// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface TimelockControllerLike {
  function execute(address target, uint256 value, bytes calldata payload, bytes32 predecessor, bytes32 salt)
    external
    payable;

  function executeBatch(
    address[] calldata targets,
    uint256[] calldata values,
    bytes[] calldata payloads,
    bytes32 predecessor,
    bytes32 salt
  ) external payable;

  function getMinDelay() external view returns (uint256);
}

interface GovernorLike {
  function propose(
    address[] memory targets,
    uint256[] memory values,
    bytes[] memory calldatas,
    string memory description
  ) external returns (uint256 proposalId);

  function castVote(uint256 proposalId, uint8 support) external returns (uint256 balance);

  function queue(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    external
    returns (uint256);

  function execute(address[] memory targets, uint256[] memory values, bytes[] memory calldatas, bytes32 descriptionHash)
    external
    payable;

  function votingPeriod() external view returns (uint256);

  function votingDelay() external view returns (uint256);
}
