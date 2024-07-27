// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

interface IHatsSignerGateFactory {
  /// @notice Deploy a new HatsSignerGate and a new Safe, all wired up together
  function deployHatsSignerGateAndSafe(
    uint256 _ownerHatId,
    uint256 _signersHatId,
    uint256 _minThreshold,
    uint256 _targetThreshold,
    uint256 _maxSigners
  ) external returns (address hsg, address payable safe);

  /**
   * @notice Deploy a new HatsSignerGate and relate it to an existing Safe
   * @dev In order to wire it up to the existing Safe, the owners of the Safe must enable it as a module and guard
   *      WARNING: HatsSignerGate must not be attached to a Safe with any other modules
   *      WARNING: HatsSignerGate must not be attached to its Safe if `validSignerCount()` >= `_maxSigners`
   *      Before wiring up HatsSignerGate to its Safe, call `canAttachHSGToSafe` and make sure the result is true
   *      Failure to do so may result in the Safe being locked forever
   */
  function deployHatsSignerGate(
    uint256 _ownerHatId,
    uint256 _signersHatId,
    address _safe, // existing Gnosis Safe that the signers will join
    uint256 _minThreshold,
    uint256 _targetThreshold,
    uint256 _maxSigners
  ) external returns (address hsg);

  /// @notice Deploy a new MultiHatsSignerGate and a new Safe, all wired up together
  function deployMultiHatsSignerGateAndSafe(
    uint256 _ownerHatId,
    uint256[] calldata _signersHatIds,
    uint256 _minThreshold,
    uint256 _targetThreshold,
    uint256 _maxSigners
  ) external returns (address mhsg, address payable safe);

  /**
   * @notice Deploy a new MultiHatsSignerGate and relate it to an existing Safe
   * @dev In order to wire it up to the existing Safe, the owners of the Safe must enable it as a module and guard
   *      WARNING: MultiHatsSignerGate must not be attached to a Safe with any other modules
   *      WARNING: MultiHatsSignerGate must not be attached to its Safe if `validSignerCount()` > `_maxSigners`
   *      Before wiring up MultiHatsSignerGate to its Safe, call `canAttachMHSGToSafe` and make sure the result is true
   *      Failure to do so may result in the Safe being locked forever
   */
  function deployMultiHatsSignerGate(
    uint256 _ownerHatId,
    uint256[] calldata _signersHatIds,
    address _safe, // existing Gnosis Safe that the signers will join
    uint256 _minThreshold,
    uint256 _targetThreshold,
    uint256 _maxSigners
  ) external returns (address mhsg);
}
