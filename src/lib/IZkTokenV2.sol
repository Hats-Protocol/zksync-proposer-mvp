// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IZkTokenV2 is IERC20 {
  function grantRole(bytes32 role, address account) external;
  function mint(address _to, uint256 _amount) external;
}
