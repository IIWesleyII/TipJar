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

    /// @notice Destination for withdrawals; changing it does not change owner.
    address public withdrawalAddress;

    /// @notice Lifetime tips in token base units, unaffected by withdrawals.
    // uint256 is a nonnegative integer. For USDC, 1_000_000 units = 1 USDC.
    uint256 public totalTips;

    /// @notice Number of successful tips, including repeat tips by one wallet.
    uint256 public tipCount;

    /// @notice Lifetime amount tipped by each address, in USDC base units.
    // A mapping looks up a value by a key: wallet address => amount tipped.
    // Addresses start at zero. "public" creates tippedBy(address) for reads.
    mapping(address => uint256) public tippedBy;

    /// @notice Largest single successful tip, in USDC base units.
    uint256 public largestTip;

    /// @notice Sender of that tip; address(0) until the first successful tip.
    address public largestTipper;

    // Events record activity in transaction logs. "indexed" lets apps filter
    // those logs by address without us storing a list of tips in this contract.
    event TipReceived(address indexed tipper, uint256 amount, string message);
    event Withdrawal(address indexed recipient, uint256 amount);
    event WithdrawalAddressChanged(
        address indexed previousAddress, address indexed newAddress
    );

    // Custom errors identify failures without storing long revert messages.
    error InvalidAmount();
    error Unauthorized();
    error InvalidAddress();
    error NothingToWithdraw();

    // Both administrative functions share this check. "_" runs their body
    // only after the caller has passed the owner check.
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

    constructor(address usdcAddress) {
        // The constructor runs once, when the jar is deployed. A token needs
        // contract code; this check alone does not prove it is genuine USDC.
        if (usdcAddress == address(0) || usdcAddress.code.length == 0) {
            revert InvalidAddress();
        }

        // Refer to an existing token through its interface; no token is created.
        usdc = IERC20(usdcAddress);
        // msg.sender is the caller: here, the account deploying the jar.
        owner = msg.sender;
        withdrawalAddress = msg.sender;
    }

    /// @notice Tip in USDC base units after approving this jar on the token.
    /// @param message Optional public message; pass "" to leave it empty.
    // "external" makes this an entry point for wallets and other contracts.
    // "calldata" reads the supplied text directly from the call's input data.
    // We cannot modify it here, and we do not save it in a storage variable.
    function tip(uint256 amount, string calldata message) external {
        // A revert stops the call and undoes its state changes.
        if (amount == 0) revert InvalidAmount();

        // If the transfer fails, the transaction rolls back all statistics.
        totalTips += amount;
        tipCount += 1;
        // Add to this caller's total without changing anyone else's entry.
        tippedBy[msg.sender] += amount;

        // Compare this individual tip, not the caller's lifetime contribution.
        // Strictly greater means an equal tip keeps the first record holder.
        if (amount > largestTip) {
            largestTip = amount;
            largestTipper = msg.sender;
        }

        // msg.sender is the tipper; address(this) is the jar. Inside the token
        // call, the jar is the spender, so it needs the tipper's prior approval.
        usdc.safeTransferFrom(msg.sender, address(this), amount);

        // Put the message in the event so clients can read it from past logs.
        emit TipReceived(msg.sender, amount, message);
    }

    function withdraw() external onlyOwner {
        // Ask the token for the jar's actual balance. totalTips is historical
        // and may differ after withdrawals or direct transfers into the jar.
        uint256 balance = usdc.balanceOf(address(this));
        if (balance == 0) revert NothingToWithdraw();

        address recipient = withdrawalAddress;
        // No approval is needed to transfer tokens owned by the jar itself.
        // All lifetime statistics, including the largest tip, stay unchanged.
        usdc.safeTransfer(recipient, balance);

        emit Withdrawal(recipient, balance);
    }

    function setWithdrawalAddress(address newWithdrawalAddress)
        external
        onlyOwner
    {
        // Sending back to this jar would leave the funds inside it.
        if (
            newWithdrawalAddress == address(0)
                || newWithdrawalAddress == address(this)
        ) revert InvalidAddress();

        address previousAddress = withdrawalAddress;
        withdrawalAddress = newWithdrawalAddress;

        emit WithdrawalAddressChanged(previousAddress, newWithdrawalAddress);
    }
}
