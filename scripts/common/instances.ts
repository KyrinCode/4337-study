import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers } from "hardhat";
import { address } from "./address";

async function entrypointFunc(signer?: SignerWithAddress) {
  const entrypoint = await ethers.getContractAt(
    "@account-abstraction/contracts/core/EntryPoint.sol:EntryPoint",
    // @ts-ignore
    address.ENTRYPOINT_ADDRESS,
    signer,
  );
  return entrypoint;
}

async function accountFactoryFunc(signer?: SignerWithAddress) {
  const accountFactory = await ethers.getContractAt("AccountFactory", address.FACTORYPROXY_ADDRESS!, signer);
  return accountFactory;
}

async function smartAccountFunc(signer?: SignerWithAddress) {
  const smartAccount = await ethers.getContractAt("PayableAccount", address.SMARTACCOUNT_ADDRESS!, signer);

  return smartAccount;
}

async function webAuthValidatorFunc(signer?: SignerWithAddress) {
  const webAuthValidator = await ethers.getContractAt(
    "WebAuthnAndECDSAValidator",
    address.WEBAUTH_VALIDATOR_ADDRESS!,
    signer,
  );

  return webAuthValidator;
}

async function configFunc(signer?: SignerWithAddress) {
  const config = await ethers.getContractAt("Config", address.CONFIG_ADDRESS!, signer);

  return config;
}

async function helperFunc(signer?: SignerWithAddress) {
  const helper = await ethers.getContractAt("Helper", address.HELPER_ADDRESS!, signer);
  return helper;
}

async function fallbackHandlerFunc(signer?: SignerWithAddress) {
  const fallbackHandler = await ethers.getContractAt("TokenReceiver", address.FALLBACK_HANDLER!, signer);
  return fallbackHandler;
}

async function recoveryModuleFunc(signer?: SignerWithAddress) {
  const recoveryModule = await ethers.getContractAt("EmailRecoveryModule", address.MOCK_RECOVERY_MODULE!, signer);
  return recoveryModule;
}

async function testERC20Func(signer?: SignerWithAddress) {
  const testERC20 = await ethers.getContractAt("TestToken20", address.TEST_ERC20!, signer);
  return testERC20;
}

async function payFunc(signer?: SignerWithAddress) {
  const pay = await ethers.getContractAt("Pay", address.PAY!, signer);
  return pay;
}

export const instances = {
  entrypointFunc,
  accountFactoryFunc,
  smartAccountFunc,
  webAuthValidatorFunc,
  configFunc,
  helperFunc,
  fallbackHandlerFunc,
  recoveryModuleFunc,
  testERC20Func,
  payFunc
};
