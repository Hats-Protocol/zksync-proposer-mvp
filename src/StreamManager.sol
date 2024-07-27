// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // remove before deploy
import { IERC20 } from "../lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol"; // replace with ZK token
import { ud60x18 } from "../lib/prb-math/src/UD60x18.sol";
import { ISablierV2LockupLinear } from "../lib/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "../lib/v2-core/src/types/DataTypes.sol";
import { IHats } from "../lib/hats-protocol/src/interfaces/IHats.sol";

// TODO improve imports and remappings

// TODO move this interface to its own file
interface IZTokenV2 is IERC20 {
  function grantRole(bytes32 role, address account) external;
  function mint(address _to, uint256 _amount) external;
}

/**
 * @title StreamManager
 * @author Haberdasher Labs
 * @notice // TODO
 */
contract StreamManager {
  /*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/

  error NotAuthorized();

  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  IERC20 public immutable ZK;
  ISablierV2LockupLinear public immutable LOCKUP_LINEAR;
  IHats public immutable HATS;

  uint128 public immutable totalAmount;
  address public immutable recipient; // recipientSafe
  uint40 public immutable cliff;
  uint40 public immutable totalDuration;

  uint256 public immutable recipientHat;
  uint256 public immutable cancellerHat;

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  uint256 public streamId;

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

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
  ) {
    totalAmount = _totalAmount;
    ZK = IERC20(_zk);
    recipient = _recipient;
    cliff = _cliff;
    totalDuration = _totalDuration;
    recipientHat = _recipientHat;
    cancellerHat = _cancellerHat;
  }

  /*//////////////////////////////////////////////////////////////
                            AUTH MODIFERS
  //////////////////////////////////////////////////////////////*/

  modifier onlyRecipient() {
    if (!HATS.isWearerOfHat(recipient, recipientHat)) revert NotAuthorized();
    _;
  }

  modifier onlyCanceller() {
    if (!HATS.isWearerOfHat(msg.sender, cancellerHat)) revert NotAuthorized();
    _;
  }

  /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
  function createStream() public onlyRecipient returns (uint256 _streamId) {
    // mint the ZK tokens
    _mintTokens(totalAmount);

    // Approve the Sablier contract to spend ZK
    ZK.approve(address(LOCKUP_LINEAR), totalAmount);

    // Declare the params struct
    LockupLinear.CreateWithDurations memory params;

    // Declare the function parameters
    params.sender = msg.sender; // The sender will be able to cancel the stream
    params.recipient = recipient; // The recipient of the streamed assets
    params.totalAmount = totalAmount; // Total amount is the amount inclusive of all fees
    params.asset = ZK; // The streaming asset
    params.cancelable = true; // Whether the stream will be cancelable or not
    params.transferable = false; // Whether the stream will be transferable or not
    params.durations = LockupLinear.Durations({
      cliff: cliff, // Assets will be unlocked only after this many seconds
      total: totalDuration // Setting a total duration of this many seconds
     });
    params.broker = Broker(address(0), ud60x18(0)); // Optional parameter for charging a fee

    // Create the LockupLinear stream using a function that sets the start time to `block.timestamp`
    _streamId = LOCKUP_LINEAR.createWithDurations(params);

    // Store the streamId
    streamId = _streamId;
  }

  function cancelStream(address _refundDestination) public onlyCanceller {
    // cancel the stream
    LOCKUP_LINEAR.cancel(streamId);

    // unstreamed tokens are sent to this contract
    uint256 unstreamedTokens = ZK.balanceOf(address(this));

    // transfer the unstreamed tokens to the refund destination
    ZK.transfer(_refundDestination, unstreamedTokens);
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  function _mintTokens(uint256 _amount) internal {
    // TODO
  }
}
