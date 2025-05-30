import { ethers } from "hardhat";
import crypto from "crypto";
import { Wallet } from "ethers";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { getContractsFromAddresses, sendUOP, Contracts, TransactionResult } from "./sendUopBatch";
import { LogLevel } from "./logger";
import { getContractsFromDelopyFixture } from "./deploy/deploy";
import { assert } from "console";

interface LoadTestConfig {
    totalUOP: number;
    batchSize: number;
    concurrency: number;
    rateLimit: number;
    fundAmount: string;  // Amount of ETH to fund each sender with
    deployContracts: boolean; // Whether to deploy contracts before running the test
    logLevel: LogLevel;
}

/**
 * Creates a deterministic wallet based on a seed and index
 * @param seed Base seed for wallet generation
 * @param index Index to create unique wallets
 * @returns Ethers wallet with private key
 */
function createDeterministicWallet(seed: string, index: number) {
    // Create a deterministic hash based on seed and index
    const hash = crypto.createHash('sha256')
        .update(`${seed}-${index}`)
        .digest('hex');

    // Use the hash as a private key (adding 0x prefix)
    const privateKey = '0x' + hash;

    // Create and return a wallet with this private key
    return new ethers.Wallet(privateKey, ethers.provider);
}

class LoadTest {
    private results: TransactionResult[] = [];
    private startTime: number = 0;
    private endTime: number = 0;
    private config: LoadTestConfig;
    private contracts!: Contracts;
    private deployer!: HardhatEthersSigner;
    private senders: Wallet[] = [];

    constructor(config: LoadTestConfig) {
        this.config = config;
    }

    private async initializeSender() {
        const network = await ethers.provider.getNetwork();
        console.log("using network: ", network.chainId);
        const signers = await ethers.getSigners();
        this.deployer = signers[0];
        console.log("deployer address: ", this.deployer.address);
        
        // Create unique deterministic senders for each thread
        const numSenders = this.config.concurrency;
        
        // Use a fixed seed for deterministic wallet generation
        console.log(`Creating ${numSenders} unique deterministic sender addresses (one per thread)`);
        const walletSeed = process.env.WALLET_SEED || 'loadtest-deterministic-seed';
        
        // Create unique wallets for each thread
        this.senders = Array(numSenders).fill(0).map((_, i) => 
            createDeterministicWallet(walletSeed, i)
        );
        
        // Log the first few and last sender addresses
        if (numSenders <= 5) {
            this.senders.forEach((sender, i) => {
                console.log(`Sender ${i}: ${sender.address}`);
            });
        } else {
            for (let i = 0; i < 3; i++) {
                console.log(`Sender ${i}: ${this.senders[i].address}`);
            }
            console.log(`... (${numSenders - 5} more senders) ...`);
            for (let i = numSenders - 2; i < numSenders; i++) {
                console.log(`Sender ${i}: ${this.senders[i].address}`);
            }
        }
        // Add all senders to the config as whitelisted bundlers, factory signers, and pay signers
        console.log("Adding senders to contract configuration...");
        const senderAddresses = this.senders.map(sender => sender.address);
        
        try {
            // Configure the contract for every sender
            console.log(`Configuring ${senderAddresses.length} sender`);
            const addBundlersTx = await this.contracts.config.connect(this.deployer).addWhitelistedBundlers(senderAddresses);
            await addBundlersTx.wait();
            const addFactorySignersTx = await this.contracts.config.connect(this.deployer).addFactorySigners(senderAddresses);
            await addFactorySignersTx.wait();
            const addPaySignersTx = await this.contracts.config.connect(this.deployer).addPaySigners(senderAddresses);
            await addPaySignersTx.wait();

            // Check if all senders are correctly configured
            for (let i = 0; i < senderAddresses.length; i++) {
                const isBundler = await this.contracts.config.isWhitelistedBundler(senderAddresses[i]);
                const isFactorySigner = await this.contracts.config.isFactorySigner(senderAddresses[i]);
                const isPaySigner = await this.contracts.config.isPaySigner(senderAddresses[i]);
                assert(isBundler, `Sender ${i} is not a whitelisted bundler`);
                assert(isFactorySigner, `Sender ${i} is not a factory signer`);
                assert(isPaySigner, `Sender ${i} is not a pay signer`);
            }
            console.log("Successfully configured all senders");
        } catch (error) {
            throw new Error("Error configuring senders:", error as Error);
        }
        
        // Fund all senders with ETH
        await this.fundSenders();
    }

