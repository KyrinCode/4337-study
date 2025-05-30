import fs from 'fs'
import path from 'path'
// @ts-ignore
import ecPem from 'ec-pem'
import { ethers, run, network } from "hardhat";
import { Client } from 'userop'
import { SmartAccount } from '../src/userop-builder'
import { P2565Signer } from '../src/p256'

async function main() {
  const chainId = (await ethers.provider.getNetwork()).chainId
  console.log(chainId);

  const keyContent = fs.readFileSync(path.join(__dirname, 'key.pem'))
  const keyPair = ecPem.loadPrivateKey(keyContent);
  console.log(keyPair);
  
  const messageHash = bufferToHex(sha256(message))

  const signer = crypto.createSign('RSA-SHA256')
  signer.update(message)
  let sigString = signer.sign(keyPair.encodePrivateKey(), 'hex')

  // @ts-ignore
  const xlength = 2 * ('0x' + sigString.slice(6, 8))
  sigString = sigString.slice(8)
  const signatureArray = ['0x' + sigString.slice(0, xlength), '0x' + sigString.slice(xlength + 4)]
  const signature = defaultAbiCoder.encode(['uint256', 'uint256'], [signatureArray[0], signatureArray[1]])


}

main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
