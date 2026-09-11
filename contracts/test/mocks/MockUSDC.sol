// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Token for local tests and Anvil; anyone can mint. Not real USDC.
// "is ERC20" inherits OpenZeppelin's balances, allowances, and transfer logic.
contract MockUSDC is ERC20 {
    // Pass the display name and symbol to the parent ERC20 constructor.
    constructor() ERC20("Mock USDC", "mUSDC") {}

    // "override" replaces ERC20's default of 18 decimals with USDC's 6.
    // "pure" means this function does not read or change contract state.
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    function mint(address recipient, uint256 amount) external {
        // Create test tokens: increase both total supply and recipient balance.
        // This is a test-only shortcut; real testnet USDC comes from a faucet.
        _mint(recipient, amount);
    }
}
