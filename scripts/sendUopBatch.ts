import { ethers } from "hardhat";
import { instances } from "./common/instances";
import * as mode from "./common/mode";
import { calldataGenerator } from "./common/calldataGenerator";
import {
  Helper,
  EntryPoint,
  AccountFactory,
  PayableAccount,
  WebAuthnAndECDSAValidator,
  Config,
  TokenReceiver,
  MockRecoveryModule,
  Pay,
  TestToken20
} from "typechain";
import { PackedUserOperationStruct } from "typechain/contracts/PayableAccount";
import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import crypto from 'crypto';
import { LogLevel, Logger } from './logger';

export interface TransactionResult {
  startTime: number;
  endTime: number;
  success: boolean;
  error?: string | unknown;
  txHash?: string;
}

export interface Contracts {
  entryPoint: EntryPoint;
  accountFactory: AccountFactory;
  smartAccount: PayableAccount;
  validator: WebAuthnAndECDSAValidator;
  config: Config;
  helper: Helper;
  fallbackHandler: TokenReceiver;
  recoveryModule: MockRecoveryModule;
  pay: Pay;
  testERC20: TestToken20;
  
  printAddresses?: () => Promise<void>;
}

export const printContractAddresses = async (contracts: Contracts): Promise<void> => {
  console.log("Contract addresses:");
  console.log(`  ENTRYPOINT: ${await contracts.entryPoint.getAddress()}`);
  console.log(`  HELPER: ${await contracts.helper.getAddress()}`);
  console.log(`  TOKEN_RECEIVER: ${await contracts.fallbackHandler.getAddress()}`);
  console.log(`  CONFIG: ${await contracts.config.getAddress()}`);
  console.log(`  WEBAUTHN_VALIDATOR: ${await contracts.validator.getAddress()}`);
  console.log(`  PAYABLE_ACCOUNT: ${await contracts.smartAccount.getAddress()}`);
  console.log(`  ACCOUNT_FACTORY: ${await contracts.accountFactory.getAddress()}`);
  console.log(`  MOCK_RECOVERY_MODULE: ${await contracts.recoveryModule.getAddress()}`);
  console.log(`  PAY: ${await contracts.pay.getAddress()}`);
  console.log(`  TEST_ERC20: ${await contracts.testERC20.getAddress()}`);
};

export interface PasskeyPair {
  pubKeyX: string;
  pubKeyY: string;
  privateKey: string;
}

async function generateP256KeyPair(privateKey: string): Promise<PasskeyPair> {
  const ecdh = crypto.createECDH('prime256v1');
  ecdh.setPrivateKey(Buffer.from(privateKey, 'hex') as unknown as Uint8Array);
  const publicKey = ecdh.getPublicKey('hex', 'uncompressed');
  
  // Public key format is: 04 || x || y
  // Remove '04' prefix and split into x and y coordinates
  const pubKeyX = '0x' + publicKey.slice(2, 66);
  const pubKeyY = '0x' + publicKey.slice(66, 130);
  
  return {
    pubKeyX,
    pubKeyY,
    privateKey
  };
}

export const getContractsFromAddresses = async (): Promise<Contracts> => {
  const entryPoint =
    (await instances.entrypointFunc()) as unknown as EntryPoint;
  const accountFactory =
    (await instances.accountFactoryFunc()) as unknown as AccountFactory;
  const smartAccount =
    (await instances.smartAccountFunc()) as unknown as PayableAccount;
  const validator =
    (await instances.webAuthValidatorFunc()) as unknown as WebAuthnAndECDSAValidator;
  const config = (await instances.configFunc()) as unknown as Config;
  const helper = (await instances.helperFunc()) as unknown as Helper;
  const fallbackHandler =
    (await instances.fallbackHandlerFunc()) as unknown as TokenReceiver;
  const recoveryModule = await instances.recoveryModuleFunc() as unknown as MockRecoveryModule;
  const pay = (await instances.payFunc()) as unknown as Pay;
  const testERC20 = (await instances.testERC20Func()) as unknown as TestToken20;

  return {
    entryPoint,
    accountFactory,
    smartAccount,
    validator,
    config,
    helper,
    fallbackHandler,
    recoveryModule,
    pay,
    testERC20
  };
};

/**
 * Sends a batch of user operations to the EntryPoint contract
 * @param contracts - Contract instances needed for execution
 * @param signer - The signer sending the user operations
 * @param deploy_salt - Salt used to generate deterministic sender address and passkey
 * @param batchSize - Number of user operations to generate and send in one transaction
 * @param options - Optional configuration parameters
 * @returns TransactionResult containing execution status and timing information
 */
