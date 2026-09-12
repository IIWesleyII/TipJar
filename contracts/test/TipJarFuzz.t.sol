// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    IERC20Errors
} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {TipJar} from "../src/TipJar.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";

/// @notice Foundry repeats each test with generated inputs, 256 times by default.
contract TipJarFuzzTest is Test {
    MockUSDC internal usdc;
    TipJar internal jar;
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    uint256 internal constant STARTING_BALANCE = 100 * 1e6;

    event TipReceived(address indexed tipper, uint256 amount, string message);

    function setUp() public {
        usdc = new MockUSDC();
        vm.prank(owner);
        jar = new TipJar(address(usdc));
        usdc.mint(alice, STARTING_BALANCE);
        usdc.mint(bob, STARTING_BALANCE);
    }

    function testFuzz_Tip(uint256 amount, string memory message) public {
        // bound maps generated numbers into a useful range: 1 base unit up to
        // Alice's balance. The message limit is for this test, not the contract.
        amount = bound(amount, 1, STARTING_BALANCE);
        vm.assume(bytes(message).length <= 256);

        vm.startPrank(alice);
        usdc.approve(address(jar), amount);
        vm.expectEmit(true, false, false, true, address(jar));
        emit TipReceived(alice, amount, message);
        jar.tip(amount, message);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), STARTING_BALANCE - amount);
        assertEq(usdc.balanceOf(address(jar)), amount);
        assertEq(usdc.allowance(alice, address(jar)), 0);
        assertEq(jar.totalTips(), amount);
        assertEq(jar.tipCount(), 1);
        assertEq(jar.tippedBy(alice), amount);
        assertEq(jar.tippedBy(bob), 0);
        assertEq(jar.largestTip(), amount);
        assertEq(jar.largestTipper(), alice);
    }

    function testFuzz_MultipleUsersAndWithdrawal(
        uint256 first,
        uint256 second,
        uint256 third
    ) public {
        first = bound(first, 1, STARTING_BALANCE - 1);
        second = bound(second, 1, STARTING_BALANCE - first);
        third = bound(third, 1, STARTING_BALANCE);
        _tip(alice, first);
        _tip(alice, second);
        _tip(bob, third);

        uint256 total = first + second + third;
        uint256 aliceLargest = first > second ? first : second;
        uint256 largest = aliceLargest > third ? aliceLargest : third;
        // Alice's tips happened first, so she wins a tie with Bob.
        address recordHolder = aliceLargest >= third ? alice : bob;
        assertEq(usdc.balanceOf(alice), STARTING_BALANCE - first - second);
        assertEq(usdc.balanceOf(bob), STARTING_BALANCE - third);
        assertEq(usdc.balanceOf(address(jar)), total);

        vm.prank(owner);
        jar.withdraw();

        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(usdc.balanceOf(owner), total);
        assertEq(jar.totalTips(), total);
        assertEq(jar.tipCount(), 3);
        assertEq(jar.tippedBy(alice), first + second);
        assertEq(jar.tippedBy(bob), third);
        assertEq(jar.largestTip(), largest);
        assertEq(jar.largestTipper(), recordHolder);
    }

    function testFuzz_NonOwnerCannotAdminister(address caller) public {
        vm.assume(caller != owner);
        _tip(alice, 1 * 1e6);

        vm.startPrank(caller);
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.withdraw();
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.setWithdrawalAddress(bob);
        vm.stopPrank();

        assertEq(jar.owner(), owner);
        assertEq(jar.withdrawalAddress(), owner);
        assertEq(usdc.balanceOf(address(jar)), 1 * 1e6);
    }

    function testFuzz_WithdrawalDestination(address recipient, uint256 amount)
        public
    {
        vm.assume(recipient != address(0) && recipient != address(jar));
        amount = bound(amount, 1, STARTING_BALANCE);
        _tip(alice, amount);
        uint256 recipientBalance = usdc.balanceOf(recipient);

        vm.startPrank(owner);
        jar.setWithdrawalAddress(recipient);
        jar.withdraw();
        vm.stopPrank();

        assertEq(usdc.balanceOf(recipient), recipientBalance + amount);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.owner(), owner);
        assertEq(jar.withdrawalAddress(), recipient);
        assertEq(jar.totalTips(), amount);
    }

    function testFuzz_InsufficientAllowance(uint256 amount, uint256 allowance)
        public
    {
        amount = bound(amount, 1, STARTING_BALANCE);
        allowance = bound(allowance, 0, amount - 1);

        vm.startPrank(alice);
        usdc.approve(address(jar), allowance);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(jar),
                allowance,
                amount
            )
        );
        jar.tip(amount, "Insufficient approval");
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), STARTING_BALANCE);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(usdc.allowance(alice, address(jar)), allowance);
        assertEq(jar.totalTips(), 0);
        assertEq(jar.tipCount(), 0);
        assertEq(jar.tippedBy(alice), 0);
        assertEq(jar.largestTip(), 0);
        assertEq(jar.largestTipper(), address(0));
    }

    function testFuzz_DirectTransfers(uint256 amount, uint256 donation) public {
        amount = bound(amount, 1, STARTING_BALANCE);
        donation = bound(donation, 1, STARTING_BALANCE);
        _tip(alice, amount);
        vm.prank(bob);
        usdc.transfer(address(jar), donation);

        vm.prank(owner);
        jar.withdraw();

        assertEq(usdc.balanceOf(owner), amount + donation);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), amount);
        assertEq(jar.tipCount(), 1);
        assertEq(jar.tippedBy(alice), amount);
        assertEq(jar.tippedBy(bob), 0);
        assertEq(jar.largestTip(), amount);
        assertEq(jar.largestTipper(), alice);
    }

    function _tip(address tipper, uint256 amount) internal {
        vm.startPrank(tipper);
        usdc.approve(address(jar), amount);
        jar.tip(amount, "");
        vm.stopPrank();
    }
}
