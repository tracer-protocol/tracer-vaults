pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// A Simple mock strategy contract. DO NOT USE IN PRODUCTIOn
contract MockStrategy is IStrategy, AccessControl {
    address public VAULT;
    // vault collateral asset
    IERC20 public VAULT_ASSET; //eg DAI in a ETH/USD+DAI pool

    // mock params for easy testing
    uint256 _value;

    function init(address vault, address vaultAsset) public {
        VAULT = vault;
        VAULT_ASSET = IERC20(vaultAsset);
        _value = VAULT_ASSET.balanceOf(address(this));
    }

    function value() external view override returns (uint256) {
        // collateral on hand + outstanding debt from external contracts denoted in the vault asset
        return _value;
    }

    /**
     * @notice triggers a rebalance on the strategy.
     */
    function rebalance() external override {
        //TODO I don't think this does anything since control is given to whitelisted addresses
    }

    /**
     * @notice returns the maximum amount of underlying that can be safely withdrawn
     * from this strategy instantly.
     */
    function withdrawable() external view override returns (uint256) {
        return VAULT_ASSET.balanceOf(address(this));
    }

    /**
     * @notice withdraws a maximum of amount underlying from the strategy. Only callable
     * by the vault.
     * @param amount the amount of underlying tokens request to be withdrawn.
     */
    function withdraw(uint256 amount) external override {
        // 1. Compute amount available to be transfered. Cap at balance of the strategy
        uint256 currentBalance = VAULT_ASSET.balanceOf(address(this));
        uint256 amountToTransfer = amount >= currentBalance ? currentBalance : amount;

        // 3. perform transfer
        VAULT_ASSET.transfer(VAULT, amountToTransfer);
    }

    /**
     * @dev this function is helpful for testing. It allows you to arbitrarily move funds
     * out of a strategy
     */
    function transferFromStrategy(address to, uint256 amount) external {
        VAULT_ASSET.transfer(to, amount);
    }

    /**
     * @dev sets the vaults value. Helpful for testing methods relying on this
     */
    function setValue(uint256 newValue) external {
        _value = newValue;
    }

    /**
    * @dev burns tokens to reduce the withdrawable amount
    */
    function setWithdrawable(uint256 newValue) external {
        uint256 currentBal = VAULT_ASSET.balanceOf(address(this));
        require(newValue <= currentBal, "new val too high");
        VAULT_ASSET.transfer(msg.sender, currentBal - newValue);
    }
}
