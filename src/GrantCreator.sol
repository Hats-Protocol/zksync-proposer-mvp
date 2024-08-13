// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // comment out before deploy
import { IHatsModuleFactory } from "./lib/IHatsModuleFactory.sol";
import { IMultiClaimsHatter, ClaimType } from "./lib/IMultiClaimsHatter.sol";
import { IHatsSignerGateFactory } from "./lib/IHatsSignerGateFactory.sol";
import { StreamManager, IHats, ISablierV2LockupLinear } from "./StreamManager.sol";
import { L2ContractHelper } from "./lib/L2ContractHelper.sol";

/**
 * @title GrantCreator
 * @author Haberdasher Labs
 * @notice A helper contract that creates new $ZK token grants. It is designed to be called by the ZK Token Governor as
 * the result of a proposal.
 *
 *  Proposers can define a new grant with the following parameters:
 *  - Name
 *  - Grant Agreement
 *  - Grant Amount, to be streamed
 *  - Stream Duration
 *  - Accountability judge who will hold the grant recipient accountable to the agreement
 *  - KYC manager who will process the recipients KYC
 *
 * The new grant will comprise a new StreamManager contract to manage the grant stream, a recipient Safe, and a
 * recipient hat that will — once they have passed KYC and signed the agreement — authorize the recipient to
 * initiate the stream and access the recipient Safe.
 *
 *  As part of the same proposal, the newly-deployed StreamManager contract should be authorized as a $ZK token minter,
 * otherwise the stream initiation will not work.
 *
 *  This contract must wear the `RECIPIENT_BRANCH_ROOT` hat to succesfully create a new grant.
 */
