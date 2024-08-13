// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { console2, Vm } from "../../lib/forge-std/src/Test.sol";
import {
  WithInstanceTest as WithGrantCreatorTest,
  GrantCreator,
  IMultiClaimsHatter,
  StreamManager
} from "../unit/GrantCreator.t.sol";
import {
  AgreementEligibilityModuleLike,
  AllowlistEligibilityModuleLike,
  HatsEligibilitiesChainLike,
  HatsSignerGateLike,
  IHatsEligibility
} from "../../test/lib/HatsModuleInterfaces.sol";
import { TimelockControllerLike, GovernorLike } from "../../test/lib/GovernorInterfaces.sol";
import { NotAuthorized } from "../../src/StreamManager.sol";
// import { ISablierLockupLinear } from "../Base.t.sol";

/// @dev Tests the recipient and streaming logic. Assumes the proposal has been executed to create the grant.
contract FullFlowTest is WithGrantCreatorTest {
  address public hsg;
  address public recipientSafe;
  StreamManager public streamManager;
  // address public kycOperator = makeAddr("kycOperator");
  address public kycOperator = 0xf48928b8d6C04122778aD74C64886D972decA39F;

  address public whale = 0x624123ec4A9f48Be7AA8a307a74381E4ea7530D4; // balance of 10,050 token

  function setUp() public virtual override {
    super.setUp();

    // set grant params
    grantName = "Test Grant";
    agreement = "Test Agreement";
    // accountabilityCouncilHat;
    // kycManagerHat;
    grantAmount = 10_000 ether; // 10,000 ZK tokens
    streamDuration = 100 days;

    // mint the recipient branch hat to the grant creator
    vm.prank(ZK_TOKEN_GOVERNOR_TIMELOCK);
    HATS.mintHat(recipientBranchRoot, address(grantCreator));

    // // mint the kyc manager hat to the kyc operator
    // vm.prank(ZK_TOKEN_GOVERNOR_TIMELOCK);
    // HATS.mintHat(kycManagerHat, kycOperator);
  }

  function _encodeGrantMinterRoleCall(address _streamManager) internal view returns (bytes memory) {
    return abi.encodeWithSelector(ZK.grantRole.selector, MINTER_ROLE, _streamManager);
  }

  function _encodeCreateGrantCall(address _streamManager) internal view returns (bytes memory) {
    return abi.encodeWithSelector(
      grantCreator.createGrant.selector,
      grantName,
      agreement,
      accountabilityCouncilHat,
      kycManagerHat,
      grantAmount,
      streamDuration,
      _streamManager
    );
  }

  // function _getGrantDataFromProposalExecutionLogs(Vm.Log[] memory _logs)
  //   internal
  //   view
  //   returns (uint256 _recipientHat, address _hsg, address _recipientSafe, address _streamManager)
  // {
  //   // print the log length
  //   console2.log("Log length", _logs.length);
  // }

  function _submitProposal(address _proposer)
    internal
    returns (
      uint256 proposalId,
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      bytes32 descriptionHash
    )
  {
    // predict the stream manager address
    address predictedStreamManagerAddress =
      grantCreator.predictStreamManagerAddress(accountabilityCouncilHat, grantAmount, streamDuration);

    targets = new address[](2);
    targets[0] = address(ZK);
    targets[1] = address(grantCreator);

    values = new uint256[](2); // should be empty

    calldatas = new bytes[](2);
    calldatas[0] = _encodeGrantMinterRoleCall(predictedStreamManagerAddress);
    calldatas[1] = _encodeCreateGrantCall(predictedStreamManagerAddress);

    string memory description = "Test Create Grant Proposal";
    descriptionHash = keccak256(bytes(description));

    // submit the proposal
    vm.prank(_proposer);
    proposalId = ZK_TOKEN_GOVERNOR.propose(targets, values, calldatas, description);

    console2.log("Proposal submitted", proposalId);
  }

  function _passAndExecuteProposal(
    address _voter,
    uint256 _proposalId,
    address[] memory _targets,
    uint256[] memory _values,
    bytes[] memory _calldatas,
    bytes32 _descriptionHash
  ) internal returns (uint256 _recipientHat, address _hsg, address _recipientSafe, StreamManager _streamManager) {
    // warp ahead to the end of the voting delay
    vm.warp(block.timestamp + ZK_TOKEN_GOVERNOR.votingDelay() + 1);

    // vote for the proposal
    vm.prank(_voter);
    ZK_TOKEN_GOVERNOR.castVote(_proposalId, 1); // 1 = for

    // warp ahead to the end of the voting period
    vm.warp(block.timestamp + ZK_TOKEN_GOVERNOR.votingPeriod() + 1);

    // queue the proposal
    ZK_TOKEN_GOVERNOR.queue(_targets, _values, _calldatas, _descriptionHash);

    // warp ahead to the end of the timelock period
    vm.warp(block.timestamp + TimelockControllerLike(ZK_TOKEN_GOVERNOR_TIMELOCK).getMinDelay() + 1);

    // execute the proposal
    // vm.recordLogs();
    ZK_TOKEN_GOVERNOR.execute(_targets, _values, _calldatas, _descriptionHash);
    // Vm.Log[] memory logs = vm.getRecordedLogs();

    // set the resulting artifacts
    /// @dev We get most of them from logs from a previous run using _createGrant(). This is a hack.
    _recipientHat = 0x0000000200010001000100010000000000000000000000000000000000000000;
    _hsg = 0x1daf89b739080C3AE23Fb459ea090354d46033De;
    _recipientSafe = 0xBd30D2f8796160CE04e95d5bD7F80205E4630054;
    _streamManager =
      StreamManager(grantCreator.predictStreamManagerAddress(accountabilityCouncilHat, grantAmount, streamDuration));

    console2.log("Proposal executed");
  }

  function _submitPassAndExecuteProposal()
    internal
    returns (uint256 _recipientHat, address _hsg, address _recipientSafe, StreamManager _streamManager)
  {
    // submit the proposal
    (
      uint256 proposalId,
      address[] memory targets,
      uint256[] memory values,
      bytes[] memory calldatas,
      bytes32 descriptionHash
    ) = _submitProposal(whale);

    // pass and execute the proposal
    (_recipientHat, _hsg, _recipientSafe, _streamManager) =
      _passAndExecuteProposal(whale, proposalId, targets, values, calldatas, descriptionHash);
  }

  /// @dev Creates the grant and returns the resulting recipient hat, recipient safe, and stream manager
  function _createGrant()
    internal
    returns (uint256 _recipientHat, address _hsg, address _recipientSafe, StreamManager _streamManager)
  {
    // predict the stream manager address
    address streamManagerAddress =
      grantCreator.predictStreamManagerAddress(accountabilityCouncilHat, grantAmount, streamDuration);

    // if this succeeds, we know that the predictedStreamManagerAddress is correct
    (_recipientHat, _hsg, _recipientSafe,) = grantCreator.createGrant(
      grantName, agreement, accountabilityCouncilHat, kycManagerHat, grantAmount, streamDuration, streamManagerAddress
    );

    // make the stream manager a minter for the recipient safe
    _grantMinterRole(streamManagerAddress);

    _streamManager = StreamManager(streamManagerAddress);

    console2.log("Grant created");
  }

  function _grantMinterRole(address _streamManager) internal {
    // set the stream manager as the minter
    vm.prank(ZK_TOKEN_GOVERNOR_TIMELOCK);
    ZK.grantRole(MINTER_ROLE, _streamManager);

    console2.log("Minter role granted to stream manager", _streamManager);
  }

  function _getEligibilityChainModule(uint256 _recipientHat) internal view returns (HatsEligibilitiesChainLike) {
    return HatsEligibilitiesChainLike(HATS.getHatEligibilityModule(_recipientHat));
  }

  function _getAgreementEligibilityModule(uint256 _recipientHat) internal view returns (AgreementEligibilityModuleLike) {
    HatsEligibilitiesChainLike eligibilityChainModule = _getEligibilityChainModule(_recipientHat);
    address[] memory modules = eligibilityChainModule.MODULES();
    return AgreementEligibilityModuleLike(modules[0]);
  }

  function _getAllowlistEligibilityModule(uint256 _recipientHat) internal view returns (AllowlistEligibilityModuleLike) {
    HatsEligibilitiesChainLike eligibilityChainModule = _getEligibilityChainModule(_recipientHat);
    address[] memory modules = eligibilityChainModule.MODULES();
    return AllowlistEligibilityModuleLike(modules[1]);
  }

  function _passKYC(address _recipient, uint256 _recipientHat) internal {
    // get the kyc eligibility module for the recipient hat
    AllowlistEligibilityModuleLike kycEligibilityModule = _getAllowlistEligibilityModule(_recipientHat);

    // the kyc operator approves KYC for the recipient
    vm.prank(kycOperator);
    kycEligibilityModule.addAccount(_recipient);

    // assert that the recipient is now eligible according to the kyc eligibility module
    (bool eligible, bool standing) = kycEligibilityModule.getWearerStatus(_recipient, _recipientHat);
    assertEq(eligible, true);
    assertEq(standing, true);

    console2.log("Passed KYC", _recipient);
  }

  function _signAgreementAndClaimHat(address _recipient, uint256 _recipientHat) internal {
    // get the agreement eligibility module for the recipient hat
    AgreementEligibilityModuleLike agreementEligibilityModule = _getAgreementEligibilityModule(_recipientHat);

    // the recipient signs the agreement and claims the recipient hat
    vm.prank(_recipient);
    agreementEligibilityModule.signAgreementAndClaimHat(address(MULTI_CLAIMS_HATTER));

    // assert that the recipient is now eligible according to the agreement eligibility module
    (bool eligible, bool standing) = agreementEligibilityModule.getWearerStatus(_recipient, _recipientHat);
    assertEq(eligible, true);
    assertEq(standing, true);

    // assert that the recipient is now wearing the recipient hat
    assertTrue(HATS.isWearerOfHat(_recipient, _recipientHat));

    console2.log("Recipient hat claimed");
  }

  function _claimSignerRights(address _recipient) internal {
    console2.log("starting claimSigner");
    assertEq(HatsSignerGateLike(hsg).signersHatId(), recipientHat, "hsg.signersHatId() != recipientHat");
    vm.prank(_recipient);
    HatsSignerGateLike(hsg).claimSigner();

    console2.log("Signer rights claimed");
  }

  function _createStream(address _recipient) internal {
    // cache the sablier ZK token balance
    uint256 preStreamBalance = ZK.balanceOf(address(LOCKUP_LINEAR));

    // cache the ZK token supply
    uint256 preSupply = ZK.totalSupply();

    vm.prank(_recipient);
    streamManager.createStream();

    // assert that the sablier ZK token balance has increased by the grant amount
    assertEq(ZK.balanceOf(address(LOCKUP_LINEAR)), preStreamBalance + grantAmount);

    // assert that the ZK token supply has increased by the grant amount
    assertEq(ZK.totalSupply(), preSupply + grantAmount);

    console2.log("Stream created");
  }

  function _withdrawFromStream(address _recipientSafe, uint40 _elapsedTime) internal {
    uint256 streamId = streamManager.streamId();
    // warp forward by the elapsed time
    vm.warp(block.timestamp + _elapsedTime);

    // cache the withdrawable amount
    uint128 withdrawableAmount = LOCKUP_LINEAR.withdrawableAmountOf(streamId);

    // cache the ZK token balances
    uint256 preSablierBalance = ZK.balanceOf(address(LOCKUP_LINEAR));
    uint256 preRecipientSafeBalance = ZK.balanceOf(_recipientSafe);

    vm.prank(_recipientSafe);
    LOCKUP_LINEAR.withdraw(streamId, recipientSafe, withdrawableAmount);

    // assert that the withdrawable amount has been withdrawn
    assertEq(LOCKUP_LINEAR.withdrawableAmountOf(streamId), 0);

    // assert that the sablier ZK token balance has decreased by the withdrawable amount
    assertEq(ZK.balanceOf(address(LOCKUP_LINEAR)), preSablierBalance - withdrawableAmount);

    // assert that the recipient safe ZK token balance has increased by the withdrawable amount
    assertEq(ZK.balanceOf(_recipientSafe), preRecipientSafeBalance + withdrawableAmount);

    console2.log("Withdrew from stream");
  }

  function _cancelStream(uint40 _elapsedTime, address _refundRecipient) internal {
    // warp forward by the elapsed time
    vm.warp(block.timestamp + _elapsedTime);

    // cache the ZK token balances
    uint256 preSablierBalance = ZK.balanceOf(address(LOCKUP_LINEAR));
    uint256 preRefundableAmount = LOCKUP_LINEAR.refundableAmountOf(streamManager.streamId());
    uint256 preRefundRecipientBalance = ZK.balanceOf(_refundRecipient);

    // the accountability council cancels the stream
    vm.prank(accountabilityCouncil);
    streamManager.cancelStream(_refundRecipient);

    // assert that the sablier ZK token balance has decreased by the refundable amount
    assertEq(ZK.balanceOf(address(LOCKUP_LINEAR)), preSablierBalance - preRefundableAmount);

    // assert that the refund recipient ZK token balance has increased by the refundable amount
    assertEq(ZK.balanceOf(_refundRecipient), preRefundRecipientBalance + preRefundableAmount);

    console2.log("Stream canceled");
  }

  function _revokeHat() internal {
    // get the hat eligibility module for the recipient hat
    AgreementEligibilityModuleLike agreementEligibilityModule = _getAgreementEligibilityModule(recipientHat);

    // the accountability council revokes the recipient hat
    vm.prank(accountabilityCouncil);
    agreementEligibilityModule.revoke(recipient);

    // assert that the recipient is no longer wearing the recipient hat
    assertFalse(HATS.isWearerOfHat(recipient, recipientHat));

    console2.log("Hat revoked");
  }
}

