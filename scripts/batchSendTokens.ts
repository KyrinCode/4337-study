import { ethers, run, network } from "hardhat";

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

  const ETH = "0xEeeeeEeeeEeEeeEeEeEeeEEEeeeeEeeeeeeeEEeE";
  const batchSend = await ethers.getContractAt("BatchSendToken", process.env.BATCH_SEND_ADDRESS, deployer);

  // let tx = await batchSend.batchSend(
  //   ["0x0c091A7F09bf4Ec2A6f1d664d3792F6518148214"],
  //   ETH
  // );
  // await tx.wait();
  // console.log(tx.hash);

  let takebackTx = await batchSend.takeback(ETH, deployer.address);
  await takebackTx.wait();
  console.log(takebackTx.hash);


}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