    private async initializeContracts() {
        // Deploy contracts if needed or use existing ones
        if (this.config.deployContracts) {
            console.log("Deploying fresh contracts for the load test...");
            this.contracts = await getContractsFromDelopyFixture();
            console.log("Contracts deployed successfully");
        } else {
            console.log("Using existing contracts from environment variables...");
            this.contracts = await getContractsFromAddresses();
            console.log("Contracts loaded from environment variables");
        }
    }
    
    private async fundSenders() {
        console.log("Funding sender addresses with ETH...");
        const fundAmount = ethers.parseEther(this.config.fundAmount);
        
        // avoid too many concurrent transactions
        const batchSize = 10;
        const totalBatches = Math.ceil(this.senders.length / batchSize);
        
        for (let batchIndex = 0; batchIndex < totalBatches; batchIndex++) {
            const startIdx = batchIndex * batchSize;
            const endIdx = Math.min(startIdx + batchSize, this.senders.length);
            console.log(`Funding batch ${batchIndex + 1}/${totalBatches} (senders ${startIdx} to ${endIdx - 1})`);
            
            // Process one sender at a time with a delay to avoid transaction replacement errors
            for (let i = startIdx; i < endIdx; i++) {
                const sender = this.senders[i];
                const balance = await ethers.provider.getBalance(sender.address);
                console.log(`Sender ${i} (${sender.address}) current balance: ${ethers.formatEther(balance)} ETH`);
                
                if (balance < fundAmount) {
                    const amountToSend = fundAmount - balance;
                    console.log(`Sending ${ethers.formatEther(amountToSend)} ETH to sender ${i} (${sender.address})`);
                    
                    try {
                        const tx = await this.deployer.sendTransaction({
                            to: sender.address,
                            value: amountToSend
                        });
                        await tx.wait();
                        
                        // Add a small delay between transactions to avoid nonce conflicts
                        await new Promise(resolve => setTimeout(resolve, 500));
                        
                        const newBalance = await ethers.provider.getBalance(sender.address);
                        console.log(`Sender ${i} (${sender.address}) new balance: ${ethers.formatEther(newBalance)} ETH`);
                    } catch (error) {
                        console.error(`Error funding sender ${i} (${sender.address}):`, error);
                    }
                } else {
                    console.log(`Sender ${i} (${sender.address}) already has sufficient funds`);
                }
            }
        }
    }

    private async rateLimiter(startTime: number, completedOps: number): Promise<void> {
        if (this.config.rateLimit <= 0) return;

        const elapsedSeconds = (Date.now() - startTime) / 1000;
        const targetOps = elapsedSeconds * this.config.rateLimit;

        if (completedOps > targetOps) {
            const waitTime = ((completedOps - targetOps) / this.config.rateLimit) * 1000;
            await new Promise(resolve => setTimeout(resolve, waitTime));
        }
    }

    public async run() {
        console.log("Load Test Config:", this.config);
        await this.initializeContracts();
        await this.initializeSender();
        
        const totalTx = Math.ceil(this.config.totalUOP / this.config.batchSize);
        const requestsPerThread = Math.ceil(totalTx / this.config.concurrency);

        this.startTime = Date.now();
        const threads = [];

        for (let sender_idx = 0; sender_idx < this.config.concurrency; sender_idx++) {
            // Each thread uses its own dedicated sender
            const sender = this.senders[sender_idx];
            
            const thread = async () => {
                for (let request_idx = 0; request_idx < requestsPerThread; request_idx++) {
                    const batchIndex = sender_idx * requestsPerThread + request_idx;
                    if (batchIndex >= totalTx) break;

                    await this.rateLimiter(this.startTime, batchIndex * this.config.batchSize);
                    
                    try {
                        // Use the original sendUOP function with proper typing
                        console.log(`Sender ${sender_idx} request ${request_idx} deployer ${this.deployer.address} sender ${sender.address}`);
                        const result = await sendUOP(
                            this.contracts,
                            this.deployer,
                            sender as unknown as HardhatEthersSigner,
                            this.config.batchSize,
                            { logLevel: this.config.logLevel }
                        );
                        
                        result.endTime = Date.now();
                        this.results.push(result);
                        
                        if (result.success) {
                            console.log(`Sender ${sender_idx} request ${request_idx} succeeded with tx hash: ${result.txHash}`);
                        } else {
                            console.error(`Sender ${sender_idx} request ${request_idx} failed with error:`, result.error);
                        }
                    } catch (error) {
                        console.error(`Unexpected error in sender ${sender_idx} request ${request_idx}:`, error);
                        this.results.push({
                            startTime: Date.now(),
                            endTime: Date.now(),
                            success: false,
                            error: error
                        });
                    }
                }
            };
            threads.push(thread());
        }

        await Promise.all(threads);
        this.endTime = Date.now();
        this.printResults();
    }

