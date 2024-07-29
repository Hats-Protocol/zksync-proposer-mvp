// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

enum ClaimType {
  NotClaimable,
  Claimable,
  ClaimableFor
}

interface IMultiClaimsHatter {
  /// @notice Maps between hats and their claimability type
  function hatToClaimType(uint256 _hatId) external view returns (ClaimType);

  /*//////////////////////////////////////////////////////////////
                        ADMIN FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Change the claimability status of a hat. The caller should be an admin of the hat.
   * @param _hatId The ID of the hat to set claimability for
   * @param _claimType New claimability type for the hat
   */
  function setHatClaimability(uint256 _hatId, ClaimType _claimType) external;

  /**
   * @notice Change the claimability status of multiple hats. The caller should be an admin of the hats.
   * @param _hatIds The ID of the hat to set claimability for
   * @param _claimTypes New claimability types for each hat
   */
  function setHatsClaimability(uint256[] calldata _hatIds, ClaimType[] calldata _claimTypes) external;

  /*//////////////////////////////////////////////////////////////
                        CLAIMING FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Claim a hat.
   * @dev This contract must be wearing an admin hat of the hat to claim or else it will revert
   * @param _hatId The ID of the hat to claim
   */
  function claimHat(uint256 _hatId) external;

  /**
   * @notice Claim multiple hats.
   * @dev This contract must be wearing an admin hat of the hats to claim or else it will revert
   * @param _hatIds The IDs of the hats to claim
   */
  function claimHats(uint256[] calldata _hatIds) external;

  /**
   * @notice Claim a hat on behalf of an account
   * @dev This contract must be wearing an admin hat of the hat to claim or else it will revert
   * @param _hatId The ID of the hat to claim for
   * @param _account The account for which to claim
   */
  function claimHatFor(uint256 _hatId, address _account) external;

  /**
   * @notice Claim multiple hats on behalf of accounts
   * @dev This contract must be wearing an admin hat of the hats to claim or else it will revert
   * @param _hatIds The IDs of the hats to claim for
   * @param _accounts The accounts for which to claim
   */
  function claimHatsFor(uint256[] calldata _hatIds, address[] calldata _accounts) external;

  /*//////////////////////////////////////////////////////////////
                          VIEW FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /**
   * @notice Checks if a hat is claimable on behalf of an account
   * @param _account The account to claim for
   * @param _hatId The hat to claim
   */
  function canClaimForAccount(address _account, uint256 _hatId) external view returns (bool);

  /**
   * @notice Checks if an account can claim a hat.
   * @param _account The claiming account
   * @param _hatId The hat to claim
   */
  function accountCanClaim(address _account, uint256 _hatId) external view returns (bool);

  /**
   * @notice Checks if a hat is claimable
   * @param _hatId The ID of the hat
   */
  function isClaimableBy(uint256 _hatId) external view returns (bool);

  /**
   * @notice Checks if a hat is claimable on behalf of accounts
   * @param _hatId The ID of the hat
   */
  function isClaimableFor(uint256 _hatId) external view returns (bool);

  /**
   * @notice Check if this contract is an admin of a hat.
   *   @param _hatId The ID of the hat
   */
  function wearsAdmin(uint256 _hatId) external view returns (bool);

  /// @notice Checks if a hat exists
  function hatExists(uint256 _hatId) external view returns (bool);
}
