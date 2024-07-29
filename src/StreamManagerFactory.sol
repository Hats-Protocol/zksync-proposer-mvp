// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import { StreamManager, IHats, ISablierV2LockupLinear } from "src/StreamManager.sol";
import { L2ContractHelper } from "./lib/L2ContractHelper.sol";

contract StreamManagerFactory {
  string public constant VERSION = "0.1.0-zksync";
  /// @dev Bytecode hash can be found in zkout/StreamManager.sol/StreamManager.json under the hash key.
  bytes32 constant BYTECODE_HASH = 0x8600000000000000000000000000000000000000000000000000000000000000; // TODO

  function create(
    IHats _hats,
    address _zk,
    ISablierV2LockupLinear _lockupLinear, // zkSync Era: 0x8cB69b514E97a904743922e1adf3D1627deeeE8D
    uint128 _totalAmount,
    uint40 _cliff,
    uint40 _totalDuration,
    address _recipient,
    uint256 _recipientHat,
    uint256 _cancellerHat,
    uint256 _saltNonce
  ) external returns (StreamManager instance) {
    bytes32 salt = _calculateSalt(_saltNonce);
    instance = new StreamManager{ salt: salt }(
      IHats(_hats), _zk, _lockupLinear, _totalAmount, _cliff, _totalDuration, _recipient, _recipientHat, _cancellerHat
    );
  }

  function _calculateSalt(uint256 _saltNonce) internal view returns (bytes32) {
    return keccak256(abi.encodePacked(block.chainid, _saltNonce));
  }

  function _constructorInputHash(
    IHats _hats,
    address _zk,
    ISablierV2LockupLinear _lockupLinear, // zkSync Era: 0x8cB69b514E97a904743922e1adf3D1627deeeE8D
    uint128 _totalAmount,
    uint40 _cliff,
    uint40 _totalDuration,
    address _recipient,
    uint256 _recipientHat,
    uint256 _cancellerHat
  ) internal pure returns (bytes32) {
    return keccak256(
      abi.encodePacked(
        _hats, _zk, _lockupLinear, _totalAmount, _cliff, _totalDuration, _recipient, _recipientHat, _cancellerHat
      )
    );
  }

  function getAddress(
    IHats _hats,
    address _zk,
    ISablierV2LockupLinear _lockupLinear, // zkSync Era: 0x8cB69b514E97a904743922e1adf3D1627deeeE8D
    uint128 _totalAmount,
    uint40 _cliff,
    uint40 _totalDuration,
    address _recipient,
    uint256 _recipientHat,
    uint256 _cancellerHat,
    uint256 _saltNonce
  ) external view returns (address addr) {
    bytes32 salt = _calculateSalt(_saltNonce);
    bytes32 constructorInputHash = _constructorInputHash(
      IHats(_hats), _zk, _lockupLinear, _totalAmount, _cliff, _totalDuration, _recipient, _recipientHat, _cancellerHat
    );
    addr = L2ContractHelper.computeCreate2Address(address(this), salt, BYTECODE_HASH, constructorInputHash);
  }
}
