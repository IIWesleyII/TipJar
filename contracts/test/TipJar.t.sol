// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {
    IERC20Errors
} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {MockUSDC} from "./mocks/MockUSDC.sol";
import {MockNonReturningUSDC} from "./mocks/MockNonReturningUSDC.sol";
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

    event TipReceived(address indexed tipper, uint256 amount, string message);
    event Withdrawal(address indexed recipient, uint256 amount);
    event WithdrawalAddressChanged(
        address indexed previousAddress, address indexed newAddress
    );

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
        assertEq(jar.withdrawalAddress(), owner);
        assertEq(jar.totalTips(), 0);
        assertEq(jar.tipCount(), 0);
        assertEq(jar.tippedBy(alice), 0);
        assertEq(jar.tippedBy(bob), 0);
        assertEq(jar.largestTip(), 0);
        assertEq(jar.largestTipper(), address(0));
    }

    function test_MockUSDCHasSixDecimals() public view {
        assertEq(usdc.decimals(), 6);
        assertEq(usdc.balanceOf(alice), 100_000_000);
    }

    function test_CannotConfigureZeroToken() public {
        vm.expectRevert(TipJar.InvalidAddress.selector);
        new TipJar(address(0));
    }

    function test_CannotConfigureNonContractToken() public {
        vm.expectRevert(TipJar.InvalidAddress.selector);
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
        assertEq(jar.tipCount(), 0);
        assertEq(jar.tippedBy(alice), 0);

        // Check the indexed tipper, amount, empty message, and emitter.
        // The next emit is the expected template; jar.tip must emit a match.
        vm.expectEmit(true, false, false, true, address(jar));
        emit TipReceived(alice, amount, "");
        // Optional means passing an empty string, not omitting the argument.
        jar.tip(amount, "");
        vm.stopPrank();

        assertEq(usdc.balanceOf(alice), STARTING_BALANCE - amount);
        assertEq(usdc.balanceOf(address(jar)), amount);
        // Spending the exact approved amount uses up the allowance.
        assertEq(usdc.allowance(alice, address(jar)), 0);
        assertEq(jar.totalTips(), amount);
    }

    function test_TipEmitsMessage() public {
        uint256 amount = 10 * 1e6;
        // "memory" holds this test's temporary string. The jar receives it
        // as calldata when the test makes the external call below.
        string memory message = "Thanks for explaining Solidity!";

        vm.startPrank(alice);
        usdc.approve(address(jar), amount);
        vm.expectEmit(true, false, false, true, address(jar));
        emit TipReceived(alice, amount, message);
        jar.tip(amount, message);
        vm.stopPrank();

        // Including a message does not change the token or statistics rules.
        assertEq(usdc.balanceOf(alice), STARTING_BALANCE - amount);
        assertEq(usdc.balanceOf(address(jar)), amount);
        assertEq(jar.totalTips(), amount);
        assertEq(jar.tipCount(), 1);
        assertEq(jar.tippedBy(alice), amount);
        assertEq(jar.largestTip(), amount);
        assertEq(jar.largestTipper(), alice);
    }

    function test_TipPreservesUnicodeAndNewlinesInMessage() public {
        string memory message = unicode"Merci! \u2615\nGreat explanation.";
        uint256 amount = 1 * 1e6;

        vm.startPrank(bob);
        usdc.approve(address(jar), amount);
        vm.expectEmit(true, false, false, true, address(jar));
        emit TipReceived(bob, amount, message);
        jar.tip(amount, message);
        vm.stopPrank();
    }

    function test_MultipleUsersAndRepeatedTipsAccumulate() public {
        _tip(alice, 10 * 1e6);
        _tip(bob, 20 * 1e6);
        _tip(alice, 5 * 1e6);

        assertEq(jar.totalTips(), 35 * 1e6);
        assertEq(jar.tipCount(), 3);
        assertEq(jar.tippedBy(alice), 15 * 1e6);
        assertEq(jar.tippedBy(bob), 20 * 1e6);
        assertEq(jar.tippedBy(owner), 0);
        assertEq(usdc.balanceOf(address(jar)), 35 * 1e6);
        assertEq(usdc.balanceOf(alice), 85 * 1e6);
        assertEq(usdc.balanceOf(bob), 80 * 1e6);
    }

    function test_TipUpdatesTipCount() public {
        _tip(alice, 10 * 1e6);
        assertEq(jar.tipCount(), 1);

        // A repeat tip counts as another tip, even from the same wallet.
        _tip(alice, 5 * 1e6);
        assertEq(jar.tipCount(), 2);
    }

    function test_TipUpdatesUserContribution() public {
        _tip(alice, 10 * 1e6);
        assertEq(jar.tippedBy(alice), 10 * 1e6);
        assertEq(jar.tippedBy(bob), 0);

        _tip(alice, 5 * 1e6);
        assertEq(jar.tippedBy(alice), 15 * 1e6);
        assertEq(jar.tippedBy(bob), 0);
    }

    function test_TipUpdatesLargestTip() public {
        _tip(alice, 10 * 1e6);
        assertEq(jar.largestTip(), 10 * 1e6);
        assertEq(jar.largestTipper(), alice);

        _tip(bob, 20 * 1e6);
        assertEq(jar.largestTip(), 20 * 1e6);
        assertEq(jar.largestTipper(), bob);
    }

    function test_SmallerTipsDoNotReplaceLargestTip() public {
        _tip(bob, 20 * 1e6);
        _tip(alice, 15 * 1e6);
        _tip(alice, 15 * 1e6);

        // Alice gave more overall, but Bob still sent the largest single tip.
        assertEq(jar.tippedBy(alice), 30 * 1e6);
        assertEq(jar.largestTip(), 20 * 1e6);
        assertEq(jar.largestTipper(), bob);
    }

    function test_EqualTipKeepsFirstLargestTipper() public {
        _tip(alice, 10 * 1e6);
        _tip(bob, 10 * 1e6);

        assertEq(jar.largestTip(), 10 * 1e6);
        assertEq(jar.largestTipper(), alice);
        assertEq(jar.tipCount(), 2);
        assertEq(jar.tippedBy(bob), 10 * 1e6);
    }

    function test_CanSetNewLargestTipAfterWithdrawal() public {
        _tip(alice, 10 * 1e6);
        vm.prank(owner);
        jar.withdraw();

        // The current record holder can beat their own record too.
        _tip(alice, 15 * 1e6);

        assertEq(jar.largestTip(), 15 * 1e6);
        assertEq(jar.largestTipper(), alice);
        assertEq(jar.totalTips(), 25 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 15 * 1e6);
    }

    function test_CannotTipZero() public {
        vm.prank(alice);
        vm.expectRevert(TipJar.InvalidAmount.selector);
        jar.tip(0, "A message cannot make a zero tip valid");
        _assertFailedTipLeftBalancesUnchanged();
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
        jar.tip(amount, "This tip has no approval");
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
        jar.tip(10 * 1e6, "");
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
        jar.tip(amount, "This tip exceeds my balance");
        vm.stopPrank();

        _assertFailedTipLeftBalancesUnchanged();
        assertEq(usdc.allowance(alice, address(jar)), amount);
    }

    function test_FailedTipPreservesExistingStatistics() public {
        _tip(alice, 10 * 1e6);
        _tip(bob, 20 * 1e6);

        // Alice's first tip used her allowance. Her attempted new record must
        // roll back on failure, preserving Bob's existing record and all totals.
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                IERC20Errors.ERC20InsufficientAllowance.selector,
                address(jar),
                0,
                25 * 1e6
            )
        );
        jar.tip(25 * 1e6, "This attempted record must fail");

        assertEq(jar.totalTips(), 30 * 1e6);
        assertEq(jar.tipCount(), 2);
        assertEq(jar.tippedBy(alice), 10 * 1e6);
        assertEq(jar.tippedBy(bob), 20 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 30 * 1e6);
        assertEq(usdc.balanceOf(alice), 90 * 1e6);
        assertEq(jar.largestTip(), 20 * 1e6);
        assertEq(jar.largestTipper(), bob);
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
        assertEq(jar.tipCount(), 2);
        assertEq(jar.tippedBy(alice), 10 * 1e6);
        assertEq(jar.tippedBy(bob), 20 * 1e6);
        assertEq(jar.largestTip(), 20 * 1e6);
        assertEq(jar.largestTipper(), bob);
    }

    function test_NonOwnerCannotWithdraw() public {
        _tip(alice, 10 * 1e6);

        vm.prank(alice);
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.withdraw();

        assertEq(usdc.balanceOf(address(jar)), 10 * 1e6);
        assertEq(usdc.balanceOf(owner), 0);
        assertEq(jar.totalTips(), 10 * 1e6);
    }

    function test_CannotWithdrawEmptyJar() public {
        vm.prank(owner);
        vm.expectRevert(TipJar.NothingToWithdraw.selector);
        jar.withdraw();
    }

    function test_CanTipAndWithdrawAgain() public {
        _tip(alice, 10 * 1e6);
        vm.prank(owner);
        jar.withdraw();

        vm.prank(owner);
        vm.expectRevert(TipJar.NothingToWithdraw.selector);
        jar.withdraw();

        _tip(bob, 5 * 1e6);
        vm.prank(owner);
        jar.withdraw();

        assertEq(usdc.balanceOf(owner), 15 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), 15 * 1e6);
        assertEq(jar.tipCount(), 2);
        assertEq(jar.tippedBy(alice), 10 * 1e6);
        assertEq(jar.tippedBy(bob), 5 * 1e6);
        assertEq(jar.largestTip(), 10 * 1e6);
        assertEq(jar.largestTipper(), alice);
    }

    function test_DirectTransfersAreWithdrawableButNotCountedAsTips() public {
        _tip(alice, 10 * 1e6);
        // Sending tokens directly bypasses tip() and its statistics updates.
        vm.prank(bob);
        usdc.transfer(address(jar), 30 * 1e6);

        assertEq(jar.totalTips(), 10 * 1e6);
        vm.prank(owner);
        jar.withdraw();

        assertEq(usdc.balanceOf(owner), 40 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), 10 * 1e6);
        assertEq(jar.tipCount(), 1);
        assertEq(jar.tippedBy(alice), 10 * 1e6);
        assertEq(jar.tippedBy(bob), 0);
        assertEq(jar.largestTip(), 10 * 1e6);
        assertEq(jar.largestTipper(), alice);
    }

    function test_OwnerCanChangeWithdrawalAddress() public {
        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(jar));
        emit WithdrawalAddressChanged(owner, bob);
        jar.setWithdrawalAddress(bob);

        assertEq(jar.withdrawalAddress(), bob);
        assertEq(jar.owner(), owner);

        // The destination may change again, including back to the owner.
        vm.prank(owner);
        vm.expectEmit(true, true, false, false, address(jar));
        emit WithdrawalAddressChanged(bob, owner);
        jar.setWithdrawalAddress(owner);
        assertEq(jar.withdrawalAddress(), owner);
    }

    function test_NonOwnerCannotChangeWithdrawalAddress() public {
        vm.prank(alice);
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.setWithdrawalAddress(alice);
        assertEq(jar.withdrawalAddress(), owner);
    }

    function test_CannotSetZeroWithdrawalAddress() public {
        vm.prank(owner);
        vm.expectRevert(TipJar.InvalidAddress.selector);
        jar.setWithdrawalAddress(address(0));
        assertEq(jar.withdrawalAddress(), owner);
    }

    function test_CannotSetJarAsWithdrawalAddress() public {
        vm.prank(owner);
        vm.expectRevert(TipJar.InvalidAddress.selector);
        jar.setWithdrawalAddress(address(jar));
        assertEq(jar.withdrawalAddress(), owner);
    }

    function test_WithdrawTransfersToConfiguredRecipient() public {
        _tip(alice, 10 * 1e6);
        vm.prank(owner);
        jar.setWithdrawalAddress(bob);

        vm.prank(owner);
        vm.expectEmit(true, false, false, true, address(jar));
        emit Withdrawal(bob, 10 * 1e6);
        jar.withdraw();

        assertEq(usdc.balanceOf(bob), STARTING_BALANCE + 10 * 1e6);
        assertEq(usdc.balanceOf(owner), 0);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), 10 * 1e6);
        assertEq(jar.tipCount(), 1);
        assertEq(jar.tippedBy(alice), 10 * 1e6);
        assertEq(jar.largestTip(), 10 * 1e6);
        assertEq(jar.largestTipper(), alice);
    }

    function test_WithdrawalRecipientDoesNotGainOwnerAccess() public {
        _tip(alice, 10 * 1e6);
        vm.prank(owner);
        jar.setWithdrawalAddress(bob);

        vm.startPrank(bob);
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.withdraw();
        vm.expectRevert(TipJar.Unauthorized.selector);
        jar.setWithdrawalAddress(alice);
        vm.stopPrank();

        assertEq(jar.withdrawalAddress(), bob);
        assertEq(usdc.balanceOf(address(jar)), 10 * 1e6);
    }

    function test_CanTipOneBaseUnit() public {
        _tip(alice, 1);
        assertEq(jar.totalTips(), 1);
        assertEq(jar.tippedBy(alice), 1);
        assertEq(jar.largestTip(), 1);
        assertEq(usdc.balanceOf(address(jar)), 1);
    }

    function test_CanTipEntireBalance() public {
        _tip(alice, STARTING_BALANCE);
        assertEq(usdc.balanceOf(alice), 0);
        assertEq(usdc.balanceOf(address(jar)), STARTING_BALANCE);
        assertEq(jar.totalTips(), STARTING_BALANCE);
    }

    function test_TokenReturningFalseRejectsTip() public {
        vm.prank(alice);
        usdc.approve(address(jar), 10 * 1e6);
        // Simulate a token reporting failure instead of reverting itself.
        vm.mockCall(
            address(usdc),
            abi.encodeCall(
                IERC20.transferFrom, (alice, address(jar), 10 * 1e6)
            ),
            abi.encode(false)
        );
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20.SafeERC20FailedOperation.selector, address(usdc)
            )
        );
        jar.tip(10 * 1e6, "Failed token transfer");
        _assertFailedTipLeftBalancesUnchanged();
        assertEq(usdc.allowance(alice, address(jar)), 10 * 1e6);
    }

    function test_TokenReturningFalseRejectsWithdrawal() public {
        _tip(alice, 10 * 1e6);
        vm.mockCall(
            address(usdc),
            abi.encodeCall(IERC20.transfer, (owner, 10 * 1e6)),
            abi.encode(false)
        );
        vm.prank(owner);
        vm.expectRevert(
            abi.encodeWithSelector(
                SafeERC20.SafeERC20FailedOperation.selector, address(usdc)
            )
        );
        jar.withdraw();
        _assertCollectedTipStillPresent();

        vm.clearMockedCalls();
        vm.prank(owner);
        jar.withdraw();
        assertEq(usdc.balanceOf(owner), 10 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 0);
    }

    function test_RevertingTokenPreservesFundsOnWithdrawal() public {
        _tip(alice, 10 * 1e6);
        bytes memory tokenError = abi.encodeWithSignature("TokenPaused()");
        vm.mockCallRevert(
            address(usdc),
            abi.encodeCall(IERC20.transfer, (owner, 10 * 1e6)),
            tokenError
        );
        vm.prank(owner);
        vm.expectRevert(tokenError);
        jar.withdraw();
        _assertCollectedTipStillPresent();
    }

    function test_TokenWithNoReturnDataCanTipAndWithdraw() public {
        usdc = new MockNonReturningUSDC();
        vm.prank(owner);
        jar = new TipJar(address(usdc));
        usdc.mint(alice, STARTING_BALANCE);

        _tip(alice, 10 * 1e6);
        _assertCollectedTipStillPresent();
        vm.prank(owner);
        jar.withdraw();

        assertEq(usdc.balanceOf(alice), 90 * 1e6);
        assertEq(usdc.balanceOf(owner), 10 * 1e6);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(jar.totalTips(), 10 * 1e6);
    }

    function _assertCollectedTipStillPresent() internal view {
        assertEq(usdc.balanceOf(address(jar)), 10 * 1e6);
        assertEq(usdc.balanceOf(owner), 0);
        assertEq(jar.withdrawalAddress(), owner);
        assertEq(jar.totalTips(), 10 * 1e6);
        assertEq(jar.tipCount(), 1);
        assertEq(jar.tippedBy(alice), 10 * 1e6);
        assertEq(jar.largestTip(), 10 * 1e6);
        assertEq(jar.largestTipper(), alice);
    }

    // Reuse the approval + tip steps in tests. "internal" keeps this helper
    // callable within this test contract and derived contracts, not by wallets.
    function _tip(address tipper, uint256 amount) internal {
        vm.startPrank(tipper);
        usdc.approve(address(jar), amount);
        jar.tip(amount, "");
        vm.stopPrank();
    }

    function _assertFailedTipLeftBalancesUnchanged() internal view {
        // A failed transfer must also undo all of the jar's statistics updates.
        assertEq(jar.totalTips(), 0);
        assertEq(jar.tipCount(), 0);
        assertEq(jar.tippedBy(alice), 0);
        assertEq(jar.tippedBy(bob), 0);
        assertEq(usdc.balanceOf(address(jar)), 0);
        assertEq(usdc.balanceOf(alice), STARTING_BALANCE);
        assertEq(jar.largestTip(), 0);
        assertEq(jar.largestTipper(), address(0));
    }
}
