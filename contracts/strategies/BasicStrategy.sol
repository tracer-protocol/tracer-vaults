pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";

contract BasicStrategy is IStrategy {

    constructor() {

    }

    function value() external view returns(uint256) {
        return 0;
    }

    /**
    * @notice triggers a rebalance on the strategy.
    */
    function rebalance() external {
        //TODO This is the bulk of the strategy
    }

    /**
    * @notice returns the maximum amount of underlying that can be safely withdrawn
    * from this strategy instantly.
    */
    function withdrawable() external view returns(uint256) {
        return 0;
    }

    /**
    * @notice withdraws a maximum of amount underlying from the strategy. Only callable
    * by the vault.
    * @param amount the amount of underlying tokens request to be withdrawn.
    */
    function withdraw(uint256 amount) external {}
}