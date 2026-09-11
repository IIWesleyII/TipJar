// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {
    IERC20Errors
} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {TipJar} from "../src/TipJar.sol";

// Test supplies assertions and Foundry's "vm" simulation helpers.
contract TipJarTest is Test {
    MockUSDC internal usdc;
    TipJar internal jar;

    // Named test addresses, separate from the real wallets in your .env file.
    address internal owner = makeAddr("owner");
    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    // Each tipper starts with 100 mock USDC (100 million base units).
    uint256 internal constant STARTING_BALANCE = 100 * 1e6;

    event TipReceived(address indexed tipper, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);

    // Every test starts from this setup; tests do not share state changes.
    function setUp() public {
        usdc = new MockUSDC();
        // Simulate the owner deploying the jar. prank affects the next call.
        vm.prank(owner);
        jar = new TipJar(address(usdc));

        usdc.mint(alice, STARTING_BALANCE);
        usdc.mint(bob, STARTING_BALANCE);
    }

    // "view" allows reading state but not changing it. assertEq checks that
    // the actual value (first argument) equals the expected value (second).
    function test_ConstructorConfiguresTokenAndOwner() public view {
        assertEq(address(jar.usdc()), address(usdc));
        assertEq(jar.owner(), owner);
        assertEq(jar.totalTips(), 0);
    }

    function test_MockUSDCHasSixDecimals() public view {
        assertEq(usdc.decimals(), 6);
        assertEq(usdc.balanceOf(alice), 100_000_000);
    }

    function test_CannotConfigureZeroToken() public {
        vm.expectRevert("Invalid token address");
        new TipJar(address(0));
    }

    function test_CannotConfigureNonContractToken() public {
        vm.expectRevert("Token must be a contract");
        new TipJar(alice);
    }

    function test_UserCanTip() public {
        uint256 amount = 10 * 1e6;

        // Act as Alice for the following calls until vm.stopPrank().
        vm.startPrank(alice);
        usdc.approve(address(jar), amount);
        // Approval grants permission; it does not move tokens.
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), 0);

        // Check the indexed tipper, the amount in the event data, and emitter.
        // The next emit is the expected template; jar.tip must emit a match.
        vm.expectEmit(true, false, false, true, address(jar));
        emit TipReceived(alice, amount);
        jar.tip(amount);
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), STARTING_BALANCE - amount);
        assertEq(usdc.balanceOf(address(jar)), amount);
        // Spending the exact approved amount uses up the allowance.
        assertEq(usdc.allowance(alice, address(jar)), 0);
        assertEq(jar.totalTips(), amount);
    }

    function test_MultipleUsersAndRepeatedTipsAccumulate() public {
        _tip(alice, 10 * 1e6);
        _tip(bob, 20 * 1e6);
        _tip(alice, 5 * 1e6);

        assertEq(jar.totalTips(), 35 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 35 * 1e6);
        assertEq(usdc.balanceOf(alice), 85 * 1e6);
        assertEq(usdc.balanceOf(bob), 80 * 1e6);
    }

    function test_CannotTipZero() public {
        vm.prank(alice);
        vm.expectRevert("Amount must be positive");
        jar.tip(0);
        assertEq(jar.totalTips(), 0);
    }

    function test_CannotTipWithoutApproval() public {
        uint256 amount = 10 * 1e6;
        vm.prank(alice);
        // This test passes only if tipping fails with this exact token error.
        // The selector identifies the error; the remaining values encode its
        // details: spender = jar, available allowance = 0, required = amount.
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(jar),
                0,
                amount
            )
        );
        jar.tip(amount);
        _assertFailedTipLeftBalancesUnchanged();
    }

    function test_CannotTipAboveAllowance() public {
        vm.startPrank(alice);
        usdc.approve(address(jar), 5 * 1e6);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(jar),
                5 * 1e6,
                10 * 1e6
            )
        );
        jar.tip(10 * 1e6);
        vm.stopPrank();

        _assertFailedTipLeftBalancesUnchanged();
        assertEq(usdc.allowance(alice, address(jar)), 5 * 1e6);
    }

    function test_CannotTipAboveBalance() public {
        uint256 amount = STARTING_BALANCE + 1;
        vm.startPrank(alice);
        usdc.approve(address(jar), amount);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientBalance.selector,
                alice,
                STARTING_BALANCE,
                amount
            )
        );
        jar.tip(amount);
        vm.stopPrank();

        _assertFailedTipLeftBalancesUnchanged();
        assertEq(usdc.allowance(alice, address(jar)), amount);
    }

    function test_OwnerCanWithdraw() public {
        _tip(alice, 10 * 1e6);
        _tip(bob, 20 * 1e6);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(jar));
        emit Withdrawal(owner, 30 * 1e6);
        jar.withdraw();

        assertEq(usdc.balanceOf(owner), 30 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), 30 * 1e6);
    }

    function test_NonOwnerCannotWithdraw() public {
        _tip(alice, 10 * 1e6);

        vm.prank(alice);
        vm.expectRevert("Only owner");
        jar.withdraw();

        assertEq(usdc.balanceOf(address(jar)), 10 * 1e6);
        assertEq(usdc.balanceOf(owner), 0);
        assertEq(jar.totalTips(), 10 * 1e6);
    }

    function test_CannotWithdrawEmptyJar() public {
        vm.prank(owner);
        vm.expectRevert("Nothing to withdraw");
        jar.withdraw();
    }

    function test_CanTipAndWithdrawAgain() public {
        _tip(alice, 10 * 1e6);
        vm.prank(owner);
        jar.withdraw();

        vm.prank(owner);
        vm.expectRevert("Nothing to withdraw");
        jar.withdraw();

        _tip(bob, 5 * 1e6);
        vm.prank(owner);
        jar.withdraw();

        assertEq(usdc.balanceOf(owner), 15 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), 15 * 1e6);
    }

    function test_DirectTransfersAreWithdrawableButNotCountedAsTips() public {
        _tip(alice, 10 * 1e6);
        // Sending tokens directly bypasses tip(), so totalTips cannot see it.
        vm.prank(bob);
        usdc.transfer(address(jar), 3 * 1e6);

        assertEq(jar.totalTips(), 10 * 1e6);
        vm.prank(owner);
        jar.withdraw();

        assertEq(usdc.balanceOf(owner), 13 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), 10 * 1e6);
    }

    // Reuse the approval + tip steps in tests. "internal" keeps this helper
    // callable within this test contract and derived contracts, not by wallets.
    function _tip(address tipper, uint256 amount) internal {
        vm.startPrank(tipper);
        usdc.approve(address(jar), amount);
        jar.tip(amount);
        vm.stopPrank();
    }

    function _assertFailedTipLeftBalancesUnchanged() internal view {
        // A failed transfer must also undo the jar's earlier totalTips update.
        assertEq(jar.totalTips(), 0);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(usdc.balanceOf(alice), STARTING_BALANCE);
    }
}
