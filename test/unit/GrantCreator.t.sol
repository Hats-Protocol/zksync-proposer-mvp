// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { console2 } from "../../lib/forge-std/src/Test.sol";
import { BaseTest } from "../Base.t.sol";
import { GrantCreator, ClaimType, IMultiClaimsHatter, StreamManager } from "../../src/GrantCreator.sol";
import { GrantCreatorHarness } from "../harness/GrantCreatorHarness.sol";
import { HatsSignerGateLike } from "../lib/HatsModuleInterfaces.sol";

contract GrantCreatorTest is BaseTest {
  string public VERSION = "0.1.0-zksync";

  // grant params
  string public grantName;
  string public agreement;
  uint128 public grantAmount;
  uint40 public streamDuration;

  // test accounts
  address public dao;

  function setUp() public virtual override {
    super.setUp();

    dao = ZK_TOKEN_GOVERNOR_TIMELOCK;
  }
}

contract WithInstanceTest is GrantCreatorTest {
  GrantCreator public grantCreator;

  function _deployGrantCreatorInstance(IMultiClaimsHatter _claimsHatter) public returns (GrantCreator) {
    console2.log("recipientBranchRoot", recipientBranchRoot);
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

    // set up the hats
    // _createZKSyncHatsTree();

    // // // deploy the instance
    grantCreator = _deployGrantCreatorInstance(MULTI_CLAIMS_HATTER);
  }
}

contract Deployment is WithInstanceTest {
  function test_deployParams() public {
    assertEq(address(grantCreator.ZK()), address(ZK), "incorrect ZK address");
    assertEq(address(grantCreator.LOCKUP_LINEAR()), address(LOCKUP_LINEAR), "incorrect LOCKUP_LINEAR address");
    assertEq(address(grantCreator.HATS()), address(HATS), "incorrect HATS address");
    assertEq(
      address(grantCreator.MULTI_CLAIMS_HATTER()), address(MULTI_CLAIMS_HATTER), "incorrect MULTI_CLAIMS_HATTER address"
    );
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
      MULTI_CLAIMS_HATTER,
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

contract _DeployAgreementEligibilty is WithHarnessTest {
  function test_deployAgreementEligibilty() public {
    recipientHat = 1;
    agreementOwnerHat = 2;
    accountabilityCouncilHat = 3;
    agreement = "test agreement";

    address agreementEligibilityModule =
      harness.deployAgreementEligibilityModule(recipientHat, agreementOwnerHat, accountabilityCouncilHat, agreement);

    bytes memory initData = abi.encode(agreementOwnerHat, accountabilityCouncilHat, agreement);

    // AGREEMENT_ELIGIBILITY_FACTORY.deployModule(recipientHat, address(HATS), initData, saltNonce);

    assertEq(
      agreementEligibilityModule,
      AGREEMENT_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE())
    );
  }
}

contract _DeployAllowlistEligibilty is WithHarnessTest {
  function test_deployAllowlistEligibilty() public {
    recipientHat = 1;
    kycManagerHat = 2;
    accountabilityCouncilHat = 3;

    address allowlistEligibilityModule =
      harness.deployAllowlistEligibilityModule(recipientHat, kycManagerHat, accountabilityCouncilHat);

    bytes memory initData = abi.encode(kycManagerHat, accountabilityCouncilHat);

    // ALLOWLIST_ELIGIBILITY_FACTORY.deployModule(recipientHat, address(HATS), initData, saltNonce);

    assertEq(
      allowlistEligibilityModule,
      ALLOWLIST_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE())
    );
  }
}

