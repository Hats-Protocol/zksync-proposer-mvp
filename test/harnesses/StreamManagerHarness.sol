// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy

import { StreamManager, NotAuthorized, IZkTokenV2, IHats, ISablierV2LockupLinear } from "../../src/StreamManager.sol";

contract StreamManagerHarness is StreamManager {
  uint256 public counter;

  constructor(
    IHats _hats,
    address _zk,
    ISablierV2LockupLinear _lockupLinear, // zkSync Era: 0x8cB69b514E97a904743922e1adf3D1627deeeE8D
    uint128 _totalAmount,
    uint40 _cliff,
    uint40 _totalDuration,
    address _recipient,
    uint256 _recipientHat,
    uint256 _cancellerHat
  )
    StreamManager(
      _hats,
      _zk,
      _lockupLinear,
      _totalAmount,
      _cliff,
      _totalDuration,
      _recipient,
      _recipientHat,
      _cancellerHat
    )
  { }

  function mintTokens(uint256 _amount) public {
    IZkTokenV2(address(ZK)).mint(address(this), _amount);
  }

  function recipientOnly() public onlyRecipient {
    counter++;
  }

  function cancellerOnly() public onlyCanceller {
    counter++;
  }
}
