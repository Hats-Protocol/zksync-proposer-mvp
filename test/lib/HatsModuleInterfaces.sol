// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IHatsEligibility } from "../../lib/hats-protocol/src/Interfaces/IHatsEligibility.sol";

interface AllowlistEligibilityModuleLike is IHatsEligibility {
  function ownerHat() external view returns (uint256);
  function arbitratorHat() external view returns (uint256);
  function addAccount(address account) external;
}

interface AgreementEligibilityModuleLike is IHatsEligibility {
  function ownerHat() external view returns (uint256);
  function arbitratorHat() external view returns (uint256);
  function signAgreementAndClaimHat(address claimsHatter) external;
  function revoke(address wearer) external;
}

interface HatsEligibilitiesChainLike is IHatsEligibility {
  function MODULES() external view returns (address[] memory);
}

interface HatsSignerGateLike {
  function safe() external view returns (address);
  function ownerHat() external view returns (uint256);
  function signersHatId() external view returns (uint256);
  function claimSigner() external;
  function removeSigner(address signer) external;
}
