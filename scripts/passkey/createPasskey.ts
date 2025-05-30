import fs from 'fs';
import path from 'path';
// @ts-ignore
import ecPem from 'ec-pem';
// import { ethers, run, network } from "hardhat";
// import { Client } from 'userop';
// import { SmartAccount } from '../src/userop-builder';
// import { P2565Signer } from '../src/p256';
// import { bufferToHex, sha256 } from 'ethereumjs-util';
// import { sign } from './p256'
import crypto from 'crypto'

async function main() {
  let prime256v1 = crypto.createECDH("prime256v1");
  prime256v1.generateKeys();

  let keyPair = ecPem(prime256v1, "prime256v1");
  console.log(keyPair);

  console.log("prime256v1 public key:", prime256v1.getPublicKey("hex"));
  console.log("keyPair.getPublicKey('hex'):", keyPair.getPublicKey("hex"));
  console.log(
    "prime256v1.getPrivateKey('hex'):",
    prime256v1.getPrivateKey("hex")
  );
  console.log("keyPair.getPrivateKey('hex'):", keyPair.getPrivateKey("hex"));
  console.log("prime256v1 EncodePrivateKey: ");
  console.log(keyPair.encodePrivateKey());
  console.log("prime256v1 encodePublicKey: ");
  console.log(keyPair.encodePublicKey());
}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
