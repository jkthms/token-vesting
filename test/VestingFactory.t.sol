// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import {STFX} from "../src/STFX.sol";
import {Vesting} from "../src/Vesting.sol";
import {VestingFactory} from "../src/VestingFactory.sol";

error AlreadyExists();
error AlreadyClaimed();
error NoAccess();
error ZeroAmount();
error ZeroAddress();
error StartLessThanNow();

/// @author jkthms (https://github.com/jkthms)

contract VestingFactoryTest is Test {
    STFX internal stfxToken;
    VestingFactory internal factory;
    Vesting internal vesting;

    address internal treasury = address(0xdead);
    address internal r = address(0xbee);

    /// Set up the environment
    function setUp() public {
        stfxToken = new STFX(treasury);
        vesting = new Vesting();
        factory = new VestingFactory(treasury, address(vesting), address(stfxToken));
    }

    function testCreateVestingFromNow(address _recipient, uint40 _duration, uint256 _amount, bool _isCancellable)
        public
    {
        vm.assume(_recipient != address(0));
        vm.assume(_amount > 0);
        vm.assume(_amount < 10_000_000e18);

        deal(address(stfxToken), address(factory), 1_000_000_000e18);

        vm.prank(treasury);
        vm.expectRevert(ZeroAmount.selector);
        factory.createVestingFromNow(r, 52 weeks, 0, _isCancellable);

        vm.prank(treasury);
        vm.expectRevert(ZeroAddress.selector);
        factory.createVestingFromNow(address(0), 52 weeks, _amount, _isCancellable);

        vm.prank(treasury);
        address v = factory.createVestingFromNow(_recipient, _duration, _amount, _isCancellable);

        vm.prank(treasury);
        vm.expectRevert(AlreadyExists.selector);
        factory.createVestingFromNow(_recipient, _duration, 1e18, _isCancellable);

        assertEq(factory.recipientVesting(_recipient), address(v));
        assertEq(stfxToken.balanceOf(address(factory)), 1_000_000_000e18 - _amount);
        assertEq(stfxToken.balanceOf(v), _amount);
        assertEq(Vesting(v).amount(), _amount);
        assertEq(Vesting(v).start(), block.timestamp);
        assertEq(Vesting(v).duration(), _duration);
        assertEq(Vesting(v).recipient(), _recipient);
        if (_isCancellable) assertTrue(Vesting(v).isCancellable());
        else assertTrue(!Vesting(v).isCancellable());
    }

    function testCreateVestingStartingFrom(
        address _recipient,
        uint40 _start,
        uint40 _duration,
        uint256 _amount,
        bool _isCancellable
    ) public {
        vm.assume(_recipient != address(0));
        vm.assume(_amount > 0);
        vm.assume(_amount < 10_000_000e18);
        vm.assume(_start > block.timestamp);

        deal(address(stfxToken), address(factory), 1_000_000_000e18);

        vm.prank(treasury);
        vm.expectRevert(StartLessThanNow.selector);
        factory.createVestingStartingFrom(r, uint40(block.timestamp - 1), 52 weeks, _amount, _isCancellable);

        vm.prank(treasury);
        vm.expectRevert(ZeroAddress.selector);
        factory.createVestingStartingFrom(address(0), _start, 52 weeks, _amount, _isCancellable);

        vm.prank(treasury);
        address v = factory.createVestingStartingFrom(_recipient, _start, _duration, _amount, _isCancellable);

        vm.prank(treasury);
        vm.expectRevert(AlreadyExists.selector);
        factory.createVestingStartingFrom(_recipient, _start, _duration, 1e18, _isCancellable);

        assertEq(factory.recipientVesting(_recipient), address(v));
        assertEq(stfxToken.balanceOf(address(factory)), 1_000_000_000e18 - _amount);
        assertEq(stfxToken.balanceOf(v), _amount);
        assertEq(Vesting(v).amount(), _amount);
        assertEq(Vesting(v).start(), _start);
        assertEq(Vesting(v).duration(), _duration);
        assertEq(Vesting(v).recipient(), _recipient);
        if (_isCancellable) assertTrue(Vesting(v).isCancellable());
        else assertTrue(!Vesting(v).isCancellable());
    }

    function testChangeTreasury(address _randomAddress, address _newTreasury) public {
        vm.assume(_randomAddress != treasury);
        vm.assume(_newTreasury != address(0));

        vm.prank(_randomAddress);
        vm.expectRevert(NoAccess.selector);
        factory.changeTreasury(_newTreasury);

        vm.startPrank(treasury);
        vm.expectRevert(ZeroAddress.selector);
        factory.changeTreasury(address(0));
        factory.changeTreasury(_newTreasury);
        vm.stopPrank();
    }

    function testWithdraw(address _randomAddress) public {
        vm.assume(_randomAddress != treasury);

        vm.prank(treasury);
        stfxToken.transfer(address(factory), 1_000_000e18);

        uint256 balance = stfxToken.balanceOf(treasury);

        vm.prank(_randomAddress);
        vm.expectRevert(NoAccess.selector);
        factory.withdraw(address(stfxToken));

        vm.prank(treasury);
        factory.withdraw(address(stfxToken));

        assertEq(stfxToken.balanceOf(address(factory)), 0);
        assertEq(stfxToken.balanceOf(treasury), balance + 1_000_000e18);
    }

    function testClaim(uint256 _amount1, uint256 _amount2, uint256 _amount3) public {
        vm.assume(_amount1 > 1e18);
        vm.assume(_amount1 < 1_000_000e18);
        vm.assume(_amount2 > 1e18);
        vm.assume(_amount2 < 1_000_000e18);
        vm.assume(_amount3 > 1e18);
        vm.assume(_amount3 < 1_000_000e18);

        address r1 = address(0xbee1);
        address r2 = address(0xbee2);
        address r3 = address(0xbee3);

        vm.startPrank(treasury);
        stfxToken.transfer(address(factory), _amount1 + _amount2 + _amount3);
        address v1 = factory.createVestingStartingFrom(r1, uint40(block.timestamp), 52 weeks, _amount1, true);
        address v2 = factory.createVestingStartingFrom(r2, uint40(block.timestamp), 1 weeks, _amount2, true);
        address v3 = factory.createVestingStartingFrom(r3, uint40(block.timestamp), 52 weeks, _amount3, true);
        vm.stopPrank();

        uint256 amount1 = Vesting(v1).amount() / Vesting(v1).duration();
        uint256 amount2 = Vesting(v2).amount() / Vesting(v2).duration();
        uint256 amount3 = Vesting(v3).amount() / Vesting(v3).duration();
        uint256 balance = stfxToken.balanceOf(treasury);

        vm.warp(block.timestamp + 1 weeks);
        factory.claim();

        assertEq(stfxToken.balanceOf(address(factory)), 0);
        assertEq(Vesting(v1).totalClaimedAmount(), 1 weeks * amount1);
        assertEq(Vesting(v2).totalClaimedAmount(), _amount2);
        assertEq(Vesting(v3).totalClaimedAmount(), 1 weeks * amount3);
        assertEq(stfxToken.balanceOf(r1), 1 weeks * amount1);
        assertEq(stfxToken.balanceOf(r2), _amount2);
        assertEq(stfxToken.balanceOf(r3), 1 weeks * amount3);
        assertEq(stfxToken.balanceOf(v1), _amount1 - (1 weeks * amount1));
        assertEq(stfxToken.balanceOf(v2), 0);
        assertEq(stfxToken.balanceOf(v3), _amount3 - (1 weeks * amount3));
        assertEq(stfxToken.balanceOf(treasury), balance);

        vm.warp(block.timestamp + 1 weeks);
        factory.claim();

        assertEq(stfxToken.balanceOf(address(factory)), 0);
        assertEq(Vesting(v1).totalClaimedAmount(), 2 weeks * amount1);
        assertEq(Vesting(v2).totalClaimedAmount(), _amount2);
        assertEq(Vesting(v3).totalClaimedAmount(), 2 weeks * amount3);
        assertEq(stfxToken.balanceOf(r1), 2 weeks * amount1);
        assertEq(stfxToken.balanceOf(r2), _amount2);
        assertEq(stfxToken.balanceOf(r3), 2 weeks * amount3);
        assertEq(stfxToken.balanceOf(v1), _amount1 - (2 weeks * amount1));
        assertEq(stfxToken.balanceOf(v2), 0);
        assertEq(stfxToken.balanceOf(v3), _amount3 - (2 weeks * amount3));
        assertEq(stfxToken.balanceOf(treasury), balance);

        vm.prank(treasury);
        Vesting(v3).cancelVest();

        vm.warp(block.timestamp + 1 weeks);
        factory.claim();

        assertEq(stfxToken.balanceOf(address(factory)), 0);
        assertEq(Vesting(v1).totalClaimedAmount(), 3 weeks * amount1);
        assertEq(Vesting(v2).totalClaimedAmount(), _amount2);
        assertEq(Vesting(v3).totalClaimedAmount(), 2 weeks * amount3);
        assertEq(stfxToken.balanceOf(r1), 3 weeks * amount1);
        assertEq(stfxToken.balanceOf(r2), _amount2);
        assertEq(stfxToken.balanceOf(r3), 2 weeks * amount3);
        assertEq(stfxToken.balanceOf(v1), _amount1 - (3 weeks * amount1));
        assertEq(stfxToken.balanceOf(v2), 0);
        assertEq(stfxToken.balanceOf(v3), 0);
        assertEq(stfxToken.balanceOf(treasury), balance + (_amount3 - (2 weeks * amount3)));
    }
}
