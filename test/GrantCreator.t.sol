// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { console2 } from "../lib/forge-std/src/Test.sol";
import { BaseTest } from "./Base.t.sol";
import { GrantCreator, ClaimType, IMultiClaimsHatter, StreamManager } from "../src/GrantCreator.sol";
import { GrantCreatorHarness } from "./harnesses/GrantCreatorHarness.sol";

contract GrantCreatorTest is BaseTest {
  uint256 saltNonce = 1;

  string public VERSION = "0.1.0-zksync";

  // hats
  uint256 public tophat;
  uint256 public autoAdmin;

  uint256 public recipientHat;
  uint256 public accountabilityHat;
  uint256 public kycManagerHat;
  uint256 public agreementOwnerHat;

  string public agreement;
  string public grantName;

  uint128 public grantAmount;
  uint40 public streamDuration;

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
  }
}

contract WithInstanceTest is GrantCreatorTest {
  GrantCreator public grantCreator;

  function _deployGrantCreatorInstance(IMultiClaimsHatter _claimsHatter) public returns (GrantCreator) {
    return new GrantCreator{ salt: bytes32(abi.encodePacked(saltNonce)) }(
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

    // console2.log("HATS code length", address(HATS).code.length);
    // console2.log("CHAINING_ELIGIBILITY_FACTORY code length", address(CHAINING_ELIGIBILITY_FACTORY).code.length);
    // console2.log("AGREEMENT_ELIGIBILITY_FACTORY code length", address(AGREEMENT_ELIGIBILITY_FACTORY).code.length);
    // console2.log("ALLOWLIST_ELIGIBILITY_FACTORY code length", address(ALLOWLIST_ELIGIBILITY_FACTORY).code.length);
    // console2.log("HSG_FACTORY code length", address(HSG_FACTORY).code.length);
    // console2.log("MULTI_CLAIMS_HATTER_FACTORY code length", address(MULTI_CLAIMS_HATTER_FACTORY).code.length);
    // console2.log("LOCKUP_LINEAR code length", address(LOCKUP_LINEAR).code.length);
    // console2.log("ZK code length", address(ZK).code.length);
    // console2.log("ZK_TOKEN_GOVERNOR_TIMELOCK code length", address(ZK_TOKEN_GOVERNOR_TIMELOCK).code.length);

    // set up hats
    tophat = HATS.mintTopHat(dao, "tophat", "dao.eth/tophat");
    vm.startPrank(dao);
    autoAdmin = HATS.createHat(tophat, "autoAdmin", 1, eligibility, toggle, true, "dao.eth/autoAdmin");
    accountabilityHat =
      HATS.createHat(autoAdmin, "accountabilityHat", 1, eligibility, toggle, true, "dao.eth/accountabilityHat");
    recipientBranchRoot =
      HATS.createHat(autoAdmin, "recipientBranchRoot", 1, eligibility, toggle, true, "dao.eth/recipientBranchRoot");
    HATS.mintHat(accountabilityHat, accountabilityCouncil);
    vm.stopPrank();

    // // deploy the claims hatter and mint it to the autoAdmin hat
    claimsHatter = IMultiClaimsHatter(MULTI_CLAIMS_HATTER_FACTORY.deployModule(autoAdmin, address(HATS), "", saltNonce));
    vm.prank(dao);
    HATS.mintHat(autoAdmin, address(claimsHatter));

    // // // deploy the instance
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

contract WithHarnessTest is WithInstanceTest {
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

// FIXME predicted address doen't match actual
contract _DeployAgreementEligibilty is WithHarnessTest {
  function test_deployAgreementEligibilty() public {
    recipientHat = 1;
    agreementOwnerHat = 2;
    accountabilityHat = 3;
    agreement = "test agreement";

    address agreementEligibilityModule =
      harness.deployAgreementEligibilityModule(recipientHat, agreementOwnerHat, accountabilityHat, agreement);

    bytes memory initData = abi.encode(agreementOwnerHat, accountabilityHat, agreement);

    // AGREEMENT_ELIGIBILITY_FACTORY.deployModule(recipientHat, address(HATS), initData, saltNonce);

    assertEq(
      agreementEligibilityModule,
      AGREEMENT_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE())
    );
  }
}

// FIXME predicted address doen't match actual
contract _DeployAllowlistEligibilty is WithHarnessTest {
  function test_deployAllowlistEligibilty() public {
    recipientHat = 1;
    kycManagerHat = 2;
    accountabilityHat = 3;

    address allowlistEligibilityModule =
      harness.deployAllowlistEligibilityModule(recipientHat, kycManagerHat, accountabilityHat);

    bytes memory initData = abi.encode(kycManagerHat, accountabilityHat);

    // ALLOWLIST_ELIGIBILITY_FACTORY.deployModule(recipientHat, address(HATS), initData, saltNonce);

    assertEq(
      allowlistEligibilityModule,
      ALLOWLIST_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE())
    );
  }
}

// FIXME predicted address doen't match actual
contract _DeployChainingEligibilty is WithHarnessTest {
  function test_deployChainingEligibilty() public {
    recipientHat = 1;
    agreementOwnerHat = 2;
    accountabilityHat = 3;
    kycManagerHat = 4;
    agreement = "test agreement";

    address chainingEligibilty = harness.deployChainingEligibilityModule(
      recipientHat, agreementOwnerHat, kycManagerHat, accountabilityHat, agreement
    );

    // predict the agreement eligibility module address
    bytes memory initData = abi.encode(agreementOwnerHat, accountabilityHat, agreement);
    address agreementEligibilityModule =
      AGREEMENT_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE());

    // predict the kyc eligibility module address
    initData = abi.encode(kycManagerHat, accountabilityHat);
    address kycEligibilityModule =
      ALLOWLIST_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE());

    // predict the chaining eligibility module address
    uint256 clauseCount = 1;
    uint256[] memory clauseLengths = new uint256[](clauseCount);
    address[] memory modules = new address[](2);
    modules[0] = agreementEligibilityModule;
    modules[1] = kycEligibilityModule;
    clauseLengths[0] = 2;

    initData = abi.encode(
      clauseCount, // NUM_CONJUNCTION_CLAUSES
      clauseLengths,
      abi.encode(modules)
    );

    // console2.log(agreementEligibilityModule);
    // console2.log(kycEligibilityModule);
    // console2.logBytes(initData);

    // CHAINING_ELIGIBILITY_FACTORY.deployModule(recipientHat, address(HATS), initData, saltNonce);

    assertEq(
      chainingEligibilty,
      CHAINING_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE())
    );
  }
}

