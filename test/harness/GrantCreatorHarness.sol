// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy

import {
  GrantCreator,
  IHatsModuleFactory,
  IMultiClaimsHatter,
  IHatsSignerGateFactory,
  IHats,
  ISablierV2LockupLinear
} from "../../src/GrantCreator.sol";

contract GrantCreatorHarness is GrantCreator {
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
  )
    GrantCreator(
      _hats,
      _multiClaimsHatter,
      _chainingEligibilityFactory,
      _agreementEligibilityFactory,
      _allowlistEligibilityFactory,
      _hatsSignerGateFactory,
      _lockupLinear,
      _zk,
      _recipientBranchRoot
    )
  { }

  function deployAgreementEligibilityModule(
    uint256 _hatId,
    uint256 _ownerHat,
    uint256 _arbitratorHat,
    string memory _agreement
  ) public returns (address) {
    return _deployAgreementEligibilityModule(_hatId, _ownerHat, _arbitratorHat, _agreement);
  }

  function deployAllowlistEligibilityModule(uint256 _hatId, uint256 _ownerHat, uint256 _arbitratorHat)
    public
    returns (address)
  {
    return _deployAllowlistEligibilityModule(_hatId, _ownerHat, _arbitratorHat);
  }

  function deployChainingEligibilityModule(
    uint256 _hatId,
    uint256 _agreementOwnerHat,
    uint256 _allowlistOwnerHat,
    uint256 _arbitratorHat,
    string memory _agreement
  ) public returns (address) {
    return _deployChainingEligibilityModule(_hatId, _agreementOwnerHat, _allowlistOwnerHat, _arbitratorHat, _agreement);
  }

  function deployHSGAndSafe(uint256 _signersHatId, uint256 _ownerHatId) public returns (address, address) {
    return _deployHSGAndSafe(_signersHatId, _ownerHatId);
  }

  function deployStreamManager(
    uint256 _hatId,
    uint256 _cancellerHat,
    address _recipient,
    uint128 _amount,
    uint40 _duration
  ) public returns (address) {
    return _deployStreamManager(_hatId, _cancellerHat, _recipient, _amount, _duration);
  }
}
