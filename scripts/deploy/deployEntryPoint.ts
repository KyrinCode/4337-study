import { ethers } from "hardhat";

async function main() {
  const [signer] = await ethers.getSigners();
  console.log("ownerAddress", signer.address);
  const EntryPoint = await ethers.getContractFactory("@account-abstraction/contracts/core/EntryPoint.sol:EntryPoint");
  const entryPoint = await EntryPoint.deploy();
  await entryPoint.waitForDeployment();

  console.log("entrypoint deployed at: ", entryPoint.target);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