// TODO
contract _DeployHSGAndSafe is WithHarnessTest {
  function test_deployHSGAndSafe() public {
    recipientHat = 1;
    accountabilityHat = 2;
    address safe = harness.deployHSGAndSafe(recipientHat, accountabilityHat);

    // todo assert that the safe and hsg are deployed
  }
}

// TODO
contract _DeployStreamManager is WithHarnessTest { }

contract PredictStreamManagerAddress is WithHarnessTest {
  function test_predictStreamManagerAddress() public {
    recipientHat = 1;
    accountabilityHat = 2;
    grantAmount = 4000;
    streamDuration = 5000;
    address streamManager =
      harness.deployStreamManager(recipientHat, accountabilityHat, recipient, grantAmount, streamDuration);

    assertEq(
      streamManager,
      harness.predictStreamManagerAddress(accountabilityHat, grantAmount, streamDuration),
      "incorrect stream manager address"
    );
  }
}

// TODO
contract CreateGrant is WithInstanceTest {
  function test_happy() public {
    grantName = "test grant";
    agreement = "test agreement";
    kycManagerHat = 1;
    accountabilityHat = 2;
    grantAmount = 4000;
    streamDuration = 5000;
    address predictedStreamManagerAddress =
      grantCreator.predictStreamManagerAddress(accountabilityHat, grantAmount, streamDuration);

    (uint256 recipientHatId, address recipientSafe, address streamManager) = grantCreator.createGrant(
      grantName, agreement, accountabilityHat, kycManagerHat, grantAmount, streamDuration, predictedStreamManagerAddress
    );

    // assert that the recipient hat is the correct id
    assertEq(recipientHatId, HATS.getNextId(recipientHat));

    // assert that the recipientHat is set as claimableFor
    ClaimType claimType = claimsHatter.hatToClaimType(recipientHatId);
    assertEq(uint8(claimType), uint8(ClaimType.ClaimableFor));
  }
}
