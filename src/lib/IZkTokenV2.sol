// SPDX-License-Identifier: MIT
pragma solidity >=0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { IAccessControl } from "@openzeppelin/contracts/access/IAccessControl.sol";

interface IZkTokenV2 is IERC20, IAccessControl {
  function mint(address _to, uint256 _amount) external;
}
