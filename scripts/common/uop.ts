import { SignerWithAddress } from "@nomicfoundation/hardhat-ethers/signers";
import { BigNumberish, AddressLike, BytesLike, TypedDataDomain, toBeHex, zeroPadValue } from "ethers";
import { ethers } from "hardhat";
import { PackedUserOperationStruct } from "typechain/accountabstraction/contracts/interfaces/IAccount";
import { PayableAccount } from "typechain/index";

type UserOperationStruct = {
  sender: AddressLike;
  nonce: BigNumberish;
  initCode: BytesLike;
  callData: BytesLike;
  callGasLimit: BigNumberish;
  verificationGasLimit: BigNumberish;
  preVerificationGas: BigNumberish;
  maxFeePerGas: BigNumberish;
  maxPriorityFeePerGas: BigNumberish;
  paymasterAndData: BytesLike;
  signature: BytesLike;
};

async function getSigTime(sigTime: number | null, isV06 = false) {
  let _sigTime: bigint;

  if (sigTime == null || sigTime == 0) {
    _sigTime = BigInt("281474976710655");
  } else {
    _sigTime = BigInt(sigTime);
  }

  if (isV06) {
    _sigTime = _sigTime * BigInt("2") ** BigInt(160);
  }

  return _sigTime;
}

function packAccountGasLimits(verificationGasLimit: BigNumberish, callGasLimit: BigNumberish): string {
  return ethers.concat([zeroPadValue(toBeHex(verificationGasLimit), 16), zeroPadValue(toBeHex(callGasLimit), 16)]);
}

// /// verificationGasLimit, mUserOp.callGasLimit
// function packAccountGasLimits(verificationGasLimit: BigNumberish, callGasLimit: BigNumberish) {
//   let accountGasLimits = ethers.solidityPacked(
//     ["uint128", "uint128"],
//     [
//       ethers.zeroPadValue(ethers.toBeHex(verificationGasLimit), 16),
//       ethers.zeroPadValue(ethers.toBeHex(callGasLimit), 16),
//     ],
//   );

//   return accountGasLimits;
// }

// /// uint256 maxPriorityFeePerGas, uint256 maxFeePerGas
// function generateGasFees(maxPriorityFeePerGas: BigNumberish, maxFeePerGas: BigNumberish) {
//   let gasfees = ethers.solidityPacked(
//     ["uint128", "uint128"],
//     [
//       ethers.zeroPadValue(ethers.toBeHex(maxPriorityFeePerGas), 16),
//       ethers.zeroPadValue(ethers.toBeHex(maxFeePerGas), 16),
//     ],
//   );

//   return gasfees;
// }

function unpackAccountGasLimits(accountGasLimits: string): {
  verificationGasLimit: number;
  callGasLimit: number;
} {
  return {
    verificationGasLimit: parseInt(accountGasLimits.slice(2, 34), 16),
    callGasLimit: parseInt(accountGasLimits.slice(34), 16),
  };
}

function packUserOp(userOp: Omit<UserOperationStruct, "signature">): Omit<PackedUserOperationStruct, "signature"> {
  const accountGasLimits = packAccountGasLimits(userOp.verificationGasLimit, userOp.callGasLimit);
  const gasFees = packAccountGasLimits(userOp.maxPriorityFeePerGas, userOp.maxFeePerGas);

  return {
    sender: userOp.sender,
    nonce: userOp.nonce,
    callData: userOp.callData,
    accountGasLimits,
    initCode: userOp.initCode,
    preVerificationGas: userOp.preVerificationGas,
    gasFees,
    paymasterAndData: userOp.paymasterAndData,
  };
}

async function generateSignedPackedUop(
  owner: SignerWithAddress,
  account: PayableAccount,
  entryPoint: string,
  userOp: Omit<UserOperationStruct, "signature">,
  sigTime: number | null,
  sigType: number,
): Promise<PackedUserOperationStruct> {
  const packedUserOp = packUserOp(userOp);

  return {
    ...packedUserOp,
    signature: await generatePackedUopSignature(owner, account, entryPoint, packUserOp(userOp), sigTime, sigType),
  };
}

async function generatePackedUopSignature(
  owner: SignerWithAddress,
  account: PayableAccount,
  entryPoint: string,
  userOp: Omit<PackedUserOperationStruct, "signature">,
  sigTime: number | null,
  sigType: number,
) {
  const _sigTime = await getSigTime(sigTime);

  if (sigType == null || sigType == 0) {
    const _sigType = ethers.toBeHex(0);

    const network = await ethers.provider.getNetwork();

    let domain: TypedDataDomain = {
      name: "PayableAccount",
      version: "pay",
      chainId: network.chainId,
    };

    let types = {
      SignMessage: [
        { name: "sender", type: "address" },
        { name: "nonce", type: "uint256" },
        { name: "initCode", type: "bytes" },
        { name: "callData", type: "bytes" },
        { name: "accountGasLimits", type: "bytes32" },
        { name: "preVerificationGas", type: "uint256" },
        { name: "gasFees", type: "bytes32" },
        { name: "paymasterAndData", type: "bytes" },
        { name: "EntryPoint", type: "address" },
        { name: "sigTime", type: "uint256" },
      ],
    };

    let value = {
      sender: userOp.sender,
      nonce: userOp.nonce,
      initCode: userOp.initCode,
      callData: userOp.callData,
      accountGasLimits: userOp.accountGasLimits,
      preVerificationGas: userOp.preVerificationGas,
      gasFees: userOp.gasFees,
      paymasterAndData: userOp.paymasterAndData,
      EntryPoint: entryPoint,
      sigTime: ethers.toBeHex(_sigTime),
    };

    let signature = await owner.signTypedData(domain, types, value);

    signature = ethers.solidityPacked(
      ["uint8", "uint256", "bytes"],
      [ethers.zeroPadValue(_sigType, 1), ethers.zeroPadValue(ethers.toBeHex(_sigTime), 32), signature],
    );
    return signature;
  } else {
    const _sigType = ethers.toBeHex(1);
    /*
    const uop = {
      ...userOp,
      signature: ethers.solidityPacked(
        ["uint8", "uint256"],
        [
          ethers.zeroPadValue(_sigType, 1),
          ethers.zeroPadValue(ethers.toBeHex(_sigTime), 32),
        ]
      ),
    };
    */

    let signature = ethers.solidityPacked(
      ["uint8", "uint256"],
      [ethers.zeroPadValue(_sigType, 1), ethers.zeroPadValue(ethers.toBeHex(_sigTime), 32)],
    );

    // console.log("77777777777777777777777777777");
    return signature;
  }
}

export {
  packAccountGasLimits,
  unpackAccountGasLimits,
  packUserOp,
  generateSignedPackedUop,
  generatePackedUopSignature,
};