contract FullFlow is FullFlowTest {
  function test_createGrant() public {
    // predict the stream manager address
    address predictedStreamManagerAddress =
      grantCreator.predictStreamManagerAddress(accountabilityCouncilHat, grantAmount, streamDuration);

    // encode the create grant call
    bytes memory data = _encodeCreateGrantCall(predictedStreamManagerAddress);

    // execute the create grant call via a low level call, from the ZK token governor timelock
    vm.prank(ZK_TOKEN_GOVERNOR_TIMELOCK);
    (bool success, bytes memory returnData) = address(grantCreator).call(data);
    assertTrue(success);

    address streamManagerAddress;

    // decode the return data
    (recipientHat, hsg, recipientSafe, streamManagerAddress) =
      abi.decode(returnData, (uint256, address, address, address));
  }

  function test_grantMinterRole() public {
    // predict the stream manager address
    address predictedStreamManagerAddress =
      grantCreator.predictStreamManagerAddress(accountabilityCouncilHat, grantAmount, streamDuration);

    // encode the grant minter role call
    bytes memory data = _encodeGrantMinterRoleCall(predictedStreamManagerAddress);

    // execute the grant minter role call via a low level call, from the ZK token governor timelock
    vm.prank(ZK_TOKEN_GOVERNOR_TIMELOCK);
    (bool success,) = address(ZK).call(data);

    assertTrue(success);
  }

  /// @dev Tests the happy path from grant creation (without a proposal) to stream conclusion and withdrawal
  function test_happy_withoutProposal() public {
    // create the grant
    (recipientHat, hsg, recipientSafe, streamManager) = _createGrant();
    // console2.log("hsg", hsg);
    // console2.log("recipientSafe", recipientSafe);

    // the recipient passes KYC
    _passKYC(recipient, recipientHat);
    // the recipient signs the agreement and claims the recipient hat
    _signAgreementAndClaimHat(recipient, recipientHat);
    // the recipient claims its signer rights on the recipient safe
    _claimSignerRights(recipient);
    // the recipient starts a stream
    _createStream(recipient);
    // after the stream has concluded, the recipient withdraws streamed funds to the recipient safe
    _withdrawFromStream(recipientSafe, 100 days);
  }

  /// @dev Tests the happy path for the full flow, from proposal creation to stream conclusion and withdrawal
  function test_happy_viaProposal() public {
    // create the grant via proposal
    (recipientHat, hsg, recipientSafe, streamManager) = _submitPassAndExecuteProposal();
    // the recipient passes KYC
    _passKYC(recipient, recipientHat);
    // the recipient signs the agreement and claims the recipient hat
    _signAgreementAndClaimHat(recipient, recipientHat);
    // the recipient claims its signer rights on the recipient safe
    _claimSignerRights(recipient);
    // the recipient starts a stream
    _createStream(recipient);
    // after the stream has concluded, the recipient withdraws streamed funds to the recipient safe
    _withdrawFromStream(recipientSafe, 100 days);
  }

  function test_cancelStream() public {
    // create the grant
    (recipientHat, hsg, recipientSafe, streamManager) = _submitPassAndExecuteProposal();
    // the recipient passes KYC
    _passKYC(recipient, recipientHat);
    // the recipient signs the agreement and claims the recipient hat
    _signAgreementAndClaimHat(recipient, recipientHat);
    // the recipient claims its signer rights on the recipient safe
    _claimSignerRights(recipient);
    // the recipient starts a stream
    _createStream(recipient);
    // the accountability council cancels the stream after half the stream duration has elapsed
    _cancelStream(50 days, ZK_TOKEN_GOVERNOR_TIMELOCK);
    // the recipient withdraws streamed funds to the recipient safe
    _withdrawFromStream(recipientSafe, 50 days);
  }

  function test_revokeHat() public {
    // create the grant
    (recipientHat, hsg, recipientSafe, streamManager) = _submitPassAndExecuteProposal();
    // the recipient passes KYC
    _passKYC(recipient, recipientHat);
    // the recipient signs the agreement and claims the recipient hat
    _signAgreementAndClaimHat(recipient, recipientHat);
    // the accountability council revokes the recipient hat
    _revokeHat();
    // the recipient tries to create the stream but cannot
    vm.expectRevert(NotAuthorized.selector);
    vm.prank(recipient);
    streamManager.createStream();

    // TODO should work once agreement module is fixed
  }

  function test_unclaimedHat() public {
    // create the grant
    (recipientHat, hsg, recipientSafe, streamManager) = _submitPassAndExecuteProposal();
    // the recipient passes KYC
    _passKYC(recipient, recipientHat);
    // the recipient tries to create the stream but cannot
    vm.expectRevert(NotAuthorized.selector);
    vm.prank(recipient);
    streamManager.createStream();
  }
}
