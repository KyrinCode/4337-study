import { ethers, run, network } from "hardhat";
// import { Utils } from "../../test/Utils";
import { instances } from "./common/instances";
import { calldataGenerator } from "./common/calldataGenerator";
import { uopUtils } from "./common/uopUtils";
import * as mode from "./common/mode";
import { toHex } from "hardhat/internal/util/bigint";
import { UserOperation } from "./common/uopUtils";
import { passkeyFunctions } from "./passkey/passkeySign";

/**
 * Computes the address of a clone deployed using @openzeppelin/contracts/proxy/Clones.sol
 *
 * @param implementation the address of the master contract
 * @param salt integer or string value of salt
 * @param deployer the address of the factory contract
 */

async function main() {
  let [deployer] = await ethers.getSigners();
  let bundler = deployer;

  let provider = await ethers.provider;

  console.log("deployer address is", deployer.address);

  let chainID = (await ethers.provider.getNetwork()).chainId;
  if (chainID == 31337n) {
    await network.provider.send("hardhat_setBalance", [deployer.address, "0x1000000000000000000000000"]);
  }

  const entrypoint = await instances.entrypointFunc();
  const accountFactory = await instances.accountFactoryFunc();
  const smartAccount = await instances.smartAccountFunc();
  const validator = await instances.webAuthValidatorFunc();
  const configObj = await instances.configFunc();
  const helper = await instances.helperFunc();
  const fallbackHandler = await instances.fallbackHandlerFunc();
  const recoveryModule = await instances.recoveryModuleFunc();
  const pay = await instances.payFunc();
  const testToken = await instances.testERC20Func();


  const ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";

  let salt = "0";

  let expireTime = await helper.getBlocktimeStamp();
  expireTime = expireTime + 10000n;

  let pubKeyX = "0x640c5cacef387563d0b105c7724c45ee19f8a952cb583de494a6a7ce5ed16760";
  let pubKeyY = "0x142b33cbf8255e9f0628ab9e250e179a3e7e8e24e0a2a4340f0b9fdeb29a1b48";

  let { sender, initcode } = await calldataGenerator.initcodeCalldata(
    accountFactory,
    helper,
    smartAccount.target,
    validator.target,
    recoveryModule.target,
    fallbackHandler.target,
    deployer,
    pubKeyX,
    pubKeyY,
    salt,
    expireTime
  );
  console.log(sender, initcode);

  let revertData =
    "0x220266b600000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000040000000000000000000000000000000000000000000000000000000000000001441413234207369676e6174757265206572726f72000000000000000000000000";
  let revertD = entrypoint.interface.parseError(revertData);
  // console.log(revertD);return;

  if (chainID == 31337n) {
    let tx = await deployer.sendTransaction({
      to: sender,
      value: ethers.parseEther("1"), // Sends exactly 1.0 ether
    });
    await tx.wait();
  }

  const expirationTime = ethers.solidityPacked(["uint128", "uint128"], [expireTime, expireTime]);
  let chequeID = 0;
  let chequeParams = {
    chequeID: chequeID,
    to: ethers.ZeroAddress,
    tokenAddress: testToken.target,
    amount: 1,
    expiration: expirationTime,
  };

  let sendCalldata = await pay.send.populateTransaction(chequeParams);
  console.log(sendCalldata);

  let approveCalldata = await testToken.approve.populateTransaction(pay.target, ethers.MaxUint256)

  let executeParams: mode.ExecuteParams[] = [
    {
      to: testToken.target,
      value: 0,
      data: approveCalldata.data,
    },
    {
      to: pay.target,
      value: 0,
      data: sendCalldata.data,
    }
  ];

  console.log(executeParams);
  let executeCalldatas = mode.encodeExecutions(executeParams);


  const modeType = mode.encodeModeType(
    mode.CallType.Batch, 
    mode.ExecType.Default, 
    mode.ModeSelector.Default, 
    "0x"
  );

  // let executeCalldata = mode.encodeExecutionCalldata(
  //   deployer.address,
  //   1,
  //   "0x",
  // );

  let calldata = calldataGenerator.entrypointCalldata(
    smartAccount,
    modeType,
    executeCalldatas,
  );
  let nonce = await entrypoint.getNonce(sender, validator.target);

  console.log(nonce);
  const bytecode = await ethers.provider.getCode(sender);

  let accountGasLimits = uopUtils.generateAccountGasLimits(Math.floor(4000000), Math.floor(400000));

  let gasFees = uopUtils.generateGasFees(ethers.parseUnits("1", 9), ethers.parseUnits("1", 9));
  let params: UserOperation = {
    sender,
    nonce: toHex(nonce),
    initCode: bytecode == "0x" ? initcode : "0x",
    callData: calldata,
    accountGasLimits: accountGasLimits,
    gasFees: gasFees,
  };
  let uop = await uopUtils.generateUop(params);
  console.log(uop);


  const verifyType = 1;
  let sig = await uopUtils.generateSignatureForUop(
    deployer,
    uop,
    entrypoint,
    helper,
    pubKeyX,
    pubKeyY,
    verifyType
  );
  console.log(sig);
  return;

  uop.signature = sig;
  console.log(uop);


  // let sendTx = await deployer.sendTransaction({
  //   to: sender,
  //   value: ethers.parseEther("0.01"), // Sends exactly 1.0 ether
  // });
  // await sendTx.wait();
  // console.log(sendTx.hash);

  let override = {
    //gasPrice: ethers.parseUnits("1000", 9),
    //gasLimit: 3000000,
  };
  let txdata = await entrypoint.handleOps([uop], deployer.address);
  await txdata.wait();
  console.log(txdata.hash);
  return;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
