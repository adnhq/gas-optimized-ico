// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import {SafeTransferLib} from "./utils/SafeTransferLib.sol";
/**
 * @notice Bare-bones gas-efficient token sale implementation using yul.
 * @author adnhq
 * Perform independent thorough tests before use. 
 */
contract TokenSale {
    /**
     * @dev Token sale end timestamp has been reached.
     */
    error SaleEnded();

    /**
     * @dev Could not get token balance of the contract.
     */
    error BalanceCheckFailed(); 

    /**
     * @dev Purchase exceeds remaining token supply.
     */
    error ExceedsRemainingSupply();

    /**
     * @dev Insufficient ether provided for purchase.
     */
    error InsufficientEth();

    /**
     * @dev Sale has not ended yet.
     */
    error SaleActive();

    /**
     * @dev Sample values.
     */
    uint256 public constant END_TIMESTAMP = 1704045599; // Sun Dec 31 2023 23:59:59 GMT+0600
    uint256 public constant RATE = 20;                  // Token units per wei.

    /**
     * @dev Replace.
     */
    address private constant _TREASURY = 0x0000000000000000000000000000000000000000;
    address public token = 0x0000000000000000000000000000000000000000;
    
    /**
     * @notice Purchase tokens in exchange for ETH.
     * 
     * Requirements:
     * 
     * - `END_TIMESTAMP` must not have been reached.
     * - purchase amount must not be greater than token supply of contract.
     * - ETH must have sent with the transaction.
     */
    function purchase() external payable {
        uint256 tokenAmount = getOutputAmount(msg.value); // Purchase is valid if does not revert.
        SafeTransferLib.safeTransferAllETH(_TREASURY); 
        SafeTransferLib.safeTransfer(token, msg.sender, tokenAmount);
    }

    /**
     * @notice Returns remaining supply of tokens in the contract.
     * @return supply Token balance of the contract.
     */
    function getRemainingSupply() public view returns (uint256 supply) {
        /// @solidity memory-safe-assembly
        assembly {
            mstore(0x00, 0x70a08231) // Store the function selector of `balanceOf(address)`.
            mstore(0x20, address()) // Store the address of the current contract.
            // Read the balance, reverting upon failure.

            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), sload(token.slot), 0x1c, 0x24, 0x34, 0x20)
                )
            ) {
                mstore(0x00, 0x150a8082) // `BalanceCheckFailed()`.
                revert(0x1c, 0x04)
            }
            
            supply := mload(0x34)
        }
    }

    /**
     * @notice Returns amount of tokens to be received in exchange for `ethAmount`.
     * @return tokenAmount Amount of tokens to be received in exchange.
     */
    function getOutputAmount(uint256 ethAmount) public view returns (uint256 tokenAmount) {
        /// @solidity memory-safe-assembly
        assembly {
            if iszero(ethAmount) {
                mstore(0x00, 0xa01a9df6) // `InsufficientEth()`.
                revert(0x1c, 0x04)
            }

            if gt(timestamp(), END_TIMESTAMP) {
                mstore(0x00, 0x0bd8a3eb) // `SaleEnded()`.
                revert(0x1c, 0x04)
            }

            mstore(0x00, 0x70a08231) // Store the function selector of `balanceOf(address)`.
            mstore(0x20, address()) // Store the address of the current contract.
            // Read the balance, reverting upon failure.
            if iszero(
                and( // The arguments of `and` are evaluated from right to left.
                    gt(returndatasize(), 0x1f), // At least 32 bytes returned.
                    staticcall(gas(), sload(token.slot), 0x1c, 0x24, 0x34, 0x20)
                )
            ) {
                mstore(0x00, 0x150a8082) // `BalanceCheckFailed()`.
                revert(0x1c, 0x04)
            }
            
            tokenAmount := mul(ethAmount, RATE)
            
            if lt(mload(0x34), tokenAmount) {
                mstore(0x00, 0x080c5d9e) // `ExceedsRemainingSupply()`.
                revert(0x1c, 0x04)
            }
        }
    }

    /**
     * @notice Transfers unsold tokens to treasury.
     *         Caller validation skipped as recipient is hardcoded.
     */
    function transferExcessTokensToTreasury() external {
        assembly {
            if lt(timestamp(), END_TIMESTAMP) {
                mstore(0x00, 0xf1d2165f) // `SaleActive()`.
                revert(0x1c, 0x04)
            }
            
        }
        SafeTransferLib.safeTransferAll(token, _TREASURY);
    }
}
