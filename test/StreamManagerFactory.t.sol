// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.19;

import { Test, console2, Vm } from "forge-std/Test.sol";
import { StreamManager } from "../src/StreamManager.sol";
import { StreamManagerFactory } from "../src/StreamManagerFactory.sol";

contract TestMultiClaimsHatterFactory is Test {
  StreamManagerFactory factory;

  function setUp() public {
    factory = new StreamManagerFactory();
  }

  function testFuzz_deployAgreementEligibilty(uint256 _hatId, address _hat, uint256 _saltNonce) public {
    address instance = factory.deployModule(_hatId, _hat, "", _saltNonce);
    address expectedAddress = factory.getAddress(_hatId, _hat, "", _saltNonce);
    assertEq(instance, expectedAddress);
  }

  function testFuzz_deployAgreementEligibiltyTwice(uint256 _hatId, address _hat, uint256 _saltNonce) public {
    factory.deployModule(_hatId, _hat, "", _saltNonce);
    vm.expectRevert(bytes("Code hash is non-zero"));
    factory.deployModule(_hatId, _hat, "", _saltNonce);
  }
}
