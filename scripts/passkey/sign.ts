import fs from 'fs';
import path from 'path';
// @ts-ignore
import ecPem from 'ec-pem';
import { ethers, run, network } from "hardhat";
import { Client } from 'userop';
import { SmartAccount } from '../src/userop-builder';
import { P2565Signer } from '../src/p256';
import { bufferToHex, sha256 } from 'ethereumjs-util';
import { sign } from './p256'
import crypto from 'crypto'

async function main() {
 

  // const keyContent = fs.readFileSync(path.join(__dirname, 'key.pem'))
  // const keyPair = ecPem.loadPrivateKey(keyContent);

  let keyPair = ecPem(null, 'prime256v1');
  keyPair.setPrivateKey("42d2bd030a8a71ff2f9043adcfb46138a5d87287cefff37d18a638f956c33449", "hex")
   
  // console.log("keyPair.getPrivateKey('hex'):", keyPair.getPrivateKey('hex')); 

  const publicKey = '0x' + keyPair.getPublicKey('hex').substring(2);
  console.log("publicKey: ", publicKey);

  let publicKeyArray = [
      '0x' + keyPair.getPublicKey('hex').slice(2, 66),
      '0x' + keyPair.getPublicKey('hex').slice(-64)
  ];

  console.log("publicKeyArray: ", publicKeyArray);
  // const authenticatorData = ethers.toBeHex("0x49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d97631900000000")
  // const clientDataJSONPre = '{"type":"webauthn.get","challenge":"'
  // const clientDataJSONPost = '","origin":"http://localhost:8000","crossOrigin":false}'
  // let userOpHash = ethers.zeroPadValue(ethers.toBeHex("0x713481494a20ffb30fd54110c2d2a9c8e18b89e48ad2909d3a4f86f6340e93f1"), 32)

  let messageData = "0x49960de5880e8c687434170f6476605b8fe4aeb9a28632c7995cf3ba831d9763190000000071ee23d9118e71fda3448e3b0fa3b77bb9c93f5f310dc598edfb2440504be1dc";
  // const res = sign(keyPair, Buffer.from(ethers.utils.arrayify(message)));
  let message = Buffer.from(ethers.getBytes(messageData));
  const messageHash = bufferToHex(sha256(message))

  const signer = crypto.createSign('RSA-SHA256')
  signer.update(message)
  let sigString = signer.sign(keyPair.encodePrivateKey(), 'hex')

  // @ts-ignore
  const xlength = 2 * ('0x' + sigString.slice(6, 8))
  sigString = sigString.slice(8)

  let abiencoder = ethers.AbiCoder.defaultAbiCoder();
  const signatureArray = ['0x' + sigString.slice(0, xlength), '0x' + sigString.slice(xlength + 4)]
  const signature = abiencoder.encode(['uint256', 'uint256'], [signatureArray[0], signatureArray[1]])

  console.log("messageHash:", messageHash);
  console.log("signature:", signature);

  console.log("signatureArray:", signatureArray);

}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
