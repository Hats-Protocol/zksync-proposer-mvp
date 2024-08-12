// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { Test, console2 } from "../lib/forge-std/src/Test.sol";
import { IHats, ISablierV2LockupLinear, IZkTokenV2 } from "../src/StreamManager.sol";
import { IHatsModuleFactory, IHatsSignerGateFactory, IMultiClaimsHatter } from "../src/GrantCreator.sol";
import { GovernorLike } from "./lib/GovernorInterfaces.sol";

contract BaseTest is Test {
  string public network;
  uint256 public BLOCK_NUMBER;
  uint256 public fork;

  uint256 saltNonce = 1;

  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  // Existing contracts
  IHatsModuleFactory public AGREEMENT_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public ALLOWLIST_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public CHAINING_ELIGIBILITY_FACTORY;
  IHats public HATS;
  IHatsSignerGateFactory public HSG_FACTORY;
  ISablierV2LockupLinear public LOCKUP_LINEAR;
  IHatsModuleFactory public MULTI_CLAIMS_HATTER_FACTORY;
  IZkTokenV2 public ZK;
  GovernorLike public ZK_TOKEN_GOVERNOR;
  address public ZK_TOKEN_GOVERNOR_TIMELOCK;

  IMultiClaimsHatter public claimsHatter;

  // test accounts
  address public eligibility = makeAddr("eligibility");
  address public toggle = makeAddr("toggle");
  // address public dao = makeAddr("dao");

  address public recipient = makeAddr("recipient");
  address public accountabilityCouncil = makeAddr("accountabilityCouncil");

  // Hats tree
  uint256 public tophat; // x
  uint256 public autoAdmin; // x.1
  uint256 public zkTokenControllerHat; // x.1.1
  uint256 public recipientBranchRoot; // x.1.1.1
  uint256 public recipientHat; // x.1.1.1.y
  uint256 public accountabilityBranchRoot; // x.1.1.2
  uint256 public accountabilityCouncilHat; // x.1.1.2.1
  uint256 public accountabilityCouncilMemberHat; // x.1.1.2.2
  uint256 public kycManagerHat; // x.1.1.2.3

  // other
  uint256 public agreementOwnerHat;

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

  function _createZKSyncHatsTree() internal {
    // the tophat is worn by the ZK Token Governor Timelock
    tophat = HATS.mintTopHat(ZK_TOKEN_GOVERNOR_TIMELOCK, "tophat", "dao.eth/tophat");
    vm.startPrank(ZK_TOKEN_GOVERNOR_TIMELOCK);
    // create the autoAdmin hat
    autoAdmin = HATS.createHat(tophat, "x.1 autoAdmin", 1, eligibility, toggle, true, "dao.eth/autoAdmin");

    // create the ZK Token Controller hat and mint it to the ZK Token Governor Timelock
    zkTokenControllerHat = HATS.createHat(
      autoAdmin, "x.1.1 ZK Token Controller", 1, eligibility, toggle, true, "dao.eth/zkTokenControllerHat"
    );
    HATS.mintHat(zkTokenControllerHat, ZK_TOKEN_GOVERNOR_TIMELOCK);

    // create the recipientBranchRoot hat
    recipientBranchRoot = HATS.createHat(
      zkTokenControllerHat, "x.1.1.1 recipientBranchRoot", 1, eligibility, toggle, true, "dao.eth/recipientBranchRoot"
    );

    // create the accountability branch hat
    accountabilityBranchRoot = HATS.createHat(
      zkTokenControllerHat,
      "x.1.1.2 accountabilityBranchRoot",
      1,
      eligibility,
      toggle,
      true,
      "dao.eth/accountabilityBranchRoot"
    );

    // create the accountabilityCouncilHat and mint it to the accountabilityCouncil
    accountabilityCouncilHat = HATS.createHat(
      accountabilityBranchRoot,
      "x.1.1.2.1 accountabilityCouncilHat",
      1,
      eligibility,
      toggle,
      true,
      "dao.eth/accountabilityCouncilHat"
    );
    HATS.mintHat(accountabilityCouncilHat, accountabilityCouncil);

    // create the accountabilityCouncilMemberHat
    accountabilityCouncilMemberHat = HATS.createHat(
      accountabilityBranchRoot,
      "x.1.1.2.2 accountabilityCouncilMemberHat",
      1,
      eligibility,
      toggle,
      true,
      "dao.eth/accountabilityCouncilMemberHat"
    );

    // create the kycManagerHat
    kycManagerHat = HATS.createHat(
      zkTokenControllerHat, "x.1.1.2.3 kycManagerHat", 1, eligibility, toggle, true, "dao.eth/kycManagerHat"
    );

    // deploy the claims hatter and mint it to the autoAdmin hat
    claimsHatter = IMultiClaimsHatter(MULTI_CLAIMS_HATTER_FACTORY.deployModule(autoAdmin, address(HATS), "", saltNonce));
    HATS.mintHat(autoAdmin, address(claimsHatter));
    vm.stopPrank();
  }

  function setUp() public virtual {
    network = "zkSyncSepolia";
    BLOCK_NUMBER = 3_591_535;
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
    ZK_TOKEN_GOVERNOR = GovernorLike(0x98fF5B31bBa84f5Ad05a7635a436151F74aDa466);
    ZK_TOKEN_GOVERNOR_TIMELOCK = 0x0d9DD6964692a0027e1645902536E7A3b34AA1d7;

    // ZK_TOKEN_MINTER_ADMIN = 0xD64e136566a9E04eb05B30184fF577F52682D182;
    // HATS = config.Hats;
    // LOCKUP_LINEAR = config.lockupLinear;
    // ZK = config.ZK;
    // ZK_TOKEN_GOVERNOR = config.ZKTokenGovernor;

    // console2.log("HATS", address(HATS));
    // console2.log("LOCKUP_LINEAR", address(LOCKUP_LINEAR));
    // console2.log("ZK", address(ZK));
    // console2.log("ZK_TOKEN_GOVERNOR", ZK_TOKEN_GOVERNOR);

    // set params from config
    CHAINING_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x5fe98594F3b83FC8dcd63ee5a6FA4C2b685a8F48);
    AGREEMENT_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x18eE7bC80dD334D782C84E106216EB30f86D1CA9);
    ALLOWLIST_ELIGIBILITY_FACTORY = IHatsModuleFactory(0xA29Ae9e5147F2D1211F23D323e4b2F3055E984B0);
    HSG_FACTORY = IHatsSignerGateFactory(0xAa5ECbAE5D3874A5b0CFD1c24bd4E2c0Fb305c32);
    MULTI_CLAIMS_HATTER_FACTORY = IHatsModuleFactory(0x3f049Dee8D91D56708066F5b9480A873a4F75ae2);
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
