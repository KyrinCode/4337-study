import { HardhatEthersSigner, SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { ethers, network } from "hardhat";
import { sign } from "../passkey/passkeySign";
import { EntryPoint, Helper } from "typechain/index";

const ACCOUNT_GAS_LIMIT = "0x000000000000000000000000000ddba0000000000000000000000000000ddba0";
const PRE_VERIFICATION_GAS = "0xa0";
const GAS_FEES = "0x00000000000000000000000a7a35820000000000000000000000001b79591c00";

const SIGN_EIP712_TYPE = 0;
const SIGN_EIP191_TYPE = 1;
const VERSION_3_0_0 = "3.0.2";
const NAME = "SmartAccount";
const CHAIN_ID = 137;

export type UserOperation = {
  sender: string;
  nonce: string;
  initCode: string;
  callData: string;
  accountGasLimits: bigint;
  preVerificationGas?: bigint;
  gasFees?: bigint;
  paymasterAndData?: string;
  signature?: string;
};

function predictDeterministicAddress(implementation, salt, deployer) {
  let assembly = `3d602d80600a3d3981f3363d3d373d3d3d363d73${implementation
    .toLowerCase()
    .slice(2)}5af43d82803e903d91602b57fd5bf3ff${deployer.toLowerCase().slice(2)}${String(salt).slice(2)}`;
  assembly += keccak256(solidityPacked(["bytes"], ["0x" + assembly.slice(0, 110)])).slice(2);
  const address = keccak256(solidityPacked(["bytes"], ["0x" + assembly.slice(110, 280)])).slice(-40);
  return "0x" + address;
}

async function getSigTime() {
  const blockTime = (await ethers.provider.getBlock()).timestamp.toString();
  return ethers.getBigInt(blockTime) + ethers.getBigInt(100000);
}

function getPaymasterSigTime() {
  return BigInt("0x000000000000ffffffffffff0000000000000000000000000000000000000000");
}

// EIP712_ORDER_STRUCT_SCHEMA_HASH,
//                           userOp.getSender(),
//                           userOp.nonce,
//                           keccak256(userOp.initCode),
//                           keccak256(userOp.callData),
//                           userOp.accountGasLimits,
//                           userOp.preVerificationGas,
//                           userOp.gasFees,
//                           keccak256(userOp.paymasterAndData),
//                           EntryPoint,
//                           uint256(bytes32(userOp.signature[1:33]))

async function signUopViaEip712(
  signer: ethers.Signer,
  authenticationManager: ethers.Contract,
  entryPointAddress: string,
  userOp: UserOperation,
  sigTime: bigint = 0,
) {
  const sigType = ethers.toBeHex(0);
  if (sigTime == 0) {
    sigTime = await getSigTime();
  }

  // const network = await hre.ethers.provider.getNetwork();
  const domain = {
    name: NAME,
    version: VERSION_3_0_0,
    chainId: CHAIN_ID,
    verifyingContract: authenticationManager.target,
  };

  const types = {
    SignMessage: [
      { name: "sender", type: "address" },
      { name: "nonce", type: "uint256" },
      { name: "initCode", type: "bytes" },
      { name: "callData", type: "bytes" },
      { name: "accountGasLimits", type: "uint256" },
      { name: "preVerificationGas", type: "uint256" },
      { name: "gasFees", type: "uint256" },
      { name: "paymasterAndData", type: "bytes" },
      { name: "EntryPoint", type: "address" },
      { name: "sigTime", type: "uint256" },
    ],
  };

  const value = {
    sender: userOp.sender,
    nonce: userOp.nonce,
    initCode: userOp.initCode,
    callData: userOp.callData,
    accountGasLimits: userOp.accountGasLimits,
    preVerificationGas: userOp.preVerificationGas,
    gasFees: userOp.gasFees,
    paymasterAndData: userOp.paymasterAndData,
    EntryPoint: entryPointAddress,
    sigTime: sigTime,
  };

  let signature = await signer.signTypedData(domain, types, value);

  signature = ethers.solidityPacked(
    ["uint8", "uint256", "bytes"],
    [ethers.zeroPadValue(sigType, 1), ethers.zeroPadValue(ethers.toBeHex(sigTime), 32), signature],
  );
  return signature;
}

/// verificationGasLimit, mUserOp.callGasLimit
function generateAccountGasLimits(verificationGasLimit: number, callGasLimit: number) {
  const accountGasLimits = ethers.solidityPacked(
    ["uint128", "uint128"],
    [
      ethers.zeroPadValue(ethers.toBeHex(verificationGasLimit), 16),
      ethers.zeroPadValue(ethers.toBeHex(callGasLimit), 16),
    ],
  );

  return accountGasLimits;
}

/// uint256 maxPriorityFeePerGas, uint256 maxFeePerGas
function generateGasFees(maxPriorityFeePerGas: number, maxFeePerGas: number) {
  const gasfees = ethers.solidityPacked(
    ["uint128", "uint128"],
    [
      ethers.zeroPadValue(ethers.toBeHex(maxPriorityFeePerGas), 16),
      ethers.zeroPadValue(ethers.toBeHex(maxFeePerGas), 16),
    ],
  );

  return gasfees;
}

async function signUopViaEip191(
  signer: ethers.Signer,
  validator: ethers.Contract,
  entryPointAddress: string,
  userOp: UserOperation,
  sigTime: bigint,
) {
  if (sigTime == 0) {
    sigTime = await getSigTime();
  }
  const sigType = ethers.toBeHex(SIGN_EIP191_TYPE);

  userOp.signature = ethers.solidityPacked(
    ["uint8", "uint256"],
    [ethers.zeroPadValue(sigType, 1), ethers.zeroPadValue(ethers.toBeHex(sigTime), 32)],
  );
  const uopHash = await validator.getUopHash(entryPointAddress, userOp);
  return await signer.signMessage(ethers.getBytes(uopHash));
}

async function generateUop(userOperation: UserOperation) {
  const uop: UserOperation = {
    sender: userOperation.sender,
    nonce: 0,
    initCode: "0x",
    callData: "0x",
    paymasterAndData: "0x",
    signature: "0x",
    accountGasLimits: ACCOUNT_GAS_LIMIT,
    preVerificationGas: PRE_VERIFICATION_GAS,
    gasFees: GAS_FEES,
  };
  if (userOperation.nonce) {
    uop.nonce = userOperation.nonce;
  }

  if (userOperation.initCode) {
    uop.initCode = userOperation.initCode;
  }

  if (userOperation.callData) {
    uop.callData = userOperation.callData;
  }
  if (userOperation.accountGasLimits) {
    uop.accountGasLimits = userOperation.accountGasLimits;
  }

  if (userOperation.preVerificationGas) {
    uop.preVerificationGas = userOperation.preVerificationGas;
  }

  if (userOperation.gasFees) {
    uop.gasFees = userOperation.gasFees;
  }

  return uop;
}

function packedUopSig(signature: string, sigType: number, sigTime: number) {
  const packedSignature = ethers.solidityPacked(
    ["uint8", "uint256", "bytes"],
    [ethers.zeroPadValue(ethers.toBeHex(sigType), 1), ethers.zeroPadValue(ethers.toBeHex(sigTime), 32), signature],
  );
  return packedSignature;
}

async function signUopAndPacked(
  signer: ethers.Signer,
  authenticationManager: ethers.Contract,
  entryPointAddress: string,
  userOp: UserOperation,
  sigType: number,
) {
  let signature: string;
  const sigTime = await getSigTime();
  if (sigType == SIGN_EIP712_TYPE) {
    signature = await signUopViaEip712(signer, authenticationManager, entryPointAddress, userOp, sigTime);
  } else {
    signature = await signUopViaEip191(signer, authenticationManager, entryPointAddress, userOp, sigTime);
  }
  return packedUopSig(signature, sigType, sigTime);
}

async function generateSignedUop(params) {
  const uop = await generateUop(params.sender, params.nonce, params.initCode, params.callData, params.paymasterAndData);

  uop.signature = await signUopAndPacked(
    params.signer,
    params.smartAccount,
    params.entryPointAddress,
    uop,
    params.sigType,
    params.sigTime,
  );

  return uop;
}

async function signfreeGasPaymaster(
  paymasterSigner: ethers.Signer,
  userOp: UserOperation,
  policyPaymaster: string,
  freegasPaymaster: ethers.Contract,
  sigTime?: number,
) {
  if (!sigTime) {
    sigTime = getPaymasterSigTime();
  }

  const abiencoder = ethers.AbiCoder.defaultAbiCoder();

  const additionalData = abiencoder.encode(
    [
      { name: "sigTime", type: "uint256" },
      { name: "businessId", type: "uint64" },
    ],
    [sigTime, 0n],
  );
  // console.log("additionalData is", additionalData);

  // let encodedData = abiencoder.encode(
  //     [
  //         { name: "sender", type: "address" },
  //         { name: "nonce", type: "uint256" },
  //         { name: "initCodeHash", type: "bytes32" },
  //         { name: "callDataHash", type: "bytes32" },
  //         { name: "accountGasLimits", type: "uint256" },
  //         { name: "preVerificationGas", type: "uint256" },
  //         { name: "gasFees", type: "uint256" },
  //         { name: "chainId", type: "uint256" },
  //         { name: "caller", type: "address" },
  //         { name: "additionalData", type: "bytes" },
  //     ],
  //     [
  //         userOp.sender,
  //         userOp.nonce,
  //         ethers.keccak256(userOp.initCode),
  //         ethers.keccak256(userOp.callData),
  //         BigInt(userOp.accountGasLimits),
  //         userOp.preVerificationGas,
  //         BigInt(userOp.gasFees),
  //         BigInt(CHAIN_ID),
  //         policyPaymaster,
  //         additionalData,
  //     ],
  // );

  // let keccak256Encodedata = ethers.keccak256(encodedData);
  // console.log("keccak256Encodedata is ", keccak256Encodedata);
  const hash = await freegasPaymaster.getHash(userOp, policyPaymaster, additionalData);

  return await paymasterSigner.signMessage(ethers.getBytes(hash));
}

/**
 * paymaster地址： 20bytes
 * paymasterVerificationGasLimit：16bytes +
 * paymasterPostOpGasLimit:16Bytes +
 * mode 1byte +
 * businessId : 8Bytes +
 * sigTime : 32Bytes +
 * signature
 */
function packedFreeGasPaymasterSig(
  policyPaymaster: string,
  verificationGasLimit: number,
  postOpGasLimit: number,
  signature: string,
  sigTime?: number,
) {
  if (!sigTime) {
    sigTime = getPaymasterSigTime();
  }
  const packedSignature = ethers.solidityPacked(
    ["address", "uint128", "uint128", "uint8", "uint64", "uint256", "bytes"],
    [
      policyPaymaster,
      ethers.zeroPadValue(ethers.toBeHex(verificationGasLimit), 16),
      ethers.zeroPadValue(ethers.toBeHex(postOpGasLimit), 16),
      ethers.zeroPadValue(ethers.toBeHex(0), 1),
      ethers.zeroPadValue(ethers.toBeHex(0), 8),
      ethers.zeroPadValue(ethers.toBeHex(sigTime), 32),
      signature,
    ],
  );
  return packedSignature;
}

async function signfreeGasPaymasterAndPacked(
  paymasterSigner: ethers.Signer,
  policyPaymaster: string,
  freegasPaymaster: ethers.Contract,
  userOp: UserOperation,
  verificationGasLimit: number,
  postOpGasLimit: number,
) {
  const signature = await signfreeGasPaymaster(paymasterSigner, userOp, policyPaymaster, freegasPaymaster);

  return packedFreeGasPaymasterSig(policyPaymaster, verificationGasLimit, postOpGasLimit, signature);
}

async function signTokenPaymaster(
  paymasterSigner: ethers.Signer,
  userOp: UserOperation,
  policyPaymaster: string,
  tokenPaymaster: ethers.Contract,
  exchangeToken: string,
  exchangeRate: number,
  sigTime?: number,
) {
  if (!sigTime) {
    sigTime = getPaymasterSigTime();
  }

  const abiencoder = ethers.AbiCoder.defaultAbiCoder();

  const additionalData = abiencoder.encode(
    [
      {
        internalType: "uint256",
        name: "sigTime",
        type: "uint256",
      },
      {
        internalType: "uint64",
        name: "businessId",
        type: "uint64",
      },
      {
        components: [
          {
            internalType: "address",
            name: "token",
            type: "address",
          },
          {
            internalType: "uint256",
            name: "exchangeRate",
            type: "uint256",
          },
        ],
        internalType: "struct testabi.TokenData",
        name: "tokenData",
        type: "tuple",
      },
    ],
    [
      sigTime,
      0n,
      {
        token: exchangeToken,
        exchangeRate: exchangeRate,
      },
    ],
  );

  const hash = await tokenPaymaster.getHash(userOp, policyPaymaster, additionalData);

  return await paymasterSigner.signMessage(ethers.getBytes(hash));
}

function packedTokenPaymasterSig(
  policyPaymaster: string,
  verificationGasLimit: number,
  postOpGasLimit: number,
  signature: string,
  exchangeToken: string,
  exchangeRate: number,
  sigTime?: number,
) {
  if (!sigTime) {
    sigTime = getPaymasterSigTime();
  }
  const packedSignature = ethers.solidityPacked(
    ["address", "uint128", "uint128", "uint8", "uint64", "uint256", "address", "uint256", "bytes"],
    [
      policyPaymaster,
      ethers.zeroPadValue(ethers.toBeHex(verificationGasLimit), 16),
      ethers.zeroPadValue(ethers.toBeHex(postOpGasLimit), 16),
      ethers.zeroPadValue(ethers.toBeHex(1), 1),
      ethers.zeroPadValue(ethers.toBeHex(0), 8),
      ethers.zeroPadValue(ethers.toBeHex(sigTime), 32),
      exchangeToken,
      ethers.zeroPadValue(ethers.toBeHex(exchangeRate), 32),
      signature,
    ],
  );
  return packedSignature;
}

async function getOKXSignature(datahash: string, okxSigner: ethers.Signer) {
  // let datahash = ethers.id("123");
  // let datahash = "0x713481494a20ffb30fd54110c2d2a9c8e18b89e48ad2909d3a4f86f6340e93f1";
  const sig = await okxSigner.signMessage(ethers.getBytes(datahash));
  return sig;
  // let abiencoder = ethers.AbiCoder.defaultAbiCoder();
  // let okxSignature = abiencoder.encode(
  //     ["bytes32", "bytes"],
  //     [datahash, sig],
  // );

  //return okxSignature;
}

async function getPasskeySignature(
  authenticatorData: string,
  clientDataJSON: string,
  r: number,
  s: number,
  pubKeyX: number,
  pubKeyY: number,
) {
  const abiencoder = ethers.AbiCoder.defaultAbiCoder();
  const passkeySignature = abiencoder.encode(
    ["bytes", "string", "uint256", "uint256", "uint256", "uint256", "uint256", "bool"],
    [ethers.getBytes(authenticatorData), clientDataJSON, 1, r, s, pubKeyX, pubKeyY, false],
  );
  return passkeySignature;
}

function getPasskeyAndOkxSignature(hookData: string, passkeySignature: string, okxSignature: string, uid: sting) {
  const abiencoder = ethers.AbiCoder.defaultAbiCoder();
  const signature = abiencoder.encode(
    ["bytes", "bytes", "bytes"],
    [
      abiencoder.encode(["string"], [hookData]),
      abiencoder.encode(["bytes", "bytes"], [ethers.getBytes(passkeySignature), ethers.getBytes(okxSignature)]),
      abiencoder.encode(["bytes32"], [uid]),
    ],
  );

  return signature;
}

async function generateSignatureForUop(
  signer: HardhatEthersSigner,
  userOperation: any,
  entryPoint: EntryPoint,
  helper: Helper,
  pubKeyX: number,
  pubKeyY: number,
  verifyType: number = 1,
) {
  /// TO-DO
  /// 0 : PRECOMPILED_VERIFIER, helper validation passes, but handleops fails.
  /// 1 : DAIMO_VERIFIER success
  /// 2 : ELLIPTIC_CURVE success(local fork node)
  // const verifyType = 1;
  const entrypointUopHash = await entryPoint.getUserOpHash(userOperation);
  // console.log("entrypointUopHash : ", entrypointUopHash);

  const expireTime = Math.floor(Date.now() / 1000) + 10 * 60;
  const validationData = await helper.getValidationData(expireTime);
  console.log("validationData : ", validationData);

  const checkValidationDate = await helper.checkValidationDate(validationData);
  console.log("checkValidationDate : ", checkValidationDate);

  const uopHash = await helper.encodeUopHash(entrypointUopHash, validationData);
  // console.log("uopHash:", uopHash);

  //  generate signature
  const okxEoaSignature = await signer.signMessage(ethers.getBytes(uopHash));

  // sig Verify
  const verifyEoaSig = await helper.recoverAddress(okxEoaSignature, uopHash);
  console.log("verifyEoaSig:", verifyEoaSig);

  const clientDataJSONPre = '{"type":"webauthn.get","challenge":"';
  const clientDataJSONPost = '","origin":"http://localhost:8000","crossOrigin":false}';

  const clientJson = await helper.getClientJson(clientDataJSONPre, clientDataJSONPost, uopHash);
  // console.log("clientJson : ", clientJson);

  const passkeySigResult = sign(clientJson[1]);
  // console.log("passkeySigResult : ", passkeySigResult);

  let [r, s] = [passkeySigResult[0], passkeySigResult[1]];

  const N_DIV_2 = 57896044605178124381348723474703786764998477612067880171211129530534256022184n;
  const N = 115792089210356248762697446949407573529996955224135760342422259061068512044369n;

  const bigIntS = ethers.toBigInt(s);
  if (bigIntS > N_DIV_2) {
    s = N - bigIntS;
  }

  // sig Verify
  const passkeySigVerify = await helper.passkeyVerify(uopHash, r, s, pubKeyX, pubKeyY, verifyType, clientJson[0]);
  console.log("passkeySigVerify:", passkeySigVerify);
  console.log("Passkey check: ", passkeySigVerify[0] ? "✅ Success" : "❌ Failed");

  if (!passkeySigVerify[0]) {
    console.warn("Passkey verify failed.");
    return "";
  }
  const passkeySig = await helper.encodePasskeySig(r, s, verifyType, clientJson[0]);
  // console.log("passkeySig:", passkeySig);

  const sig = await helper.getSignature2(pubKeyX, pubKeyY, passkeySig, okxEoaSignature, validationData);

  // sig Verify
  const getSignature2Decode = await helper.getSignature2Decode(sig);
  console.log("getSignature2Decode:", getSignature2Decode);

  return sig;
}

export const uopUtils = {
  generateUop,
  generateSignedUop,
  signUopViaEip712,
  signUopViaEip191,
  signUopAndPacked,
  getSigTime,
  VERSION_3_0_0,
  predictDeterministicAddress,
  signfreeGasPaymaster,
  signfreeGasPaymasterAndPacked,
  signTokenPaymaster,
  packedTokenPaymasterSig,
  generateAccountGasLimits,
  generateGasFees,
  getOKXSignature,
  getPasskeySignature,
  getPasskeyAndOkxSignature,
  generateSignatureForUop,
};
