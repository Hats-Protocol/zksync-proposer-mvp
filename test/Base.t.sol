// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { Test, console2 } from "../lib/forge-std/src/Test.sol";
import { IHats, ISablierV2LockupLinear, IZkTokenV2 } from "../src/StreamManager.sol";
import { IHatsModuleFactory, IHatsSignerGateFactory } from "../src/GrantCreator.sol";

contract BaseTest is Test {
  string public network;
  uint256 public BLOCK_NUMBER;
  uint256 public fork;

  IHatsModuleFactory public AGREEMENT_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public ALLOWLIST_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public CHAINING_ELIGIBILITY_FACTORY;
  IHats public HATS;
  IHatsSignerGateFactory public HSG_FACTORY;
  ISablierV2LockupLinear public LOCKUP_LINEAR;
  IHatsModuleFactory public MULTI_CLAIMS_HATTER_FACTORY;
  uint256 public recipientBranchRoot;
  IZkTokenV2 public ZK;
  address public ZK_TOKEN_GOVERNOR_TIMELOCK;
  address public ZK_TOKEN_MINTER_ADMIN;

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

  function _getNetworkConfig() internal view returns (bytes memory) {
    string memory root = vm.projectRoot();
    string memory path = string.concat(root, "/script/NetworkConfig.json");
    string memory json = vm.readFile(path);
    string memory networkName = string.concat(".", network);
    return vm.parseJson(json, networkName);
  }

  function setUp() public virtual {
    network = "zkSyncSepolia";
    BLOCK_NUMBER = 3_577_635;
    fork = vm.createSelectFork(vm.rpcUrl(network), BLOCK_NUMBER);

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
    ZK_TOKEN_GOVERNOR_TIMELOCK = 0x6fEB7Ca79CFD7e1CF761c7Aa8659F24e392fbc7D;
    ZK_TOKEN_MINTER_ADMIN = 0xD64e136566a9E04eb05B30184fF577F52682D182;
    // HATS = config.Hats;
    // LOCKUP_LINEAR = config.lockupLinear;
    // ZK = config.ZK;
    // ZK_TOKEN_GOVERNOR = config.ZKTokenGovernor;

    // console2.log("HATS", address(HATS));
    // console2.log("LOCKUP_LINEAR", address(LOCKUP_LINEAR));
    // console2.log("ZK", address(ZK));
    // console2.log("ZK_TOKEN_GOVERNOR", ZK_TOKEN_GOVERNOR);

    // set params from config
    CHAINING_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x2C8AE0B842562C8B8C35E90F51d20D39C3c018F6);
    AGREEMENT_ELIGIBILITY_FACTORY = IHatsModuleFactory(0xc5c92a89d7664Ef02d6d10FC3Fe313CC4A781553);
    ALLOWLIST_ELIGIBILITY_FACTORY = IHatsModuleFactory(0xa3DabD368bAE702199959e55560F688C213fBb3c);
    HSG_FACTORY = IHatsSignerGateFactory(0xAa5ECbAE5D3874A5b0CFD1c24bd4E2c0Fb305c32);
    MULTI_CLAIMS_HATTER_FACTORY = IHatsModuleFactory(0x6175C315720E9Ca084414AA6A2d0abC9C74E60c0);
    // CHAINING_ELIGIBILITY_FACTORY = IHatsModuleFactory(config.chainingEligibilityFactory);
    // AGREEMENT_ELIGIBILITY_FACTORY = IHatsModuleFactory(config.agreementEligibilityFactory);
    // ALLOWLIST_ELIGIBILITY_FACTORY = IHatsModuleFactory(config.allowlistEligibilityFactory);
    // HSG_FACTORY = IHatsSignerGateFactory(config.hsgFactory);
    // MULTI_CLAIMS_HATTER_FACTORY = IHatsModuleFactory(config.multiClaimsHatterFactory);

    // console2.log("CHAINING_ELIGIBILITY_FACTORY", address(CHAINING_ELIGIBILITY_FACTORY));
    // console2.log("AGREEMENT_ELIGIBILITY_FACTORY", address(AGREEMENT_ELIGIBILITY_FACTORY));
    // console2.log("ALLOWLIST_ELIGIBILITY_FACTORY", address(ALLOWLIST_ELIGIBILITY_FACTORY));
    // console2.log("HSG_FACTORY", address(HSG_FACTORY));
    // console2.log("MULTI_CLAIMS_HATTER_FACTORY", address(MULTI_CLAIMS_HATTER_FACTORY));
  }
}
