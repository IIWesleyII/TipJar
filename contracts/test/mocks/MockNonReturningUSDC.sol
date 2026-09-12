// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {MockUSDC} from "./MockUSDC.sol";

/// @notice Tests SafeERC20 support for tokens that transfer but return no data.
contract MockNonReturningUSDC is MockUSDC {
    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        super.transfer(to, amount);
        // Test-only: finish the call with zero return bytes after moving tokens.
        assembly {
            return(0, 0)
        }
    }

    function transferFrom(address from, address to, uint256 amount)
        public
        override
        returns (bool)
    {
        super.transferFrom(from, to, amount);
        assembly {
            return(0, 0)
        }
    }
}
