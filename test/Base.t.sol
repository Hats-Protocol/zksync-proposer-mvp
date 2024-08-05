// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { Test, console2 } from "../lib/forge-std/src/Test.sol";
import { IHats, ISablierV2LockupLinear, IZkTokenV2 } from "../src/StreamManager.sol";
import { IHatsModuleFactory, IHatsSignerGateFactory } from "../src/GrantCreator.sol";

contract BaseTest is Test {
  string public network;
  uint256 public BLOCK_NUMBER;
  uint256 public fork;

  /// @dev config data for the current network, loaded from script/NetworkConfig.json. Foundry will parse that json in
  /// alphabetical order by key, so make sure this struct is defined accordingly.
  struct Config {
    address agreementEligibilityFactory;
    address allowlistEligibilityFactory;
    address chainingEligibilityFactory;
    address Hats;
    address hsgFactory;
    address lockupLinear;
    address multiClaimsHatterFactory;
    uint256 recipientBranchRoot;
    address ZK;
    address ZKTokenGovernor;
  }

  // Common params
  Config public config;
  IHats public HATS;
  ISablierV2LockupLinear public LOCKUP_LINEAR;
  IZkTokenV2 public ZK;
  address public ZK_TOKEN_GOVERNOR;

  function _getNetworkConfig() internal view returns (bytes memory) {
    string memory root = vm.projectRoot();
    string memory path = string.concat(root, "/script/NetworkConfig.json");
    string memory json = vm.readFile(path);
    string memory networkName = string.concat(".", network);
    return vm.parseJson(json, networkName);
  }

  function setUp() public virtual {
    network = "zkSyncSepolia";
    BLOCK_NUMBER = 3_574_400;
    fork = vm.createFork(vm.rpcUrl(network), BLOCK_NUMBER);

    // load the network config
    // config = abi.decode(_getNetworkConfig(), (Config));
    // console2.logBytes(_getNetworkConfig());
    // console2.log(address(config.agreementEligibilityFactory));
    // console2.log(address(config.allowlistEligibilityFactory));
    // console2.log(address(config.chainingEligibilityFactory));
    // console2.log(address(config.Hats));
    // console2.log(address(config.hsgFactory));
    // console2.log(address(config.lockupLinear));
    // console2.log(address(config.multiClaimsHatterFactory));
    // console2.log(config.recipientBranchRoot);
    // console2.log(address(config.ZK));
    // console2.log(config.ZKTokenGovernor);

    // set the common params from the config
    HATS = IHats(0x32Ccb7600c10B4F7e678C7cbde199d98453D0e7e);
    LOCKUP_LINEAR = ISablierV2LockupLinear(0x43864C567b89FA5fEE8010f92d4473Bf19169BBA);
    ZK = IZkTokenV2(0x69e5DC39E2bCb1C17053d2A4ee7CAEAAc5D36f96);
    ZK_TOKEN_GOVERNOR = 0x9F9b6f090AF502c5ffe9d89df13e9DBf83df5Bf7;
    // HATS = config.Hats;
    // LOCKUP_LINEAR = config.lockupLinear;
    // ZK = config.ZK;
    // ZK_TOKEN_GOVERNOR = config.ZKTokenGovernor;

    // console2.log("HATS", address(HATS));
    // console2.log("LOCKUP_LINEAR", address(LOCKUP_LINEAR));
    // console2.log("ZK", address(ZK));
    // console2.log("ZK_TOKEN_GOVERNOR", ZK_TOKEN_GOVERNOR);
  }
}
