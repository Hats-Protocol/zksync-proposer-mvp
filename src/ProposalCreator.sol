// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { IHatsModuleFactory } from "../lib/hats-module/src/interfaces/IHatsModuleFactory.sol";
import { IMultiClaimsHatter, ClaimType } from "./lib/IMultiClaimsHatter.sol";
import { IHatsSignerGateFactory } from "./lib/IHatsSignerGateFactory.sol";
import { StreamManager, IHats, ISablierV2LockupLinear, IZkTokenV2 } from "./StreamManager.sol";

/**
 * @title ProposalHelper
 * @author Haberdasher Labs
 * @notice // TODO
 */
contract ProposalCreator {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  error WrongRecipientHatId();

  /*//////////////////////////////////////////////////////////////
                              DATA MODELS
  //////////////////////////////////////////////////////////////*/

  struct StreamConfig {
    address _zk;
    uint128 _totalAmount;
    uint40 _cliff;
    uint40 _totalDuration;
  }

  struct GrantConfig {
    string name;
    string image;
    string agreement;
    uint256 amount;
    uint256 accountabilityJudgeHat;
    uint256 kycManagerHat;
    StreamConfig streamConfig;
  }

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  uint256 public constant SALT_NONCE = 1;

  IHats public immutable HATS;
  IMultiClaimsHatter public immutable MULTI_CLAIMS_HATTER;
  IHatsModuleFactory public immutable CHAINING_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public immutable AGREEMENT_ELIGIBILITY_FACTORY;
  IHatsModuleFactory public immutable ALLOWLIST_ELIGIBILITY_FACTORY;
  IHatsSignerGateFactory public immutable HATS_SIGNER_GATE_FACTORY;
  ISablierV2LockupLinear public immutable LOCKUP_LINEAR;
  address public immutable ZK;

  uint256 public immutable RECIPIENT_BRANCH_ROOT;

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

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

  /// $ZK token minting governor execution delegatecalls this contract, which executes the following on the governor’s
  /// behalf
  function createGrant(GrantConfig memory _grant)
    external
    returns (uint256 recipientHat, address recipientSafe, address streamManager)
  {
    // get the id of the next recipient hat
    recipientHat = HATS.getNextId(RECIPIENT_BRANCH_ROOT);

    // deploy agreement eligibility module
    // TODO what hat should be the agreement eligibility module owner?
    address agreementEligibilityModule = _deployAgreementEligibilityModule(
      recipientHat, _grant.accountabilityJudgeHat, _grant.accountabilityJudgeHat, _grant.agreement
    );

    // deploy KYC eligibility module
    address kycEligibilityModule =
      _deployAllowlistEligibilityModule(recipientHat, _grant.kycManagerHat, _grant.accountabilityJudgeHat);

    // deploy chaining eligibility module
    address chainingEligibilityModule =
      _deployChainingEligibilityModule(recipientHat, agreementEligibilityModule, kycEligibilityModule);

    // create recipient hat, ensuring that its id is as predicted
    if (
      HATS.createHat(
        RECIPIENT_BRANCH_ROOT, // admin
        _grant.name, // details
        1, // maxSupply
        chainingEligibilityModule,
        address(0x4a75), // no need for toggle
        true, // mutable
        _grant.image // imageURI
      ) != recipientHat
    ) {
      revert WrongRecipientHatId();
    }

    // make recipient hat claimableFor
    MULTI_CLAIMS_HATTER.setHatClaimability(recipientHat, ClaimType.ClaimableFor);

    // deploy recipient Safe gated to recipientHat
    // TODO what hat should be the HSG owner?
    recipientSafe = _deployHSGAndSafe(recipientHat, _grant.accountabilityJudgeHat);

    // deploy stream manager contract
    streamManager =
      _deployStreamManager(recipientHat, _grant.accountabilityJudgeHat, recipientSafe, _grant.streamConfig);

    // authorize stream manager contract to mint $ZK tokens
    IZkTokenV2(ZK).grantRole(keccak256("MINTER_ROLE"), streamManager);
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function _deployAgreementEligibilityModule(
    uint256 _hatId,
    uint256 _ownerHat,
    uint256 _arbitratorHat,
    string memory _agreement
  ) internal returns (address _module) {
    bytes memory initData = abi.encode(_ownerHat, _arbitratorHat, _agreement);
    return AGREEMENT_ELIGIBILITY_FACTORY.deployModule(_hatId, address(HATS), initData, SALT_NONCE);
  }

  function _deployAllowlistEligibilityModule(uint256 _hatId, uint256 _ownerHat, uint256 _arbitratorHat)
    internal
    returns (address _module)
  {
    bytes memory initData = abi.encode(_ownerHat, _arbitratorHat);
    return ALLOWLIST_ELIGIBILITY_FACTORY.deployModule(_hatId, address(HATS), initData, SALT_NONCE);
  }

  function _deployChainingEligibilityModule(
    uint256 _hatId,
    address _agreementEligibilityModule,
    address _kycEligibilityModule
  ) internal returns (address _module) {
    bytes memory initData = abi.encode(
      1, // NUM_CONJUNCTION_CLAUSES
      2, // CONJUNCTION_CLAUSE_LENGTH
      _agreementEligibilityModule,
      _kycEligibilityModule
    );
    return CHAINING_ELIGIBILITY_FACTORY.deployModule(_hatId, address(HATS), initData, SALT_NONCE);
  }

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

  function _deployStreamManager(uint256 _hatId, uint256 _cancellerHat, address _recipient, StreamConfig memory _stream)
    internal
    returns (address)
  {
    return address(
      new StreamManager(
        HATS,
        address(ZK),
        LOCKUP_LINEAR,
        _stream._totalAmount,
        _stream._cliff,
        _stream._totalDuration,
        _recipient,
        _hatId, // recipientHat
        _cancellerHat
      )
    );
  }
}
