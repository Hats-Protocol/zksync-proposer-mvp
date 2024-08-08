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
 */
contract GrantCreator {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  error WrongRecipientHatId();
  error WrongStreamManagerAddress();

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
  bytes32 public constant STREAM_MANAGER_BYTECODE_HASH =
    0x010001e70435d6470adba8b9078022b7278deebc8929ef0c7365919dfa98865f;

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
   * @param name The name of the grant.
   * @param agreement The agreement for the grant.
   * @param accountabilityJudgeHat The hat id of the accountability judge, whose wearer determines whether the grant
   * recipient is upholding their commitments (as outlined in the grant agreement), and can stop the grant stream and/or
   * revoke the recipient hat.
   * @param kycManagerHat The hat id of the KYC manager, whose wearer determines whether the grant recipient has
   * completed
   * the KYC process.
   * @param amount The amount of $ZK to grant as a stream.
   * @param streamDuration The duration of the stream.
   * @param predictedStreamManagerAddress The predicted address of the stream manager. A proposal should also include an
   * action to grant this address the $ZK token grant minting role.
   * @return recipientHat The hat id of the recipient hat.
   * @return recipientSafe The address of the recipient Safe.
   * @return streamManager The address of the stream manager.
   */
  function createGrant(
    string memory name,
    string memory agreement,
    uint256 accountabilityJudgeHat,
    uint256 kycManagerHat,
    uint128 amount,
    uint40 streamDuration,
    address predictedStreamManagerAddress
  ) external returns (uint256 recipientHat, address recipientSafe, address streamManager) {
    // get the id of the next recipient hat
    recipientHat = HATS.getNextId(RECIPIENT_BRANCH_ROOT);

    // deploy chained eligibility with agreement and kyc modules
    address chainingEligibilityModule = _deployChainingEligibilityModule({
      _targetHat: recipientHat,
      _agreementOwnerHat: 0, // no owner for the agreement eligibility module
      _allowlistOwnerHat: kycManagerHat,
      _arbitratorHat: accountabilityJudgeHat,
      _agreement: agreement
    });

    // create recipient hat, ensuring that its id is as predicted
    if (
      HATS.createHat(
        RECIPIENT_BRANCH_ROOT, // admin
        name, // details
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
    // TODO what hat should be the HSG owner?
    recipientSafe = _deployHSGAndSafe(recipientHat, accountabilityJudgeHat);

    // deploy stream manager contract
    streamManager = _deployStreamManager(recipientHat, accountabilityJudgeHat, recipientSafe, amount, streamDuration);

    // ensure the deployment address matches the predicted address
    if (predictedStreamManagerAddress != streamManager) revert WrongStreamManagerAddress();
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
    // predict the recipient hat id
    uint256 recipientHat = HATS.getNextId(RECIPIENT_BRANCH_ROOT);

    return L2ContractHelper.computeCreate2Address(
      address(this),
      bytes32(SALT_NONCE),
      STREAM_MANAGER_BYTECODE_HASH,
      keccak256(
        abi.encode(_buildStreamManagerCreationArgs(recipientHat, _accountabilityJudgeHat, _amount, _streamDuration))
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
    address[] memory modules = new address[](2);
    modules[0] = agreementEligibilityModule;
    modules[1] = kycEligibilityModule;

    bytes memory initData = abi.encode(
      1, // NUM_CONJUNCTION_CLAUSES
      clauseLengths,
      abi.encode(modules)
    );
    return CHAINING_ELIGIBILITY_FACTORY.deployModule(_targetHat, address(HATS), initData, SALT_NONCE);
  }

  /**
   * @dev Deploys a Hats Signer Gate and Safe, wired up together.
   * @param _signersHatId The id of the signers hat.
   * @param _ownerHatId The id of the owner hat.
   * @return The address of the deployed Safe.
   */
  function _deployHSGAndSafe(uint256 _signersHatId, uint256 _ownerHatId) internal returns (address) {
    (, address safe) = HATS_SIGNER_GATE_FACTORY.deployHatsSignerGateAndSafe(
      _signersHatId,
      _ownerHatId,
      1, // minThreshold
      1, // targetThreshold
      1 // maxSigners
    );

    return safe;
  }

  /**
   * @dev Builds the constructor arguments for the stream manager contract.
   * @param _recipientHat The id of the target hat.
   * @param _cancellerHat The id of the canceller hat.
   * @param _amount The amount of $ZK to grant as a stream.
   * @param _duration The duration of the stream.
   * @return The arguments for the stream manager contract, as a StreamManager.CreationArgs struct.
   */
  function _buildStreamManagerCreationArgs(
    uint256 _recipientHat,
    uint256 _cancellerHat,
    uint128 _amount,
    uint40 _duration
  ) internal view returns (StreamManager.CreationArgs memory) {
    return StreamManager.CreationArgs({
      hats: HATS,
      zk: ZK,
      lockupLinear: LOCKUP_LINEAR,
      totalAmount: _amount,
      cliff: 0, // no cliff in this MVP
      totalDuration: _duration,
      recipientHat: _recipientHat,
      cancellerHat: _cancellerHat
    });
  }

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
    StreamManager streamManager = new StreamManager{ salt: bytes32(SALT_NONCE) }(
      _buildStreamManagerCreationArgs(_targetHat, _cancellerHat, _amount, _duration)
    );

    streamManager.setUp(_recipientSafe);

    return address(streamManager);

    // TODO post-MVP: make the salt nonce a parameter so that multiple stream managers can be deployed for the same args
  }
}
