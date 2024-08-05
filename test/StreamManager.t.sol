// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.18;

import { console2 } from "../lib/forge-std/src/Test.sol";
import { BaseTest } from "./Base.t.sol";
import { StreamManager, NotAuthorized } from "../src/StreamManager.sol";
import { StreamManagerHarness } from "./harnesses/StreamManagerHarness.sol";

contract StreamManagerTest is BaseTest {
  // Sepolia Era addresses
  uint256 saltNonce = 1;

  string public VERSION = "0.1.0-zksync";

  // hats
  uint256 public tophat;
  uint256 public recipientHat;
  uint256 public cancellerHat;
  address public eligibility = makeAddr("eligibility");
  address public toggle = makeAddr("toggle");
  address public dao = makeAddr("dao");

  // test accounts
  address public recipient = makeAddr("recipient");
  address public canceller = makeAddr("canceller");
  address public nonWearer = makeAddr("nonWearer");

  // stream params
  uint128 public totalAmount = 1000;
  uint40 public cliff = 0;
  uint40 public totalDuration = 1000;

  function setUp() public virtual override {
    super.setUp();
  }
}

contract WithInstanceTest is StreamManagerTest {
  StreamManager public instance;

  function _deployStreamManagerInstance(
    uint128 _totalAmount,
    uint40 _cliff,
    uint40 _totalDuration,
    address _recipient,
    uint256 _recipientHat,
    uint256 _cancellerHat
  ) public returns (StreamManager) {
    StreamManager.CreationArgs memory args = StreamManager.CreationArgs({
      hats: HATS,
      zk: address(ZK),
      lockupLinear: LOCKUP_LINEAR,
      totalAmount: _totalAmount,
      cliff: _cliff,
      totalDuration: _totalDuration,
      recipient: _recipient,
      recipientHat: _recipientHat,
      cancellerHat: _cancellerHat
    });
    return new StreamManager(args);
  }

  function setUp() public virtual override {
    super.setUp();

    // set up hats
    tophat = HATS.mintTopHat(dao, "tophat", "dao.eth/tophat");
    vm.startPrank(dao);
    recipientHat = HATS.createHat(tophat, "recipientHat", 1, eligibility, toggle, true, "dao.eth/recipientHat");
    cancellerHat = HATS.createHat(tophat, "cancellerHat", 1, eligibility, toggle, true, "dao.eth/cancellerHat");
    HATS.mintHat(recipientHat, recipient);
    HATS.mintHat(cancellerHat, canceller);
    vm.stopPrank();

    // deploy the instance
    instance = _deployStreamManagerInstance(totalAmount, cliff, totalDuration, recipient, recipientHat, cancellerHat);
  }
}

contract Deployment is WithInstanceTest {
  function test_deployParams() public {
    assertEq(address(instance.ZK()), address(ZK), "incorrect ZK address");
    assertEq(instance.totalAmount(), totalAmount, "incorrect total amount");
    assertEq(instance.recipient(), recipient, "incorrect recipient");
    assertEq(instance.cliff(), cliff, "incorrect cliff");
    assertEq(instance.totalDuration(), totalDuration, "incorrect total duration");
    assertEq(instance.recipientHat(), recipientHat, "incorrect recipient hat");
    assertEq(instance.cancellerHat(), cancellerHat, "incorrect canceller hat");
  }

  function test_event() public {
    vm.expectEmit(true, true, true, true);
    emit StreamManager.StreamManagerCreated(
      address(ZK), totalAmount + 1, cliff, totalDuration, recipient, recipientHat, cancellerHat
    );
    _deployStreamManagerInstance(totalAmount + 1, cliff, totalDuration, recipient, recipientHat, cancellerHat);
  }
}

