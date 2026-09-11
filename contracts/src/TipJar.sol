// SPDX-License-Identifier: MIT
// Compile this contract with Solidity version 0.8.24.
pragma solidity 0.8.24;

// IERC20 describes token functions such as balanceOf, approve, and transfer.
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    SafeERC20
} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @notice Collects tips in a configured, trusted USDC token.
contract TipJar {
    // Adds helpers such as usdc.safeTransfer() that check transfer failures.
    using SafeERC20 for IERC20;

    // These are fixed at deployment. "public" creates read functions:
    // usdc() returns the token address, and owner() returns the owner address.
    IERC20 public immutable usdc;
    address public immutable owner;

    /// @notice Lifetime tips in token base units, unaffected by withdrawals.
    // uint256 is a nonnegative integer. For USDC, 1_000_000 units = 1 USDC.
    uint256 public totalTips;

    // Events record activity in transaction logs. "indexed" lets apps filter
    // those logs by address without us storing a list of tips in this contract.
    event TipReceived(address indexed tipper, uint256 amount);
    event Withdrawal(address indexed recipient, uint256 amount);

    constructor(address usdcAddress) {
        // The constructor runs once, when the jar is deployed. A token needs
        // contract code; this check alone does not prove it is genuine USDC.
        require(usdcAddress != address(0), "Invalid token address");
        require(usdcAddress.code.length > 0, "Token must be a contract");

        // Refer to an existing token through its interface; no token is created.
        usdc = IERC20(usdcAddress);
        // msg.sender is the caller: here, the account deploying the jar.
        owner = msg.sender;
    }

    /// @notice Tip in USDC base units after approving this jar on the token.
    // "external" makes this an entry point for wallets and other contracts.
    function tip(uint256 amount) external {
        // A failed require stops the call and undoes its state changes.
        require(amount > 0, "Amount must be positive");

        // If the transfer fails, the entire transaction rolls back this update.
        totalTips += amount;
        // msg.sender is the tipper; address(this) is the jar. Inside the token
        // call, the jar is the spender, so it needs the tipper's prior approval.
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        emit TipReceived(msg.sender, amount);
    }

    function withdraw() external {
        // Anyone can try calling this function; only the owner can pass here.
        require(msg.sender == owner, "Only owner");

        // Ask the token for the jar's actual balance. totalTips is historical
        // and may differ after withdrawals or direct transfers into the jar.
        uint256 balance = usdc.balanceOf(address(this));
        require(balance > 0, "Nothing to withdraw");

        // No approval is needed to transfer tokens owned by the jar itself.
        // totalTips stays unchanged because withdrawing does not undo past tips.
        usdc.safeTransfer(owner, balance);

        emit Withdrawal(owner, balance);
    }
}