    private printResults() {
        const successfulTxs = this.results.filter(r => r.success);
        const failedTxs = this.results.filter(r => !r.success);
        
        const latencies = successfulTxs.map(r => r.endTime - r.startTime);
        const totalDuration = (this.endTime - this.startTime) / 1000; // in seconds

        console.log("\n* Results");
        console.log(`Samples: ${this.results.length * this.config.batchSize}`);
        console.log(`Start time: ${new Date(this.startTime).toISOString()}`);
        console.log(`End time: ${new Date(this.endTime).toISOString()}`);
        console.log(`UserOperations Per Second (UOPS): ${(successfulTxs.length * this.config.batchSize / totalDuration).toFixed(2)}`);
        console.log(`Transactions Per Second (TPS): ${(successfulTxs.length / totalDuration).toFixed(2)}`);
        
        if (latencies.length > 0) {
            console.log("\nRequest Latency Stats (ms):");
            console.log(`  Min: ${Math.min(...latencies).toFixed(2)}`);
            console.log(`  Max: ${Math.max(...latencies).toFixed(2)}`);
            console.log(`  Mean: ${(latencies.reduce((a, b) => a + b, 0) / latencies.length).toFixed(2)}`);
            console.log(`  Median: ${latencies.sort((a, b) => a - b)[Math.floor(latencies.length / 2)].toFixed(2)}`);
            console.log(`  StdDev: ${this.calculateStdDev(latencies).toFixed(2)}`);
        } else {
            console.log("\nNo successful transactions to calculate latency statistics.");
        }

        console.log(`\nTest Duration: ${totalDuration.toFixed(2)}s`);
        console.log(`Number of Errors: ${failedTxs.length}`);

        if (failedTxs.length > 0) {
            console.log("\nError Summary:");
            const errorCounts: { [key: string]: number } = Object.create(null);
            failedTxs.forEach(tx => {
                const error = String(tx.error || 'Unknown error');
                errorCounts[error] = (errorCounts[error] || 0) + 1;
            });
            Object.entries(errorCounts).forEach(([error, count]) => {
                console.log(`  ${error}: ${count} occurrences`);
            });
        }
    }

    private calculateStdDev(values: number[]): number {
        const mean = values.reduce((a, b) => a + b, 0) / values.length;
        const squareDiffs = values.map(value => Math.pow(value - mean, 2));
        const avgSquareDiff = squareDiffs.reduce((a, b) => a + b, 0) / squareDiffs.length;
        return Math.sqrt(avgSquareDiff);
    }
}

async function main() {
    // Read configuration from environment variables
    const config: LoadTestConfig = {
        totalUOP: parseInt(process.env.TOTAL_UOP!),
        batchSize: parseInt(process.env.BATCH_SIZE!),
        concurrency: parseInt(process.env.CONCURRENCY!),
        rateLimit: parseInt(process.env.RATE_LIMIT!),
        fundAmount: process.env.FUND_AMOUNT!,
        deployContracts: process.env.DEPLOY_CONTRACTS! === 'true', // Default to false unless explicitly set to 'true'
        logLevel: parseInt(process.env.LOG_LEVEL!) as LogLevel
    };
    const loadTest = new LoadTest(config);
    await loadTest.run();
}

if (require.main === module) {
    main().catch((error) => {
        console.error(error);
        process.exit(1);
    });
} 