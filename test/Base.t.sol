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

  // Existing contracts on
  IHats HATS = IHats(0x32Ccb7600c10B4F7e678C7cbde199d98453D0e7e);
  ISablierV2LockupLinear LOCKUP_LINEAR = ISablierV2LockupLinear(0x43864C567b89FA5fEE8010f92d4473Bf19169BBA);
  IZkTokenV2 ZK = IZkTokenV2(0x69e5DC39E2bCb1C17053d2A4ee7CAEAAc5D36f96);
  GovernorLike ZK_TOKEN_GOVERNOR = GovernorLike(0x98fF5B31bBa84f5Ad05a7635a436151F74aDa466);
  address ZK_TOKEN_GOVERNOR_TIMELOCK = 0x0d9DD6964692a0027e1645902536E7A3b34AA1d7;
  IHatsModuleFactory CHAINING_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x5fe98594F3b83FC8dcd63ee5a6FA4C2b685a8F48);
  IHatsModuleFactory AGREEMENT_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x497f71Fb4bBebf53fbC0EF4e6d99BDACE3c00463);
  IHatsModuleFactory ALLOWLIST_ELIGIBILITY_FACTORY = IHatsModuleFactory(0xA29Ae9e5147F2D1211F23D323e4b2F3055E984B0);
  IHatsModuleFactory MULTI_CLAIMS_HATTER_FACTORY = IHatsModuleFactory(0x3f049Dee8D91D56708066F5b9480A873a4F75ae2);
  IHatsSignerGateFactory HSG_FACTORY = IHatsSignerGateFactory(0xAa5ECbAE5D3874A5b0CFD1c24bd4E2c0Fb305c32);
  IMultiClaimsHatter MULTI_CLAIMS_HATTER = IMultiClaimsHatter(0x38A037A2c1f8c76e24fe583CBe9Ff8855bb888F4);

  // test accounts
  address public eligibility = makeAddr("eligibility");
  address public toggle = makeAddr("toggle");
  // address public dao = makeAddr("dao");

  address public recipient = makeAddr("recipient");
  address public accountabilityCouncil = 0xA7a5A2745f10D5C23d75a6fd228A408cEDe1CAE5;

  // Hats tree

  // x
  uint256 public tophat = 0x0000000200000000000000000000000000000000000000000000000000000000;
  // x.1
  uint256 public autoAdmin = 0x0000000200010000000000000000000000000000000000000000000000000000;
  // x.1.1
  uint256 public zkTokenControllerHat = 0x0000000200010001000000000000000000000000000000000000000000000000;
  // x.1.1.1
  uint256 public recipientBranchRoot = 0x0000000200010001000100000000000000000000000000000000000000000000;
  // x.1.1.1.y
  uint256 public recipientHat;
  // x.1.1.2
  uint256 public accountabilityBranchRoot = 0x0000000200010001000200000000000000000000000000000000000000000000;
  // x.1.1.2.1
  uint256 public accountabilityCouncilHat = 0x0000000200010001000200010000000000000000000000000000000000000000;
  // x.1.1.2.2
  uint256 public accountabilityCouncilMemberHat = 0x0000000200010001000200020000000000000000000000000000000000000000;
  // x.1.1.3
  uint256 public operationsBranchRoot = 0x0000000200010001000300000000000000000000000000000000000000000000;
  // x.1.1.3.1
  uint256 public kycManagerHat = 0x0000000200010001000300010000000000000000000000000000000000000000;

  // other
  uint256 public agreementOwnerHat;

  function setUp() public virtual {
    network = "zkSyncSepolia";
    // BLOCK_NUMBER = 3_591_535; // before creating the hats
    BLOCK_NUMBER = 3_610_782;
    fork = vm.createSelectFork(vm.rpcUrl(network), BLOCK_NUMBER);

    // load the network config
    // config = abi.decode(_getNetworkConfig(), (Config));
    // console2.logBytes(_getNetworkConfig());

    // set the common params from the config
  }

  /// @dev config data for the current network, loaded from script/NetworkConfig.json. Foundry will parse that json in
  /// alphabetical order by key, so make sure this struct is defined accordingly.
  // struct Config {
  //   address agreementEligibilityFactory;
  //   address allowlistEligibilityFactory;
  //   address chainingEligibilityFactory;
  //   address Hats;
  //   address hsgFactory;
  //   address lockupLinear;
  //   address multiClaimsHatterFactory;
  //   uint256 recipientBranchRoot;
  //   address ZK;
  // }

  // Common params
  // Config public config;

  // function _getNetworkConfig() internal view returns (bytes memory) {
  //   string memory root = vm.projectRoot();
  //   string memory path = string.concat(root, "/script/NetworkConfig.json");
  //   string memory json = vm.readFile(path);
  //   string memory networkName = string.concat(".", network);
  //   return vm.parseJson(json, networkName);
  // }

  // function _createZKSyncHatsTree() internal {
  //   // the tophat is worn by the ZK Token Governor Timelock
  //   tophat = HATS.mintTopHat(ZK_TOKEN_GOVERNOR_TIMELOCK, "tophat", "dao.eth/tophat");
  //   vm.startPrank(ZK_TOKEN_GOVERNOR_TIMELOCK);
  //   // create the autoAdmin hat
  //   autoAdmin = HATS.createHat(tophat, "x.1 autoAdmin", 1, eligibility, toggle, true, "dao.eth/autoAdmin");

  //   // create the ZK Token Controller hat and mint it to the ZK Token Governor Timelock
  //   zkTokenControllerHat = HATS.createHat(
  //     autoAdmin, "x.1.1 ZK Token Controller", 1, eligibility, toggle, true, "dao.eth/zkTokenControllerHat"
  //   );
  //   HATS.mintHat(zkTokenControllerHat, ZK_TOKEN_GOVERNOR_TIMELOCK);

  //   // create the recipientBranchRoot hat
  //   recipientBranchRoot = HATS.createHat(
  //     zkTokenControllerHat, "x.1.1.1 recipientBranchRoot", 1, eligibility, toggle, true,
  // "dao.eth/recipientBranchRoot"
  //   );

  //   // create the accountability branch hat
  //   accountabilityBranchRoot = HATS.createHat(
  //     zkTokenControllerHat,
  //     "x.1.1.2 accountabilityBranchRoot",
  //     1,
  //     eligibility,
  //     toggle,
  //     true,
  //     "dao.eth/accountabilityBranchRoot"
  //   );

  //   // create the accountabilityCouncilHat and mint it to the accountabilityCouncil
  //   accountabilityCouncilHat = HATS.createHat(
  //     accountabilityBranchRoot,
  //     "x.1.1.2.1 accountabilityCouncilHat",
  //     1,
  //     eligibility,
  //     toggle,
  //     true,
  //     "dao.eth/accountabilityCouncilHat"
  //   );
  //   HATS.mintHat(accountabilityCouncilHat, accountabilityCouncil);

  //   // create the accountabilityCouncilMemberHat
  //   accountabilityCouncilMemberHat = HATS.createHat(
  //     accountabilityBranchRoot,
  //     "x.1.1.2.2 accountabilityCouncilMemberHat",
  //     1,
  //     eligibility,
  //     toggle,
  //     true,
  //     "dao.eth/accountabilityCouncilMemberHat"
  //   );

  //   // create the kycManagerHat
  //   kycManagerHat = HATS.createHat(
  //     zkTokenControllerHat, "x.1.1.2.3 kycManagerHat", 1, eligibility, toggle, true, "dao.eth/kycManagerHat"
  //   );

  // deploy the claims hatter and mint it to the autoAdmin hat
  // claimsHatter = IMultiClaimsHatter(MULTI_CLAIMS_HATTER_FACTORY.deployModule(autoAdmin, address(HATS), "",
  // saltNonce));
  // HATS.mintHat(autoAdmin, address(claimsHatter));
  // vm.stopPrank();
  // }
}
