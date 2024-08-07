import { config as dotEnvConfig } from "dotenv";
import { Deployer } from "@matterlabs/hardhat-zksync-deploy";
import { Wallet } from "zksync-ethers";
import * as hre from "hardhat";

// Before executing a real deployment, be sure to set these values as appropriate for the environment being deployed
// to. The values used in the script at the time of deployment can be checked in along with the deployment artifacts
// produced by running the scripts.
const contractName = "GrantCreator";
async function main() {
  dotEnvConfig();

  const deployerPrivateKey = process.env.PRIVATE_KEY;
  if (!deployerPrivateKey) {
    throw "Please set PRIVATE_KEY in your .env file";
  }

  console.log("Deploying " + contractName + "...");

  const zkWallet = new Wallet(deployerPrivateKey);
  const deployer = new Deployer(hre, zkWallet);

  // get the deployment config for the current network
  const configData = require("./NetworkConfig.json");
  const config = configData[hre.network.name];

  const contract = await deployer.loadArtifact(contractName);
  console.log(config.Hats);
  const constructorArgs: any = [config.Hats, config.ChainingEligibilityFactory, config.AgreementEligibilityFactory, config.AllowlistEligibilityFactory, config.HatsSignerGateFactory, config.LockupLinear, config.ZKToken, config.RecipientBranchRoot];

  const grantCreator = await deployer.deploy(
    contract,
    constructorArgs,
    "create2",
    {
      customData: {
        salt: "0x0000000000000000000000000000000000000000000000000000000000004a75",
      },
    }
  );
  console.log(
    "constructor args:" +
    grantCreator.interface.encodeDeploy(constructorArgs)
  );
  console.log(
    `${contractName} was deployed to ${await grantCreator.getAddress()}`
  );
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
