import { HardhatEthersSigner } from "@nomicfoundation/hardhat-ethers/signers";
import { artifacts, ethers } from "hardhat";
import { AddressLike, BytesLike } from "ethers";
import { EntryPoint } from "typechain";
import { packUserOp } from "./uop";
import { UserOperation } from "../common/uopUtils";
import { sign } from "../passkey/passkeySign";
import { PayableAccount, AccountFactory, Helper } from "typechain";
// @ts-expect-error ecPem types not available
import ecPem from 'ec-pem';
import { PackedUserOperationStruct } from "typechain/contracts/PayableAccount";
import { PasskeyPair } from "scripts/sendUopBatch";

const hashEmail = (email: string) => {
  const abiCoder = ethers.AbiCoder.defaultAbiCoder();
  return ethers.keccak256(abiCoder.encode(["string"], [email]));
};

async function generateUopsOfSender(
  sender: string,
  signer: HardhatEthersSigner,
  entryPoint: EntryPoint,
  helper: Helper,
  count: number,
  currnetNonce: bigint,
  callData: string,
  initCode: string,
  passkey: PasskeyPair
) {
  // console.log("uop sender is : ", sender);
  if (count === 0) return [];
  let needInit = false;
  // ensure this account has been deployed
  const bytecode = await ethers.provider.getCode(sender);
  if (bytecode == "0x") {
    needInit = true;
  }
  const userOps: Array<UserOperation> = [];
  for (let i = 0n; i < count; i++) {
    const userOperation = {
      ...packUserOp({
        sender,
        nonce: currnetNonce + i,
        initCode: i == 0n && needInit ? initCode : "0x",
        callData,
        paymasterAndData: "0x",
        callGasLimit: 1000000,
        verificationGasLimit: 1000000,
        maxFeePerGas: process.env.GAS_PRICE || 1e9,
        maxPriorityFeePerGas: process.env.GAS_PRICE || 1e9,
        preVerificationGas: 0,
      }),
      signature: "0x",
    };
    const sig = await generateSignatureForUop(signer, userOperation, entryPoint, helper, 0, passkey);
    if (sig.length != 0) {
      // @ts-expect-error Type mismatch between UserOperation and internal types
      userOperation.signature = sig;
      // @ts-expect-error Type mismatch between UserOperation and internal types
      userOps.push(userOperation);
    }
  }
  return userOps;
}

const generateSignatureForUop = async (
  signer: HardhatEthersSigner,
  userOperation: UserOperation,
  entryPoint: EntryPoint,
  helper: Helper,
  verifyType: number = 0,
  passkey: PasskeyPair
) => {
  const entrypointUopHash = await entryPoint.getUserOpHash(userOperation as unknown as PackedUserOperationStruct);
  const expireTime = Math.floor(Date.now() / 1000) + 10 * 60;
  const validationData = await helper.getValidationData(expireTime);
  const uopHash = await helper.encodeUopHash(entrypointUopHash, validationData);

  // Generate EOA signature
  const okxEoaSignature = await signer.signMessage(ethers.getBytes(uopHash));

  const clientDataJSONPre = '{"type":"webauthn.get","challenge":"';
  const clientDataJSONPost = '","origin":"http://localhost:8000","crossOrigin":false}';
  const clientJson = await helper.getClientJson(clientDataJSONPre, clientDataJSONPost, uopHash);

  // Use P-256 signing
  const [r, s] = sign(clientJson[1], passkey);

  const N_DIV_2 = 57896044605178124381348723474703786764998477612067880171211129530534256022184n;
  const N = 115792089210356248762697446949407573529996955224135760342422259061068512044369n;
  let bigS = ethers.toBigInt(s);
  if (bigS > N_DIV_2) {
    bigS = N - bigS;
  }

  // sig Verify
  const passkeySigVerify = await helper.passkeyVerify(uopHash, r, bigS, passkey.pubKeyX, passkey.pubKeyY, verifyType, clientJson[0]);
  if (!passkeySigVerify[0]) {
    throw new Error("Passkey verify failed");
  }

  const passkeySig = await helper.encodePasskeySig(r, bigS, verifyType, clientJson[0]);
  return await helper.getSignature2(passkey.pubKeyX, passkey.pubKeyY, passkeySig, okxEoaSignature, validationData);
};

