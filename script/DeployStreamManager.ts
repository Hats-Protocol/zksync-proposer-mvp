import { config as dotEnvConfig } from "dotenv";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet, Contract } from "zksync-ethers";
import * as hre from "hardhat";

const StreamManagerFactory = require("../artifacts-zk/src/StreamManagerFactory.sol/StreamManagerFactory.json");

// Before executing a real deployment, be sure to set these values as appropriate for the environment being deployed
// to. The values used in the script at the time of deployment can be checked in along with the deployment artifacts
// produced by running the scripts.
const contractName = "StreamManager";
const HATS_ID = 1;
const HATS = "0x32Ccb7600c10B4F7e678C7cbde199d98453D0e7e";
const SALT_NONCE = 2;
const FACTORY_ADDRESS = "0x0ab76D0635E50A644433B31f1bb8b0EC5FB19fa4";

async function main() {
  dotEnvConfig();

  const deployerPrivateKey = process.env.PRIVATE_KEY;
  if (!deployerPrivateKey) {
    throw "Please set PRIVATE_KEY in your .env file";
  }

  console.log("Deploying " + contractName + "...");

  const zkWallet = new Wallet(deployerPrivateKey);
  const deployer = new Deployer(hre, zkWallet);
  const agreementEligibility = await new Contract(
    FACTORY_ADDRESS,
    StreamManagerFactory.abi,
    deployer.zkWallet
  );

  const tx = await agreementEligibility.deployAgreementEligibility(
    SALT_NONCE
  );
  const tr = await tx.wait();
  console.log("Stream manager deployed at " + tr.contractAddress);
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