export const sendUOP = async (
  contracts: Contracts,
  deployer: HardhatEthersSigner,
  signer: HardhatEthersSigner,
  passkeyPrivateKey: string,
  batchSize: number,
  options: { 
    logLevel?: LogLevel 
  } = {}
): Promise<TransactionResult> => {
  const { logLevel } = options;
  const logger = new Logger(logLevel);
  
  const result: TransactionResult = {
    startTime: Date.now(),
    endTime: Date.now(),
    success: false
  };

  try {
    // Fixed deploy salt, only 1 deployer as factorySigner
    const deploy_salt = "2";
    // Use a large expire time Year 2088 to avoid expiration
    const expireTime = 3740578311n;

    // constant passkey for testing
    const passkey = await generateP256KeyPair(passkeyPrivateKey);
    logger.debug(`Generated passkey with pubKeyX: ${passkey.pubKeyX.substring(0, 10)}...`);

    const { sender, initcode } = await calldataGenerator.initcodeCalldata(
      contracts.accountFactory,
      contracts.helper,
      contracts.smartAccount.target,
      contracts.validator.target,
      contracts.recoveryModule.target,
      contracts.fallbackHandler.target,
      deployer,
      passkey.pubKeyX,
      passkey.pubKeyY,
      deploy_salt,
      expireTime
    );
    logger.debug(`Generated initcode for sender: ${sender}`);

    const modeType = mode.encodeModeType(
      mode.CallType.Batch,
      mode.ExecType.Default,
      mode.ModeSelector.Default,
      "0x"
    );

    // Mint ERC20 tokens to the sender account first
    const mintAmount = ethers.parseUnits("1000000000", 18); // Mint 1 billion tokens
    logger.debug(`Minting ${ethers.formatUnits(mintAmount, 18)} ERC20 tokens to ${sender}`);
    const mintTx = await contracts.testERC20.mint(sender, mintAmount);
    await mintTx.wait();
    logger.debug(`Minted tokens successfully: ${mintTx.hash}`);
    
    // Get token balance after minting
    const tokenBalance = await contracts.testERC20.balanceOf(sender);
    logger.debug(`Token balance after minting: ${ethers.formatUnits(tokenBalance, 18)}`);

    // Send 1 token to a fixed address 0x1111111111111111111111111111111111111111
    // Generate a random Ethereum address
    const randomBytes = crypto.randomBytes(20);
    const recipient = '0x' + randomBytes.toString('hex');
    const erc20Amount = ethers.parseUnits("1", 18);
    
    // Create approve calldata for ERC20 token
    const tokenAddress = await contracts.testERC20.getAddress();
    const approveData = contracts.testERC20.interface.encodeFunctionData("approve", [
      contracts.pay.target,
      erc20Amount
    ]);
    
    const chequeParams = {
      chequeID: 1,
      to: recipient,
      tokenAddress: tokenAddress,
      amount: erc20Amount,
      expiration: expireTime
    }
    // Create Pay.send calldata for ERC20 token
    const sendData = contracts.pay.interface.encodeFunctionData("send", [chequeParams]);
    
    const executeParams: mode.ExecuteParams[] = [
      {
        to: tokenAddress,
        value: 0,
        data: approveData,
      },
      {
        to: contracts.pay.target,
        value: 0,
        data: sendData,
      }
    ];

    logger.debug(`Created batch executeCalldata for approving and transferring ${ethers.formatUnits(erc20Amount, 18)} tokens to ${recipient}`);

    const callData = contracts.smartAccount.interface.encodeFunctionData("execute", [
      modeType,
      mode.encodeExecutions(executeParams),
    ]);
    logger.warn(`callData is ${callData}`);

    const nonce = await contracts.entryPoint.getNonce(sender, contracts.validator.target as string);
    logger.debug(`Current nonce for ${sender}: ${nonce}`);

    const userOps = await calldataGenerator.generateUopsOfSender(
      sender,
      signer,
      contracts.entryPoint,
      contracts.helper,
      batchSize,
      nonce,
      callData,
      initcode,
      passkey,
    );

    if (userOps.length === 0) {
      logger.error(`Failed to generate user operations`);
      throw new Error("Generate uops failed!");
    }
    
    logger.debug(`Generated ${userOps.length} user operations`);

    // Fund the account with more ETH, ensure the account has enough balance to pay for the user operations
    const minBalance = ethers.parseEther(process.env.SMART_ACCOUNT_BALANCE || "0.1");
    const accountBalance = await ethers.provider.getBalance(sender);
    logger.debug(`Smart account ${sender} balance: ${accountBalance}`);
    
    if (accountBalance < minBalance) {
      logger.debug(`Funding smart account ${sender} with ${ethers.formatEther(minBalance)} ETH from signer ${signer.address}`);
      const sendTx = await signer.sendTransaction({
        to: sender,
        value: minBalance,
      });
      await sendTx.wait();
      logger.debug(`Funding transaction completed: ${sendTx.hash}`);
    }

    logger.debug(`Signer ${signer.address} sending handleOps for smart account ${sender}`);
    const txdata = await contracts.entryPoint.handleOps(
      userOps as unknown as PackedUserOperationStruct[],
      signer.address
    );
    logger.debug(`Transaction sent: ${JSON.stringify(txdata)}`);
    
    await txdata.wait();

    result.success = true;
    result.txHash = txdata.hash;
  } catch (error) {
    result.success = false;
    result.error = error;
    logger.error(`Error in sendUOP: ${error}`);
  }

  result.endTime = Date.now();
  return result;
};

const sendUopBatch = async () => {
  const network = await ethers.provider.getNetwork();
  console.log("using network : ", network.chainId);
  const [deployer] = await ethers.getSigners();
  console.log("deployer address is", deployer.address);

  const contracts = await getContractsFromAddresses();

  const uopBatchSize = 1;
  const passkeyPrivateKey = "42d2bd030a8a71ff2f9043adcfb46138a5d87287cefff37d18a638f956c33449";
  const result = await sendUOP(contracts, deployer, deployer, passkeyPrivateKey, uopBatchSize, { logLevel: LogLevel.DEBUG });
  console.log(result);
};

// Only run if this file is being run directly
if (require.main === module) {
  sendUopBatch().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
