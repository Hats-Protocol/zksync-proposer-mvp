// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { IHatsModuleFactory as HatsModuleFactoryLike } from
  "../../lib/hats-module/src/interfaces/IHatsModuleFactory.sol";

interface IHatsModuleFactory is HatsModuleFactoryLike {
  function getAddress(uint256 _hatId, address _hat, bytes calldata _initData, uint256 _saltNonce)
    external
    returns (address);
}
