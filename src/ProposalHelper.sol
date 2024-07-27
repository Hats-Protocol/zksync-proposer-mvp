// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { IHats } from "../lib/hats-protocol/src/Interfaces/IHats.sol";
import { IHatsModuleFactory } from "../lib/hats-module/src/interfaces/IHatsModuleFactory.sol";
import { IHatsSignerGateFactory } from "./lib/IHatsSignerGateFactory.sol";
import { StreamManager, ISablierV2LockupLinear, IZTokenV2 } from "./StreamManager.sol";

/**
 * @title ProposalHelper
 * @author Haberdasher Labs
 * @notice TODO
 */
contract ProposalHelper {
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

  enum ClaimType {
    NotClaimable,
    Claimable,
    ClaimableFor
  }

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  uint256 public constant SALT_NONCE = 1;

  IHats public immutable hats;
  IMultiClaimsHatter public immutable multiClaimsHatter;
  IHatsModuleFactory public immutable chainingEligibilityFactory;
  IHatsModuleFactory public immutable agreementEligibilityFactory;
  IHatsModuleFactory public immutable allowlistEligibilityFactory;
  IHatsSignerGateFactory public immutable hatsSignerGateFactory;
  ISablierV2LockupLinear public immutable lockupLinear;
  address public immutable zk;

  uint256 public immutable recipientBranchRoot;

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
    hats = _hats;
    multiClaimsHatter = _multiClaimsHatter;
    chainingEligibilityFactory = _chainingEligibilityFactory;
    agreementEligibilityFactory = _agreementEligibilityFactory;
    allowlistEligibilityFactory = _allowlistEligibilityFactory;
    hatsSignerGateFactory = _hatsSignerGateFactory;
    lockupLinear = _lockupLinear;
    zk = _zk;

    recipientBranchRoot = _recipientBranchRoot;
  }

  /*//////////////////////////////////////////////////////////////
                            INITIALIZER
  //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// $ZK token minting governor execution delegatecalls this contract, which executes the following on the governor’s
  /// behalf
  function createGrant(
    string memory _name,
    string memory _image,
    string memory _agreement,
    uint256 _amount,
    uint256 _accountabilityJudgeHat,
    uint256 _kycManagerHat,
    StreamConfig calldata _streamConfig
  ) external returns (uint256 _recipientHat) {
    // get the id of the next recipient hat
    uint256 recipientHat = hats.getNextId(recipientBranchRoot);

    // deploy agreement eligibility module
    address agreementEligibilityModule =
      _deployAgreementEligibilityModule(recipientHat, _accountabilityJudgeHat, _agreement);

    // deploy KYC eligibility module
    address kycEligibilityModule =
      _deployAllowlistEligibilityModule(recipientHat, _kycManagerHat, _accountabilityJudgeHat);

    // deploy chaining eligibility module
    address chainingEligibilityModule =
      _deployChainingEligibilityModule(recipientHat, agreementEligibilityModule, kycEligibilityModule);

    // create recipient hat, ensuring that its id is as predicted
    if (
      hats.createHat(
        recipientBranchRoot, // admin
        _grantName, // details
        1, // maxSupply
        chainingEligibilityModule,
        address(0x4a75), // no need for toggle
        true, // mutable
        _image // imageURI
      ) != recipientHat
    ) {
      revert WrongRecipientHatId();
    }

    // make recipient hat claimableFor
    multiClaimsHatter.setHatClaimability(recipientHat, ClaimType.ClaimableFor);

    // deploy recipient Safe gated to recipientHat
    address recipientSafe = _deployHSGAndSafe(recipientHat, 1 /* TODO */ );

    // deploy streaming manager contract
    address streamingManager = _deployStreamManager(recipientHat, _accountabilityJudgeHat, recipientSafe, _streamConfig);

    // authorize streaming manager contract to mint $ZK tokens
    IZTokenV2(zk).grantRole(keccak256("MINTER_ROLE"), streamingManager);
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
    return agreementEligibilityFactory.createModule(_hatId, hats, initData, SALT_NONCE);
  }

  function _deployAllowlistEligibilityModule(uint256 _hatId, uint256 _ownerHat, uint256 _arbitratorHat)
    internal
    returns (address _module)
  {
    bytes memory initData = abi.encode(_ownerHat, _arbitratorHat);
    return allowlistEligibilityFactory.createModule(_hatId, hats, initData, SALT_NONCE);
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
    return chainingEligibilityFactory.createModule(_hatId, hats, initData, SALT_NONCE);
  }

  function _deployHSGAndSafe(uint256 _signersHatId, uint256 _ownerHatId) internal returns (address) {
    (, address safe) = _hatsSignerGateFactory.deployHatsSignerGateAndSafe(
      _signersHatId,
      _ownerHatId,
      1, // minThreshold
      1, // targetThreshold
      1 // maxSigners
    );

    return safe;
  }

  function _deployStreamManager(
    uint256 _hatId,
    uint256 _cancellerHat,
    address _recipient,
    StreamConfig calldata _stream
  ) internal returns (address) {
    return address(
      new StreamManager(
        hats,
        address(zk),
        lockupLinear,
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