async function initcodeCalldata(
  accountFactory: AccountFactory,
  helper: Helper,
  smartAccountAddress: string | AddressLike,
  validatorAddress: string | AddressLike,
  recoveryAddress: string | AddressLike,
  callbackAddress: string | AddressLike,
  signer: HardhatEthersSigner,
  pubKeyX: string | bigint,
  pubKeyY: string | bigint,
  salt: string,
  expireTime: bigint,
) {
  const sender = await accountFactory.computeAddress(smartAccountAddress, salt);
  // console.log("computePausableAddress:", sender);

  const installRecoveryModuleCalldata = smartAccountInstallRecoveryModule(
    recoveryAddress,
    ethers.AbiCoder.defaultAbiCoder().encode(["bytes32"], [hashEmail("123@gmail.com")]),
  );
  const installFallbackModuleCalldata = smartAccountInstallFallbackModule(3, callbackAddress);

  const initializer = await helper.getAccountInitializer2(
    pubKeyX,
    pubKeyY,
    validatorAddress,
    signer.address,
    sender,
    installRecoveryModuleCalldata,
    installFallbackModuleCalldata,
  );

  const factoryMsgHash = await helper.getFactoryCreateAccountHash(
    accountFactory.target,
    salt,
    expireTime,
    initializer[0],
  );
  const factorySig = await signer.signMessage(ethers.getBytes(factoryMsgHash));

  const factoryPackedSig = await helper.getPackedSig(expireTime, factorySig);

  const calldata = accountFactory.interface.encodeFunctionData("createAccountWithSignature", [
    smartAccountAddress,
    initializer[0],
    salt,
    factoryPackedSig,
  ]);

  // const calldata = accountFactory.interface.encodeFunctionData("createAccount", [
  //   smartAccountAddress,
  //   initializer[0],
  //   salt,
  // ]);

  const initcode = await helper.encodePacked(accountFactory.target, calldata);

  return {
    sender,
    initcode,
  };
}

async function createSenderAccount(
  ownerAddress: string,
  ecdsaValidatorAddress: string,
  smartAccount: PayableAccount,
  accountFactory: AccountFactory,
  salt: number = 0,
) {
  const coder = new ethers.AbiCoder();

  const params = coder.encode(
    ["bytes", "address", "tuple(address,uint256,bytes)[]"],
    [ownerAddress, ecdsaValidatorAddress, []],
  );

  // @ts-ignore
  const initializer = smartAccount.interface.encodeFunctionData("initializeAccount", [params]);
  // @ts-ignore
  const sender = await accountFactory.computeAddress(smartAccount.target, initializer, salt);

  const tx = await accountFactory.createAccount(smartAccount.target, initializer, salt);
  await tx.wait();
  console.log(sender);
  console.log(tx.hash);
}

function entrypointCalldata(smartAccount: PayableAccount, modeType: string, calldata: string) {
  return smartAccount.interface.encodeFunctionData("execute", [modeType, calldata]);
}

function smartAccountInstallRecoveryModule(module: AddressLike, data: BytesLike) {
  const iface = new ethers.Interface(artifacts.readArtifactSync("PayableAccount").abi);
  const calldata = iface.encodeFunctionData("installRecoveryModule", [module, data]);
  return calldata;
}

function smartAccountInstallFallbackModule(id: number, module: AddressLike) {
  const iface = new ethers.Interface(artifacts.readArtifactSync("PayableAccount").abi);
  const calldata = iface.encodeFunctionData("installModule", [id, module, "0x"]);
  return calldata;
}

function smartAccountInstallValidatorModule(id: number, address: string, data: any) {
  const iface = new ethers.Interface(artifacts.readArtifactSync("PayableAccount").abi);
  const calldata = iface.encodeFunctionData("installModule", [id, address, data]);
  return calldata;
}

export const calldataGenerator = {
  initcodeCalldata,
  entrypointCalldata,
  createSenderAccount,
  smartAccountInstallRecoveryModule,
  smartAccountInstallFallbackModule,
  smartAccountInstallValidatorModule,
  generateUopsOfSender,
};
