//SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.0;

interface IStrategy {
    /**
     * @notice returns the current value the strategy is holding
     * in units of the vaults underlying collateral
     */
    function value() external view returns (uint256);

    /**
     * @notice triggers a rebalance on the strategy.
     */
    function rebalance() external;

    /**
     * @notice returns the maximum amount of underlying that can be safely withdrawn
     * from this strategy instantly.
     */
    function withdrawable() external view returns (uint256);

    /**
     * @notice withdraws a maximum of amount underlying from the strategy. Only callable
     * by the vault.
     * @param amount the amount of underlying tokens request to be withdrawn.
     */
    function withdraw(uint256 amount) external;

    /**
    * @notice deposits into the strategy
    * @dev this hook can be used to update and strategy state / deposit into external contracts
    */
    function deposit(uint256 amount) external;

    function requestWithdraw(uint256 amount) external;
}
