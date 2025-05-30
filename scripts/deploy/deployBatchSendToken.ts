// We require the Hardhat Runtime Environment explicitly here. This is optional
// but useful for running the script in a standalone fashion through `node <script>`.
//
// You can also run a script with `npx hardhat run <script>`. If you do that, Hardhat
// will compile your contracts, add the Hardhat Runtime Environment's members to the
// global scope, and execute the script.
import { ethers, run, network } from "hardhat";

async function main() {

  const [signer] = await ethers.getSigners();
  console.log("ownerAddress", signer.address);

  // const tx = await signer.sendTransaction({
  //     to: signer.address,
  //     value: ethers.parseEther("0"),
  // });

  // await tx.wait();
  // console.log(tx.hash);return;

  let chainID = (await ethers.provider.getNetwork()).chainId.toString();
  if (chainID == 31337) {
      await network.provider.send("hardhat_setBalance", [signer.address, "0x1000000000000000000000000"]);
  }

  const obj = await ethers.deployContract("BatchSendToken");

  await obj.waitForDeployment();

  console.log(obj.target);
  
  return;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
