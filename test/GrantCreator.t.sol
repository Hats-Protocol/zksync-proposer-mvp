// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { console2 } from "../lib/forge-std/src/Test.sol";
import { BaseTest } from "./Base.t.sol";
import { GrantCreator, IHatsModuleFactory, IHatsSignerGateFactory, IMultiClaimsHatter } from "../src/GrantCreator.sol";
import { GrantCreatorHarness } from "./harnesses/GrantCreatorHarness.sol";

contract GrantCreatorTest is BaseTest {
  uint256 saltNonce = 1;

  string public VERSION = "0.1.0-zksync";

  // params
  uint256 public recipientBranchRoot;
  IHatsModuleFactory public CHAINING_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public AGREEMENT_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public ALLOWLIST_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public MULTI_CLAIMS_HATTER_FACTORY;
  IHatsSignerGateFactory public HSG_FACTORY;

  // hats
  uint256 public tophat;
  uint256 public autoAdmin;

  uint256 public accountabilityHat;

  // test accounts
  address public eligibility = makeAddr("eligibility");
  address public toggle = makeAddr("toggle");
  address public dao = makeAddr("dao");
  IMultiClaimsHatter public claimsHatter;
  address public recipient = makeAddr("recipient");
  address public accountabilityCouncil = makeAddr("accountabilityCouncil");
  address public nonWearer = makeAddr("nonWearer");

  function setUp() public virtual override {
    super.setUp();

    // set params from config
    CHAINING_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x2C8AE0B842562C8B8C35E90F51d20D39C3c018F6);
    AGREEMENT_ELIGIBILITY_FACTORY = IHatsModuleFactory(0x0ab76D0635E50A644433B31f1bb8b0EC5FB19fa4);
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

contract WithInstanceTest is GrantCreatorTest {
  GrantCreator public grantCreator;

  function _deployGrantCreatorInstance(IMultiClaimsHatter _claimsHatter) public returns (GrantCreator) {
    return new GrantCreator(
      HATS,
      _claimsHatter,
      CHAINING_ELIGIBILITY_FACTORY,
      AGREEMENT_ELIGIBILITY_FACTORY,
      ALLOWLIST_ELIGIBILITY_FACTORY,
      HSG_FACTORY,
      LOCKUP_LINEAR,
      address(ZK),
      recipientBranchRoot
    );
  }

  function setUp() public virtual override {
    super.setUp();

    console2.log("HATS code length", address(HATS).code.length);
    console2.log("CHAINING_ELIGIBILITY_FACTORY code length", address(CHAINING_ELIGIBILITY_FACTORY).code.length);
    console2.log("AGREEMENT_ELIGIBILITY_FACTORY code length", address(AGREEMENT_ELIGIBILITY_FACTORY).code.length);
    console2.log("ALLOWLIST_ELIGIBILITY_FACTORY code length", address(ALLOWLIST_ELIGIBILITY_FACTORY).code.length);
    console2.log("HSG_FACTORY code length", address(HSG_FACTORY).code.length);
    console2.log("MULTI_CLAIMS_HATTER_FACTORY code length", address(MULTI_CLAIMS_HATTER_FACTORY).code.length);

    // set up hats
    // HATS.mintTopHat(dao, "tophat", "dao.eth/tophat");
    // vm.startPrank(dao);
    // autoAdmin = HATS.createHat(tophat, "autoAdmin", 1, eligibility, toggle, true, "dao.eth/autoAdmin");
    // accountabilityHat =
    //   HATS.createHat(autoAdmin, "accountabilityHat", 1, eligibility, toggle, true, "dao.eth/accountabilityHat");
    // recipientBranchRoot =
    //   HATS.createHat(autoAdmin, "recipientBranchRoot", 1, eligibility, toggle, true, "dao.eth/recipientBranchRoot");
    // HATS.mintHat(accountabilityHat, accountabilityCouncil);
    // vm.stopPrank();

    // deploy the claims hatter and mint it to the autoAdmin hat
    claimsHatter = IMultiClaimsHatter(MULTI_CLAIMS_HATTER_FACTORY.deployModule(autoAdmin, address(HATS), "", saltNonce));
    vm.prank(dao);
    HATS.mintHat(autoAdmin, address(claimsHatter));

    // // deploy the instance
    grantCreator = _deployGrantCreatorInstance(claimsHatter);
  }
}

contract Deployment is WithInstanceTest {
  function test_deployParams() public {
    assertEq(address(grantCreator.ZK()), address(ZK), "incorrect ZK address");
    assertEq(address(grantCreator.LOCKUP_LINEAR()), address(LOCKUP_LINEAR), "incorrect LOCKUP_LINEAR address");
    assertEq(address(grantCreator.HATS()), address(HATS), "incorrect HATS address");
    assertEq(address(grantCreator.MULTI_CLAIMS_HATTER()), address(claimsHatter), "incorrect claimsHatter address");
    assertEq(address(grantCreator.HATS_SIGNER_GATE_FACTORY()), address(HSG_FACTORY), "incorrect HSG_FACTORY address");
    assertEq(
      address(grantCreator.CHAINING_ELIGIBILITY_FACTORY()),
      address(CHAINING_ELIGIBILITY_FACTORY),
      "incorrect CHAINING_ELIGIBILITY_FACTORY address"
    );
    assertEq(
      address(grantCreator.AGREEMENT_ELIGIBILITY_FACTORY()),
      address(AGREEMENT_ELIGIBILITY_FACTORY),
      "incorrect AGREEMENT_ELIGIBILITY_FACTORY address"
    );
    assertEq(
      address(grantCreator.ALLOWLIST_ELIGIBILITY_FACTORY()),
      address(ALLOWLIST_ELIGIBILITY_FACTORY),
      "incorrect ALLOWLIST_ELIGIBILITY_FACTORY address"
    );
    assertEq(grantCreator.RECIPIENT_BRANCH_ROOT(), recipientBranchRoot, "incorrect RECIPIENT_BRANCH_ROOT");
  }
}

contract WithHarnessTest is GrantCreatorTest {
  GrantCreatorHarness public harness;

  function setUp() public virtual override {
    super.setUp();
    harness = new GrantCreatorHarness(
      HATS,
      claimsHatter,
      CHAINING_ELIGIBILITY_FACTORY,
      AGREEMENT_ELIGIBILITY_FACTORY,
      ALLOWLIST_ELIGIBILITY_FACTORY,
      HSG_FACTORY,
      LOCKUP_LINEAR,
      address(ZK),
      recipientBranchRoot
    );
  }
}

contract _DeployAgreementEligibilty is WithHarnessTest { }

contract _DeployAllowlistEligibilty is WithHarnessTest { }

contract _DeployChainingEligibilty is WithHarnessTest { }

contract _DeployHSGAndSafe is WithHarnessTest { }

contract _DeployStreamManager is WithHarnessTest { }

contract PredictStreamManagerAddress is WithInstanceTest { }

contract CreateGrant is WithInstanceTest { }