contract CreateStream is WithInstanceTest {
  function _streamAssertions(uint256 stream) internal {
    // assert that the stream exists and has the correct parameters
    assertEq(LOCKUP_LINEAR.getSender(stream), address(instance), "incorrect sender");
    assertEq(LOCKUP_LINEAR.getRecipient(stream), recipient, "incorrect recipient");
    assertEq(LOCKUP_LINEAR.getDepositedAmount(stream), totalAmount, "incorrect deposited amount");
    assertEq(address(LOCKUP_LINEAR.getAsset(stream)), address(ZK), "incorrect asset");
    assertTrue(LOCKUP_LINEAR.isCancelable(stream), "stream is not cancelable");
    assertTrue(LOCKUP_LINEAR.isTransferable(stream), "stream is not transferable");

    uint256 startTime = LOCKUP_LINEAR.getStartTime(stream);
    assertEq(startTime, block.timestamp, "incorrect start time");
    assertEq(LOCKUP_LINEAR.getEndTime(stream), startTime + totalDuration, "incorrect end time");
    assertEq(LOCKUP_LINEAR.getCliffTime(stream), startTime + cliff, "incorrect cliff time");
  }

  function test_recipient() public {
    // create the stream
    vm.prank(recipient);
    uint256 stream = instance.createStream();

    // assert that the streamId is correct
    assertEq(stream, instance.streamId(), "incorrect streamId");

    // assert that the stream exists and has the correct parameters
    _streamAssertions(stream);

    // assert that tokens were minted to the instance
    assertEq(ZK.balanceOf(address(instance)), totalAmount);
  }

  function test_revert_nonRecipient() public {
    uint256 nextStreamId = LOCKUP_LINEAR.nextStreamId();

    vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
    vm.prank(nonWearer);
    instance.createStream();

    // assert that the stream was not created
    assertFalse(LOCKUP_LINEAR.isStream(nextStreamId));

    // assert that no tokens were minted to the instance
    assertEq(ZK.balanceOf(address(instance)), 0);
  }
}

contract CancelStream is WithInstanceTest {
  function test_canceller() public {
    address refundee = dao;

    // create a stream
    vm.prank(recipient);
    uint256 stream = instance.createStream();
    uint256 instanceBalance = ZK.balanceOf(address(instance));

    // cancel the stream
    vm.prank(canceller);
    instance.cancelStream(refundee);

    // assert that the stream is cancelled
    assertTrue(LOCKUP_LINEAR.wasCanceled(stream));

    // assert that the unstreamed tokens are sent to the refundee
    // since no time has passed, all the tokens are unstreamed
    assertEq(ZK.balanceOf(refundee), instanceBalance);
  }

  function test_revert_nonCanceller() public {
    // create a stream
    vm.prank(recipient);
    uint256 stream = instance.createStream();

    // try to cancel the stream as a non-canceller
    vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
    vm.prank(nonWearer);
    instance.cancelStream(dao); // refundee doesn't matter

    // assert that the stream is still active
    assertFalse(LOCKUP_LINEAR.wasCanceled(stream));
  }
}

contract WithHarnessTest is StreamManagerTest {
  StreamManagerHarness public harness;

  function setUp() public virtual override {
    super.setUp();
    StreamManager.CreationArgs memory args = StreamManager.CreationArgs({
      hats: HATS,
      zk: address(ZK),
      lockupLinear: LOCKUP_LINEAR,
      totalAmount: totalAmount,
      cliff: cliff,
      totalDuration: totalDuration,
      recipient: recipient,
      recipientHat: recipientHat,
      cancellerHat: cancellerHat
    });
    harness = new StreamManagerHarness(args);
  }
}

contract _MintTokens is WithHarnessTest {
  bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

  modifier StreamManagerHasMinterRole() {
    // set the stream manager as the minter
    vm.prank(ZK_TOKEN_GOVERNOR);
    ZK.grantRole(MINTER_ROLE, address(harness));
    _;
  }

  function test_minter() public StreamManagerHasMinterRole {
    // mint some tokens
    vm.prank(address(harness));
    ZK.mint(recipient, 1000);

    assertEq(ZK.balanceOf(recipient), 1000);
  }

  function test_revert_nonMinter() public {
    // try to mint tokens as a non-minter
    vm.expectRevert();
    vm.prank(nonWearer);
    ZK.mint(recipient, 1000);

    assertEq(ZK.balanceOf(recipient), 0);
  }
}

contract _AuthMods is WithHarnessTest {
  function test_recipientOnly_wearer() public {
    uint256 preCount = harness.counter();

    vm.prank(recipient);
    harness.recipientOnly();

    uint256 postCount = harness.counter();
    assertEq(postCount, preCount + 1);
  }

  function test_recipientOnly_revert_nonWearer() public {
    uint256 preCount = harness.counter();

    vm.prank(nonWearer);
    vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
    harness.recipientOnly();

    uint256 postCount = harness.counter();
    assertEq(postCount, preCount);
  }

  function test_cancellerOnly_wearer() public {
    uint256 preCount = harness.counter();

    vm.prank(canceller);
    harness.cancellerOnly();

    uint256 postCount = harness.counter();
    assertEq(postCount, preCount + 1);
  }

  function test_cancellerOnly_revert_nonWearer() public {
    uint256 preCount = harness.counter();

    vm.prank(nonWearer);
    vm.expectRevert(abi.encodeWithSelector(NotAuthorized.selector));
    harness.cancellerOnly();

    uint256 postCount = harness.counter();
    assertEq(postCount, preCount);
  }
}