contract _DeployChainingEligibilty is WithHarnessTest {
  function test_deployChainingEligibilty() public {
    recipientHat = 1;
    agreementOwnerHat = 2;
    accountabilityCouncilHat = 3;
    kycManagerHat = 4;
    agreement = "test agreement";

    address chainingEligibilty = harness.deployChainingEligibilityModule(
      recipientHat, agreementOwnerHat, kycManagerHat, accountabilityCouncilHat, agreement
    );

    // predict the agreement eligibility module address
    bytes memory initData = abi.encode(agreementOwnerHat, accountabilityCouncilHat, agreement);
    address agreementEligibilityModule =
      AGREEMENT_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE());

    // predict the kyc eligibility module address
    initData = abi.encode(kycManagerHat, accountabilityCouncilHat);
    address kycEligibilityModule =
      ALLOWLIST_ELIGIBILITY_FACTORY.getAddress(recipientHat, address(HATS), initData, harness.SALT_NONCE());

    // predict the chaining eligibility module address
    uint256 clauseCount = 1;
    uint256[] memory clauseLengths = new uint256[](clauseCount);
    // address[] memory modules = new address[](2);
    // modules[0] = agreementEligibilityModule;
    // modules[1] = kycEligibilityModule;
    clauseLengths[0] = 2;

    initData = abi.encode(
      clauseCount, // NUM_CONJUNCTION_CLAUSES
      clauseLengths,
      abi.encode(agreementEligibilityModule, kycEligibilityModule)
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
// contract _DeployHSGAndSafe is WithHarnessTest {
//   function test_deployHSGAndSafe() public {
//     recipientHat = 1;
//     accountabilityCouncilHat = 2;
//     address safe = harness.deployHSGAndSafe(recipientHat, accountabilityCouncilHat);

//     // todo assert that the safe and hsg are deployed
//   }
// }

// TODO
contract _DeployStreamManager is WithHarnessTest { }

contract PredictStreamManagerAddress is WithHarnessTest {
  function test_predictStreamManagerAddress() public {
    recipientHat = 1;
    grantAmount = 4000;
    streamDuration = 5000;
    address streamManager =
      harness.deployStreamManager(recipientHat, accountabilityCouncilHat, recipient, grantAmount, streamDuration);

    assertEq(
      streamManager,
      harness.predictStreamManagerAddress(accountabilityCouncilHat, grantAmount, streamDuration),
      "incorrect stream manager address"
    );
  }
}

contract CreateGrant is WithInstanceTest {
  function setUp() public override {
    super.setUp();

    // mint the recipient branch root hat to the grant creator so it can create the recipient hat
    vm.prank(dao);
    HATS.mintHat(recipientBranchRoot, address(grantCreator));
  }

  function test_createGrant() public {
    grantName = "test grant";
    agreement = "test agreement";
    kycManagerHat = 1;
    accountabilityCouncilHat = 2;
    grantAmount = 4000;
    streamDuration = 5000;
    address predictedStreamManagerAddress =
      grantCreator.predictStreamManagerAddress(accountabilityCouncilHat, grantAmount, streamDuration);

    (uint256 recipientHatId, address hsg,,) = grantCreator.createGrant(
      grantName,
      agreement,
      accountabilityCouncilHat,
      kycManagerHat,
      grantAmount,
      streamDuration,
      predictedStreamManagerAddress
    );

    // recipient hat assertions
    (
      string memory retDetails,
      uint32 retMaxSupply,
      , // supply
      , // eligibility
      , // toggle
      , // imageURI
      , // lastHatId
      bool retMutable_,
      // active
    ) = HATS.viewHat(recipientHatId);

    assertEq(retDetails, grantName, "incorrect grant name");
    assertEq(retMaxSupply, 1, "incorrect max supply");
    assertEq(retMutable_, true, "incorrect mutable");

    // assert that the recipientHat is the signersHat of the hsg
    assertEq(HatsSignerGateLike(hsg).signersHatId(), recipientHatId, "incorrect recipientHat");

    // assert that the recipientHat is set as claimableFor
    assertEq(uint8(MULTI_CLAIMS_HATTER.hatToClaimType(recipientHatId)), uint8(ClaimType.ClaimableFor));
  }
}
