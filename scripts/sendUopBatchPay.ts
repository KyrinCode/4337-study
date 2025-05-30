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
import { expect } from "chai"; 
import fs from 'fs';
import path from 'path';
import { exit } from "process";

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

async function getP256KeyPair(): Promise<PasskeyPair> {
  // Use a fixed private key for testing
  const privateKey = "42d2bd030a8a71ff2f9043adcfb46138a5d87287cefff37d18a638f956c33449";

  // Use salt as seed to generate deterministic private key
  // const privateKey = crypto.createHash('sha256')
  //   .update(salt)
  //   .digest('hex');
  
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

const CALLDATA_FILE = process.env.CALLDATA_FILE || "calldata_file.ini"
const CALLDATA_SIZE = process.env.CALLDATA_SIZE || 100

/**
 * Clear the contents of the calldata file
 */
export const clearCallDataFile = (): void => {
  try {
    fs.writeFileSync(CALLDATA_FILE, '');
  } catch (error) {
    console.error('Error clearing calldata file:', error);
  }
};

/**
 * Save sender address, recipient address and calldata to file
 * @param sender - The sender address
 * @param to - The recipient address
 * @param callData - The calldata to save
 */
export const saveCallDataToFile = (sender: string, callData: string): void => {
  try {
    const data = `${sender},${callData}\n`;
    fs.appendFileSync(CALLDATA_FILE, data);
  } catch (error) {
    console.error('Error saving calldata:', error);
  }
};

// Generate random value based on timestamp and random number
function generateRandomValue(): string {
    const timestamp = Date.now();
    const randomNum = Math.floor(Math.random() * 1000000000000);
    const combinedValue = timestamp.toString() + randomNum.toString();
    // Convert to bytes32 format
    const paddedHex = ethers.zeroPadValue(ethers.toBeHex(combinedValue), 32);
    return paddedHex;
}

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
  batchSize: number,
  options: { 
    logLevel?: LogLevel 
  } = {}
): Promise<TransactionResult> => {
  const { logLevel } = options;
  const logger = new Logger(logLevel);
  const deployBalance = await ethers.provider.getBalance(deployer.address);
  console.log("deploy address:", deployer.address, "deployBalance:", deployBalance.toString());
  const result: TransactionResult = {
    startTime: Date.now(),
    endTime: Date.now(),
    success: false
  };
  try {
    const deploy_salt = generateRandomValue();
    const expireTime = 3740578311n;
    const passkey = await getP256KeyPair();
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

    const modeType = mode.encodeModeType(
      mode.CallType.Batch,
      mode.ExecType.Default,
      mode.ModeSelector.Default,
      "0x"
    );

    // Mint ERC20 tokens to the sender account first
    const mintAmount = ethers.parseUnits("1000000000", 18); // Mint 1 billion tokens
    const mintTx = await contracts.testERC20.mint(sender, mintAmount);
    await mintTx.wait();
    // Get token balance after minting
    const tokenBalance = await contracts.testERC20.balanceOf(sender);
    console.log(`Sender ${sender} ,token minting: ${ethers.formatUnits(tokenBalance, 18)} ,hash: ${mintTx.hash}`);

    // Create approve calldata for ERC20 token
    const tokenAddress = await contracts.testERC20.getAddress();
    const payAddress = await contracts.pay.getAddress();
    const beforePayBalance = await contracts.testERC20.balanceOf(payAddress);
    console.log("payAddress:", payAddress, "beforePayBalance:", beforePayBalance.toString());
    const approveData = contracts.testERC20.interface.encodeFunctionData("approve", [
      payAddress,
      ethers.MaxUint256
    ]);
    
    const expirationTime = ethers.solidityPacked(["uint128", "uint128"], [expireTime, expireTime]);
    let chequeID = expireTime;

    let chequeParams = {
      chequeID: chequeID,
      to: ethers.ZeroAddress,
      tokenAddress: tokenAddress,
      amount: 1,
      expiration: expirationTime,
    };

    const sendCalldata = contracts.pay.interface.encodeFunctionData("send", [chequeParams]);
    
    let executeParams: mode.ExecuteParams[] = [
      {
        to: tokenAddress,
        value: 0,
        data: approveData,
      },
      {
        to: payAddress,
        value: 0,
        data: sendCalldata,
      }
    ];

    // console.log(executeParams);
    let executeCalldatas = mode.encodeExecutions(executeParams);
    // console.log(executeCalldatas);

    const callData = contracts.smartAccount.interface.encodeFunctionData("execute", [
      modeType,
      executeCalldatas,
    ]);
    // logger.warn(`callData is ${callData}`);
    // Save sender and callData to file
    saveCallDataToFile(sender, callData);

    let nonce = 1n;
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

    for (const op of userOps) {
      const jsonString = JSON.stringify(
        op, 
        (key, value) => (typeof value === "bigint" ? value.toString() : value), 
        2
      );
      // console.log(jsonString); 
    }

    // Fund the account with more ETH
    const minBalance = ethers.parseEther(process.env.SMART_ACCOUNT_BALANCE || "0.000001");
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

    const entrypointBalance = await contracts.entryPoint.balanceOf(sender);
    logger.debug(`EntryPoint balance for ${sender}: ${entrypointBalance}`);
    
    if (entrypointBalance < minBalance) {
      logger.debug(`Depositing ${ethers.formatEther(minBalance)} ETH to EntryPoint for ${sender}`);
      const tx = await contracts.entryPoint.depositTo(sender, {
        value: minBalance,
      });
      await tx.wait();
      logger.debug(`Deposit transaction completed: ${tx.hash}`);
    }

    logger.debug(`Signer ${signer.address} sending handleOps for smart account ${sender}`);
    const txdata = await contracts.entryPoint.handleOps(
      userOps as unknown as PackedUserOperationStruct[],
      signer.address
    );
    // console.log("txdata is", txdata);
    // logger.debug(`Transaction sent: ${txdata.hash}`);
    
    await txdata.wait();
    logger.debug(`Transaction confirmed: ${txdata.hash}`);
    const afterPayBalance = await contracts.testERC20.balanceOf(payAddress);
    logger.debug(`Pay before: ${ethers.formatUnits(beforePayBalance, 18)} after: ${ethers.formatUnits(afterPayBalance, 18)}`);
    expect(afterPayBalance).to.be.gt(beforePayBalance);

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
  const [initAddress] = await ethers.getSigners();
  clearCallDataFile();
  const uopBatchSize = 1;
  for (let i = 0; i < Number(CALLDATA_SIZE); i++) {
    const contracts = await getContractsFromAddresses();
    const result = await sendUOP(contracts, initAddress, initAddress, uopBatchSize, { logLevel: LogLevel.DEBUG });
    console.log(result);
  }
};

// Only run if this file is being run directly
if (require.main === module) {
  sendUopBatch().catch((error) => {
    console.error(error);
    process.exit(1);
  });
}