contract GrantCreator {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  error WrongRecipientHatId();
  error WrongStreamManagerAddress();

  /*//////////////////////////////////////////////////////////////
                            EVENTS
  //////////////////////////////////////////////////////////////*/

  event GrantCreated(
    uint128 amount,
    uint40 streamDuration,
    uint256 recipientHat,
    address hsg,
    address recipientSafe,
    address streamManager
  );

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  string public constant VERSION = "mvp";

  uint256 public constant SALT_NONCE = 1;

  // contracts
  IHats public immutable HATS;
  IMultiClaimsHatter public immutable MULTI_CLAIMS_HATTER;
  IHatsModuleFactory public immutable CHAINING_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public immutable AGREEMENT_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public immutable ALLOWLIST_ELIGIBILITY_FACTORY;
  IHatsSignerGateFactory public immutable HATS_SIGNER_GATE_FACTORY;
  ISablierV2LockupLinear public immutable LOCKUP_LINEAR;
  address public immutable ZK;

  uint256 public immutable RECIPIENT_BRANCH_ROOT;

  /// @dev Bytecode hash can be found in zkout/StreamManager.sol/StreamManager.json under the hash key.
  /// If deploying with hardhat, need to use the hardhat-compiled address
  bytes32 public constant STREAM_MANAGER_BYTECODE_HASH =
    0x010001ed0ebad6e741ded288b7000ba180b28486ce0f3af06a47b54e69fd7b72;

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  constructor(
    IHats _hats,
    IMultiClaimsHatter _multiClaimsHatter,
    IHatsModuleFactory _chainingEligibilityFactory,
    IHatsModuleFactory _agreementEligibilityFactory,
    IHatsModuleFactory _allowlistEligibilityFactory,
    IHatsSignerGateFactory _hatsSignerGateFactory,
    ISablierV2LockupLinear _lockupLinear,
    address _zk,
    uint256 _recipientBranchRoot
  ) {
    HATS = _hats;
    MULTI_CLAIMS_HATTER = _multiClaimsHatter;
    CHAINING_ELIGIBILITY_FACTORY = _chainingEligibilityFactory;
    AGREEMENT_ELIGIBILITY_FACTORY = _agreementEligibilityFactory;
    ALLOWLIST_ELIGIBILITY_FACTORY = _allowlistEligibilityFactory;
    HATS_SIGNER_GATE_FACTORY = _hatsSignerGateFactory;
    LOCKUP_LINEAR = _lockupLinear;
    ZK = _zk;

    RECIPIENT_BRANCH_ROOT = _recipientBranchRoot;
  }

  /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Creates a new $ZK token grant. This function is designed to be called by the $ZK token minting governor,
   * i.e. as a result of a proposal to create the grant. The grant is a new hat, with KYC and agreement eligibility
   * criteria.
   * @param _name The name of the grant.
   * @param _agreement The agreement for the grant.
   * @param _accountabilityJudgeHat The hat id of the accountability judge, whose wearer determines whether the grant
   * recipient is upholding their commitments (as outlined in the grant agreement), and can stop the grant stream and/or
   * revoke the recipient hat.
   * @param _kycManagerHat The hat id of the KYC manager, whose wearer determines whether the grant recipient has
   * completed
   * the KYC process.
   * @param _amount The amount of $ZK to grant as a stream.
   * @param _streamDuration The duration of the stream.
   * @param _predictedStreamManagerAddress The predicted address of the stream manager. A proposal should also include
   * an
   * action to grant this address the $ZK token grant minting role.
   * @return recipientHat The hat id of the recipient hat.
   * @return hsg The address of the HatsSignerGate attached to the `recipientSafe`.
   * @return recipientSafe The address of the recipient Safe.
   * @return streamManager The address of the stream manager.
   */
  function createGrant(
    string memory _name,
    string memory _agreement,
    uint256 _accountabilityJudgeHat,
    uint256 _kycManagerHat,
    uint128 _amount,
    uint40 _streamDuration,
    address _predictedStreamManagerAddress
  ) external returns (uint256 recipientHat, address hsg, address recipientSafe, address streamManager) {
    // get the id of the next recipient hat
    recipientHat = HATS.getNextId(RECIPIENT_BRANCH_ROOT);

    // deploy chained eligibility with agreement and kyc modules
    address chainingEligibilityModule = _deployChainingEligibilityModule({
      _targetHat: recipientHat,
      _agreementOwnerHat: 0, // no owner for the agreement eligibility module
      _allowlistOwnerHat: _kycManagerHat,
      _arbitratorHat: _accountabilityJudgeHat,
      _agreement: _agreement
    });

    // create recipient hat, ensuring that its id is as predicted
    if (
      HATS.createHat(
        RECIPIENT_BRANCH_ROOT, // admin
        _name, // details
        1, // maxSupply
        chainingEligibilityModule,
        address(0x4a75), // no need for toggle
        true, // mutable
        "" // no image for the MVP
      ) != recipientHat
    ) {
      revert WrongRecipientHatId();
    }

    // make recipient hat claimableFor
    MULTI_CLAIMS_HATTER.setHatClaimability(recipientHat, ClaimType.ClaimableFor);

    // deploy recipient Safe gated to recipientHat
    // TODO post-MVP: figure out the right HSG owner
    (hsg, recipientSafe) = _deployHSGAndSafe(recipientHat, _accountabilityJudgeHat);

    // deploy stream manager contract
    streamManager = _deployStreamManager(recipientHat, _accountabilityJudgeHat, recipientSafe, _amount, _streamDuration);

    // ensure the deployment address matches the predicted address
    if (_predictedStreamManagerAddress != streamManager) revert WrongStreamManagerAddress();

    emit GrantCreated(_amount, _streamDuration, recipientHat, hsg, recipientSafe, streamManager);
  }

  /**
   * @notice Predicts the address of the stream manager contract deployed with the given parameters.
   * @param _accountabilityJudgeHat The hat id of the accountability judge.
   * @param _amount The amount of $ZK to grant as a stream.
   * @param _streamDuration The duration of the stream.
   * @return The predicted address of the stream manager.
   */
  function predictStreamManagerAddress(uint256 _accountabilityJudgeHat, uint128 _amount, uint40 _streamDuration)
    public
    view
    returns (address)
  {
    return L2ContractHelper.computeCreate2Address(
      address(this),
      bytes32(SALT_NONCE),
      STREAM_MANAGER_BYTECODE_HASH,
      keccak256(
        abi.encode(
          HATS,
          ZK,
          LOCKUP_LINEAR,
          _amount,
          0, // no cliff in this MVP
          _streamDuration,
          _accountabilityJudgeHat
        )
      )
    );
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @dev Deploys a Hats agreement eligibility module.
   * @param _targetHat The id of the target hat.
   * @param _ownerHat The id of the owner hat.
   * @param _arbitratorHat The id of the arbitrator hat.
   * @param _agreement The agreement for the grant.
   * @return The address of the deployed module.
   */
  function _deployAgreementEligibilityModule(
    uint256 _targetHat,
    uint256 _ownerHat,
    uint256 _arbitratorHat,
    string memory _agreement
  ) internal returns (address) {
    bytes memory initData = abi.encode(_ownerHat, _arbitratorHat, _agreement);
    return AGREEMENT_ELIGIBILITY_FACTORY.deployModule(_targetHat, address(HATS), initData, SALT_NONCE);
  }

  /**
   * @dev Deploys a Hats allowlist eligibility module.
   * @param _targetHat The id of the target hat.
   * @param _ownerHat The id of the owner hat.
   * @param _arbitratorHat The id of the arbitrator hat.
   * @return The address of the deployed module.
   */
  function _deployAllowlistEligibilityModule(uint256 _targetHat, uint256 _ownerHat, uint256 _arbitratorHat)
    internal
    returns (address)
  {
    bytes memory initData = abi.encode(_ownerHat, _arbitratorHat);
    return ALLOWLIST_ELIGIBILITY_FACTORY.deployModule(_targetHat, address(HATS), initData, SALT_NONCE);
  }

  /**
   * @dev Chains Hats agreement and allowlist modules. To be eligible for a hat wiht this chained eligibility, a user
   * must have signed the agreement AND on the allowlist.
   * @param _targetHat The id of the target hat.
   * @param _agreementOwnerHat The id of the agreement owner hat.
   * @param _allowlistOwnerHat The id of the allowlist owner hat.
   * @param _arbitratorHat The id of the arbitrator hat.
   * @param _agreement The agreement for the grant.
   * @return The address of the deployed module.
   */
  function _deployChainingEligibilityModule(
    uint256 _targetHat,
    uint256 _agreementOwnerHat,
    uint256 _allowlistOwnerHat,
    uint256 _arbitratorHat,
    string memory _agreement
  ) internal returns (address) {
    address agreementEligibilityModule =
      _deployAgreementEligibilityModule(_targetHat, _agreementOwnerHat, _arbitratorHat, _agreement);

    address kycEligibilityModule = _deployAllowlistEligibilityModule(_targetHat, _allowlistOwnerHat, _arbitratorHat);

    // build the init data
    uint256[] memory clauseLengths = new uint256[](1);
    clauseLengths[0] = 2;

    bytes memory initData = abi.encode(
      1, // NUM_CONJUNCTION_CLAUSES
      clauseLengths,
      abi.encode(agreementEligibilityModule, kycEligibilityModule)
    );
    return CHAINING_ELIGIBILITY_FACTORY.deployModule(_targetHat, address(HATS), initData, SALT_NONCE);
  }

  /**
   * @dev Deploys a Hats Signer Gate and Safe, wired up together.
   * @param _signersHatId The id of the signers hat.
   * @param _ownerHatId The id of the owner hat.
   * @return The address of the deployed Safe.
   */
  function _deployHSGAndSafe(uint256 _signersHatId, uint256 _ownerHatId) internal returns (address, address) {
    (address hsg, address safe) = HATS_SIGNER_GATE_FACTORY.deployHatsSignerGateAndSafe(
      _ownerHatId, // ownerHat
      _signersHatId, // signersHatId
      1, // minThreshold
      1, // targetThreshold
      1 // maxSigners
    );

    return (hsg, safe);
  }

  // /**
  //  * @dev Builds the constructor arguments for the stream manager contract.
  //  * @param _cancellerHat The id of the canceller hat.
  //  * @param _amount The amount of $ZK to grant as a stream.
  //  * @param _duration The duration of the stream.
  //  * @return The arguments for the stream manager contract, as a StreamManager.CreationArgs struct.
  //  */
  // function _buildStreamManagerCreationData(uint256 _cancellerHat, uint128 _amount, uint40 _duration)
  //   internal
  //   view
  //   returns (IHats, address, ISablierV2LockupLinear, uint128, uint40, uint40, uint256)
  // {
  //   return ();
  // }

  /**
   * @dev Deploys a new stream manager contract.
   * @param _targetHat The id of the target hat.
   * @param _cancellerHat The id of the canceller hat.
   * @param _recipientSafe The address of the recipient Safe.
   * @param _amount The amount of $ZK to grant as a stream.
   * @param _duration The duration of the stream.
   * @return The address of the deployed stream manager.
   */
  function _deployStreamManager(
    uint256 _targetHat,
    uint256 _cancellerHat,
    address _recipientSafe,
    uint128 _amount,
    uint40 _duration
  ) internal returns (address) {
    // deploy the stream manager
    StreamManager streamManager = new StreamManager{ salt: bytes32(SALT_NONCE) }(
      HATS,
      ZK,
      LOCKUP_LINEAR,
      _amount,
      0, // no cliff in this MVP
      _duration,
      _cancellerHat
    );

    // set the recipient as the recipient of the stream
    streamManager.setUp(_recipientSafe, _targetHat);

    return address(streamManager);

    // TODO post-MVP: make the salt nonce a parameter so that multiple stream managers can be deployed for the same args
  }
}
