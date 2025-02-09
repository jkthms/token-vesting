// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../lib/forge-std/src/Test.sol";
import {STFX} from "../src/STFX.sol";
import {Vesting} from "../src/Vesting.sol";
import {VestingFactory} from "../src/VestingFactory.sol";

error AlreadyCancelled();
error AlreadyClaimed();
error AlreadyExists();
error NoAccess();
error ZeroAddress();
error SameRecipient();
error Initialised();
error NotInitialised();

/// @author jkthms (https://github.com/jkthms)

contract VestingTest is Test {
    STFX internal stfxToken;
    VestingFactory internal factory;
    Vesting internal vesting;

    address internal treasury = address(0xdead);
    address internal r = address(0xbee);

    /// Set up the environment.
    function setUp() public {
        stfxToken = new STFX(treasury);
        vesting = new Vesting();
        factory = new VestingFactory(treasury, address(vesting), address(stfxToken));

        vm.expectRevert(NotInitialised.selector);
        vesting.claim();
    }

    function testInitialise(uint40 _start, uint40 _duration, uint256 _amount) public {
        vm.assume(_start > block.timestamp);
        vm.assume(_amount > 0);
        vm.assume(_amount < 1_000_000_000e18);

        vm.startPrank(treasury);
        stfxToken.transfer(address(factory), _amount);
        address v = factory.createVestingStartingFrom(r, _start, _duration, _amount, true);
        vm.stopPrank();

        vm.expectRevert(Initialised.selector);
        Vesting(v).initialise(r, _start, _duration, _amount, false);

        assertEq(Vesting(v).duration(), _duration);
        assertEq(Vesting(v).start(), _start);
        assertEq(Vesting(v).amount(), _amount);
        assertEq(Vesting(v).recipient(), r);
    }

    function testRevertInitialise(uint40 _start, uint40 _duration, uint256 _amount, address _randomAddress) public {
        vm.assume(_start > block.timestamp);
        vm.assume(_randomAddress != treasury);

        vm.prank(_randomAddress);
        vm.expectRevert(NoAccess.selector);
        factory.createVestingStartingFrom(r, _start, _duration, _amount, true);

        vm.prank(_randomAddress);
        vm.expectRevert(NoAccess.selector);
        factory.createVestingFromNow(r, _duration, _amount, false);
    }

    function testChangeRecipientCancellable(address _r1, address _r2) public {
        vm.assume(_r1 != address(0));
        vm.assume(_r2 != address(0));
        vm.assume(_r1 != r);
        vm.assume(_r2 != r);
        vm.assume(_r1 != _r2);

        vm.startPrank(treasury);
        stfxToken.transfer(address(factory), 1_000e18);
        address v = factory.createVestingFromNow(r, 52 weeks, 1_000e18, true);
        vm.stopPrank();

        assertEq(factory.recipientVesting(r), address(v));

        vm.prank(r);
        vm.expectRevert(ZeroAddress.selector);
        Vesting(v).changeRecipient(address(0));

        vm.prank(r);
        Vesting(v).changeRecipient(_r1);

        assertEq(Vesting(v).recipient(), _r1);
        assertEq(factory.recipientVesting(r), address(0));
        assertEq(factory.recipientVesting(_r1), address(v));

        vm.prank(treasury);
        Vesting(v).changeRecipient(_r2);

        assertEq(Vesting(v).recipient(), _r2);
        assertEq(factory.recipientVesting(_r1), address(0));
        assertEq(factory.recipientVesting(_r2), address(v));
    }

    function testChangeRecipientNotCancellable(address _r) public {
        vm.assume(_r != address(0));
        vm.assume(_r != r);

        vm.startPrank(treasury);
        stfxToken.transfer(address(factory), 1_000e18);
        address v = factory.createVestingFromNow(r, 52 weeks, 1_000e18, false);
        vm.stopPrank();

        assertEq(factory.recipientVesting(r), address(v));

        vm.prank(r);
        vm.expectRevert(ZeroAddress.selector);
        Vesting(v).changeRecipient(address(0));

        vm.prank(r);
        vm.expectRevert(SameRecipient.selector);
        Vesting(v).changeRecipient(r);

        vm.prank(treasury);
        vm.expectRevert(NoAccess.selector);
        Vesting(v).changeRecipient(_r);

        vm.prank(r);
        Vesting(v).changeRecipient(_r);

        assertEq(Vesting(v).recipient(), _r);
        assertEq(factory.recipientVesting(r), address(0));
        assertEq(factory.recipientVesting(_r), address(v));
    }

    function testCancelVest(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < 1_000_000_000e18);

        vm.startPrank(treasury);
        stfxToken.transfer(address(factory), _amount);
        address v = factory.createVestingFromNow(r, 52 weeks, _amount, true);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 weeks);

        uint256 amount = Vesting(v).amount() / Vesting(v).duration();
        uint256 balance = stfxToken.balanceOf(treasury);

        vm.prank(treasury);
        Vesting(v).cancelVest();

        assertEq(stfxToken.balanceOf(address(factory)), 0);
        assertEq(stfxToken.balanceOf(v), 0);
        assertEq(stfxToken.balanceOf(r), 4 weeks * amount);
        assertEq(stfxToken.balanceOf(treasury), balance + (_amount - (4 weeks * amount)));
        assertEq(Vesting(v).totalClaimedAmount(), 4 weeks * amount);
        assertTrue(Vesting(v).cancelled());
    }

    function testClaim(uint256 _amount) public {
        vm.assume(_amount > 1e18);
        vm.assume(_amount < 1_000_000_000e18);

        vm.startPrank(treasury);
        stfxToken.transfer(address(factory), _amount);
        address v = factory.createVestingFromNow(r, 52 weeks, _amount, true);
        vm.stopPrank();

        uint256 amount = Vesting(v).amount() / Vesting(v).duration();
        uint256 balance = stfxToken.balanceOf(treasury);

        for (uint256 i = 1; i < 52;) {
            vm.warp(block.timestamp + 1 weeks);

            Vesting(v).claim();

            assertEq(stfxToken.balanceOf(address(factory)), 0);
            assertEq(stfxToken.balanceOf(v), _amount - (i * 1 weeks * amount));
            assertEq(stfxToken.balanceOf(r), i * 1 weeks * amount);
            assertEq(stfxToken.balanceOf(treasury), balance);
            assertEq(Vesting(v).totalClaimedAmount(), i * 1 weeks * amount);

            unchecked {
                ++i;
            }
        }

        vm.warp(block.timestamp + 1 weeks);

        Vesting(v).claim();

        assertEq(stfxToken.balanceOf(address(factory)), 0);
        assertEq(stfxToken.balanceOf(v), 0);
        assertEq(stfxToken.balanceOf(r), _amount);
        assertEq(stfxToken.balanceOf(treasury), balance);
        assertEq(Vesting(v).totalClaimedAmount(), _amount);

        vm.expectRevert(AlreadyClaimed.selector);
        Vesting(v).claim();
    }

    function testCancelVestAndClaim(uint256 _amount) public {
        vm.assume(_amount > 0);
        vm.assume(_amount < 1_000_000_000e18);

        vm.startPrank(treasury);
        stfxToken.transfer(address(factory), _amount);
        address v = factory.createVestingFromNow(r, 52 weeks, _amount, true);
        vm.stopPrank();

        vm.warp(block.timestamp + 4 weeks);

        vm.prank(treasury);
        Vesting(v).cancelVest();

        vm.expectRevert(AlreadyCancelled.selector);
        Vesting(v).claim();
    }

    function testChangeRecipientAlreadyExists() public {
        vm.startPrank(treasury);
        stfxToken.transfer(address(factory), 2_000e18);
        address v1 = factory.createVestingFromNow(r, 52 weeks, 1_000e18, true);
        address v2 = factory.createVestingFromNow(address(0xbad), 52 weeks, 1_000e18, false);
        vm.stopPrank();

        vm.prank(r);
        vm.expectRevert(AlreadyExists.selector);
        Vesting(v1).changeRecipient(address(0xbad));

        vm.prank(treasury);
        vm.expectRevert(AlreadyExists.selector);
        Vesting(v1).changeRecipient(address(0xbad));

        vm.prank(r);
        Vesting(v1).changeRecipient(address(0xbaad));

        assertEq(Vesting(v1).recipient(), address(0xbaad));
        assertEq(Vesting(v2).recipient(), address(0xbad));

        vm.prank(address(0xbad));
        vm.expectRevert(AlreadyExists.selector);
        Vesting(v2).changeRecipient(address(0xbaad));

        vm.prank(address(0xbad));
        Vesting(v2).changeRecipient(r);

        assertEq(Vesting(v1).recipient(), address(0xbaad));
        assertEq(Vesting(v2).recipient(), r);
    }
}
