// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import { Script, console2 } from "forge-std/Script.sol";
import { StreamManager } from "../src/StreamManager.sol";

contract Deploy is Script {
  address public implementation;
  bytes32 public SALT = bytes32(abi.encode(0x4a75)); // "hats"
  
  // default values
  bool private verbose = true;
  string private version = "0.2.0"; // increment with each deployment

  /// @notice Override default values, if desired
  function prepare(bool _verbose, string memory _version) public {
    verbose = _verbose;
    version = _version;
  }

  function run() public {
    uint256 privKey = vm.envUint("PRIVATE_KEY");
    address deployer = vm.rememberKey(privKey);
    vm.startBroadcast(deployer);

    // TODO update deploy scripts
    //implementation = address(new AgreementEligibility{ salt: SALT }(version));

    vm.stopBroadcast();

    if (verbose) {
      console2.log("Implementation:", implementation);
    }
  }
}

// forge script script/AgreementEligibility.s.sol -f ethereum --broadcast --verify

/* 
forge verify-contract --chain-id 42220 --num-of-optimizations 1000000 --watch --constructor-args $(cast abi-encode \
"constructor(string)" "0.2.0" ) --compiler-version v0.8.19 0x8126d02F4EcDE43eca4543a0D90B755C3E225F09 \
src/AgreementEligibility.sol:AgreementEligibility --etherscan-api-key $CELOSCAN_KEY
*/
