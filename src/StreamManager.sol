// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

// import { console2 } from "forge-std/Test.sol"; // comment out before deploy
import { IERC20, IZkTokenV2 } from "./lib/IZkTokenV2.sol";
import { ud60x18 } from "@prb/math/src/UD60x18.sol";
import { ISablierV2LockupLinear } from "@sablier/v2-core/src/interfaces/ISablierV2LockupLinear.sol";
import { Broker, LockupLinear } from "@sablier/v2-core/src/types/DataTypes.sol";
import { IHats } from "../lib/hats-protocol/src/Interfaces/IHats.sol";

/*//////////////////////////////////////////////////////////////
                            CUSTOM ERRORS
  //////////////////////////////////////////////////////////////*/
error NotAuthorized();

/**
 * @title StreamManager
 * @author Haberdasher Labs
 * @notice This contract manages a $ZK token grant stream. It is designed to be deployed from the GrantCreator contract
 * as the result of a proposal to the $ZK Token Governor. The grant recipient can initiate the stream, and the grant
 * canceller can cancel the stream.
 *
 * For stream initiation to work, this contract must be authorized as a $ZK token minter.
 */
contract StreamManager {
  /*//////////////////////////////////////////////////////////////
                              EVENTS
  //////////////////////////////////////////////////////////////*/

  event StreamManagerCreated(address asset, uint128 amount, uint40 cliff, uint40 totalDuration, uint256 cancellerHat);

  event RecipientSet(address recipient, uint256 recipientHat);

  /*//////////////////////////////////////////////////////////////
                            DATA MODELS
  //////////////////////////////////////////////////////////////*/

  struct CreationArgs {
    IHats hats;
    address zk;
    ISablierV2LockupLinear lockupLinear;
    uint128 totalAmount;
    uint40 cliff;
    uint40 totalDuration;
    uint256 cancellerHat;
  }

  /*//////////////////////////////////////////////////////////////
                              CONSTANTS
  //////////////////////////////////////////////////////////////*/

  string public constant VERSION = "mvp";

  IERC20 public immutable ZK;
  ISablierV2LockupLinear public immutable LOCKUP_LINEAR;
  IHats public immutable HATS;
  address public immutable DEPLOYER;

  uint128 public immutable totalAmount;

  uint40 public immutable cliff;
  uint40 public immutable totalDuration;

  uint256 public immutable cancellerHat;

  /*//////////////////////////////////////////////////////////////
                            MUTABLE STATE
  //////////////////////////////////////////////////////////////*/

  address public recipient; // recipientSafe
  uint256 public recipientHat;
  uint256 public streamId;

  /*//////////////////////////////////////////////////////////////
                            CONSTRUCTOR
  //////////////////////////////////////////////////////////////*/

  constructor(
    IHats _hats,
    address _zk,
    ISablierV2LockupLinear _lockupLinear,
    uint128 _totalAmount,
    uint40 _cliff,
    uint40 _totalDuration,
    uint256 _cancellerHat
  ) {
    HATS = _hats;
    ZK = IERC20(_zk);
    LOCKUP_LINEAR = _lockupLinear;
    totalAmount = _totalAmount;
    cliff = _cliff;
    totalDuration = _totalDuration;
    cancellerHat = _cancellerHat;

    DEPLOYER = msg.sender;

    emit StreamManagerCreated(address(ZK), totalAmount, cliff, totalDuration, cancellerHat);
  }

  /*//////////////////////////////////////////////////////////////
                            AUTH MODIFERS
  //////////////////////////////////////////////////////////////*/

  modifier onlyRecipient() {
    if (!HATS.isWearerOfHat(msg.sender, recipientHat)) revert NotAuthorized();
    _;
  }

  modifier onlyCanceller() {
    if (!HATS.isWearerOfHat(msg.sender, cancellerHat)) revert NotAuthorized();
    _;
  }

  modifier onlyDeployer() {
    if (msg.sender != DEPLOYER) revert NotAuthorized();
    _;
  }

  /*//////////////////////////////////////////////////////////////
                          SETUP FUNCTION
  //////////////////////////////////////////////////////////////*/

  function setUp(address _recipient, uint256 _recipientHat) public onlyDeployer {
    recipient = _recipient;
    recipientHat = _recipientHat;

    emit RecipientSet(_recipient, _recipientHat);

    // TODO post-MVP: make this an initializer function
  }

  /*//////////////////////////////////////////////////////////////
                          PUBLIC FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @dev For this function to work, the sender must have approved this dummy contract to spend DAI.
  function createStream() public onlyRecipient returns (uint256 _streamId) {
    // mint the ZK tokens to this contract
    _mintTokens(totalAmount);

    // Approve the Sablier contract to spend ZK
    ZK.approve(address(LOCKUP_LINEAR), totalAmount);

    // Declare the params struct
    LockupLinear.CreateWithDurations memory params;

    // Declare the function parameters
    params.sender = address(this); // The sender will be able to cancel the stream
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

    // unstreamed tokens are returned to this contract
    uint256 unstreamedTokens = ZK.balanceOf(address(this));

    // transfer the unstreamed tokens to the refund destination
    ZK.transfer(_refundDestination, unstreamedTokens);
  }

  /*//////////////////////////////////////////////////////////////
                          INTERNAL FUNCTIONS
  //////////////////////////////////////////////////////////////*/

  /// @dev Will revert if this contract is not authorized as a minter
  function _mintTokens(uint256 _amount) internal {
    IZkTokenV2(address(ZK)).mint(address(this), _amount);
  }
}
