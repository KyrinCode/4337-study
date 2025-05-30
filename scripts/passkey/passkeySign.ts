import { ethers } from "hardhat";
// @ts-expect-error ecPem types not available
import ecPem from "ec-pem";
import crypto from "crypto";
import { PasskeyPair } from "scripts/sendUopBatch";

export function sign(messageData: string, passkey: PasskeyPair): [string, string] {
  const message = Buffer.from(ethers.getBytes(messageData));
  
  // Create ec-pem key pair from private key
  const keyPair = ecPem(null, 'prime256v1');
  keyPair.setPrivateKey(passkey.privateKey, 'hex');
  
  const signer = crypto.createSign("RSA-SHA256");
  signer.update(message);
  const sigString = signer.sign(keyPair.encodePrivateKey(), "hex");

  // @ts-expect-error DER signature format parsing
  const xlength = 2 * ("0x" + sigString.slice(6, 8));
  const sigPart = sigString.slice(8);

  return [
    "0x" + sigPart.slice(0, xlength),
    "0x" + sigPart.slice(xlength + 4)
  ];
}

