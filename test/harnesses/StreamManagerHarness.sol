// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // comment out before deploy
import { StreamManager, NotAuthorized, IZkTokenV2, IHats, ISablierV2LockupLinear } from "../../src/StreamManager.sol";

contract StreamManagerHarness is StreamManager {
  uint256 public counter;

  constructor(StreamManager.CreationArgs memory _args) StreamManager(_args) { }

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