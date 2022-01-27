// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import "./interfaces/IERC4626.sol";
import "./interfaces/IStrategy.sol";

contract Vault is ERC20("Mock cERC20 Strategy", "cERC20", 18), IERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    ERC20 immutable UNDERLYING;
    uint256 immutable BASE_UNIT;

    // strategy variables
    mapping(address => bool) public isStrategy;
    address[] public strategies;

    // buffer variables
    // todo sort scaling params / use rational_const type
    uint256 public buffer_ceil = 1;
    uint256 public buffer_floor = 1;

    constructor(ERC20 underlying, uint256 baseUnit) {
        UNDERLYING = underlying;
        BASE_UNIT = baseUnit;

        // todo: init default strategies
        strategies.push(address(this));
    }

    /**
      @notice Deposit a specific amount of underlying tokens.
      @param to The address to receive shares corresponding to the deposit
      @param underlyingAmount The amount of the underlying token to deposit.
      @return shares The shares in the vault credited to `to`
    */
    function deposit(address to, uint256 underlyingAmount) public override returns (uint256 shares) {
        shares = underlyingAmount.fdiv(exchangeRate(), BASE_UNIT);
        _mint(to, shares);
        UNDERLYING.safeTransferFrom(msg.sender, address(this), underlyingAmount);
        bufferUpKeep();
    }

    /**
      @notice Withdraw a specific amount of underlying tokens.
      @param to The address to receive underlying corresponding to the withdrawal.
      @param underlyingAmount The amount of the underlying token to withdraw.
      @return shares The shares in the vault burned from sender
    */
    function withdraw(address to, uint256 underlyingAmount) public override returns (uint256 shares) {
        // todo: This function needs to generalise for N strategies
        IStrategy strategy = IStrategy(strategies[0]);

        uint256 shares = underlyingAmount.fdiv(exchangeRate(), BASE_UNIT);
        uint256 preUnderlying = balanceOfUnderlying(address(this));

        //Check if requested withdraw amount is above vaults underlying balance
        if (underlyingAmount > preUnderlying) {
            uint256 diff = underlyingAmount - preUnderlying;

            // withdraw differece from strategy to fund withdrawal
            strategy.withdraw(diff);

            // check if withdraw gave us enough tokens back
            uint256 postUnderlying = balanceOfUnderlying(address(this));
            if (underlyingAmount > postUnderlying) {
                // still don't have enough, pay out as much as possible
                uint256 actualShares = postUnderlying.fdiv(exchangeRate(), BASE_UNIT);
                _burn(msg.sender, actualShares);
                UNDERLYING.safeTransfer(to, underlyingAmount);
            } else {
                // have enough balance to now process the whole withdraw
                _burn(msg.sender, shares);
                UNDERLYING.safeTransfer(to, underlyingAmount);
            }
        } else {
            // balance is fine to process the whole withdraw
            _burn(msg.sender, shares);
            UNDERLYING.safeTransfer(to, underlyingAmount);
        }
        bufferUpKeep();
    }

    /**
      @notice Withdraw a specific amount of underlying tokens on behalf of `from`.
      @param from The address to debit shares from corresponding to the withdrawal.
      @param to The address to receive underlying corresponding to the withdrawal.
      @param underlyingAmount The amount of the underlying token to withdraw.
      @return shares The shares in the vault burned from `from`.
      @dev requires ERC-20 approval of the ERC-4626 shares by sender.
    */
    function withdrawFrom(
        address from,
        address to,
        uint256 underlyingAmount
    ) public virtual override returns (uint256 shares) {
        shares = underlyingAmount.fdiv(exchangeRate(), BASE_UNIT);

        _burn(from, shares);

        UNDERLYING.safeTransfer(to, underlyingAmount);
    }

    /**
      @notice Redeem a specific amount of shares for underlying tokens.
      @param to The address to receive underlying corresponding to the redemption.
      @param shareAmount The amount of shares to redeem.
      @return value The underlying amount transferred to `to`.
    */
    function redeem(address to, uint256 shareAmount) public virtual override returns (uint256 value) {
        value = shareAmount.fmul(exchangeRate(), BASE_UNIT);

        _burn(msg.sender, shareAmount);

        UNDERLYING.safeTransfer(to, value);
    }

    /**
      @notice Redeem a specific amount of shares for underlying tokens on behalf of `from`.
      @param from The address to debit shares from corresponding to the redemption.
      @param to The address to receive underlying corresponding to the redemption.
      @param shareAmount The amount of shares to redeem.
      @return value The underlying amount transferred to `to`.
    */
    function redeemFrom(
        address from,
        address to,
        uint256 shareAmount
    ) public virtual override returns (uint256 value) {
        value = shareAmount.fdiv(exchangeRate(), BASE_UNIT);

        _burn(from, value);

        UNDERLYING.safeTransfer(to, shareAmount);
    }

    /*///////////////////////////////////////////////////////////////
                    Tracer Custom Mutable Functions
    //////////////////////////////////////////////////////////////*/

    //sets an approved strategy
    // todo: re add access control here
    function setApprovedStrategy(address strategy, bool status) public {
        isStrategy[strategy] = status;
    }

    // Function to withdraw from a specific strategy
    function withdrawFromStrategy(address strategy, uint256 amount) internal {
        // todo the logic to check how much was returned from the strategy could go here
        require(isStrategy[strategy], "STRATEGY NOT APPROVED");
        IStrategy(strategy).withdraw(amount);
    }

    //Function to rebalance Strategy to approach buffer
    function bufferUpKeep() public returns (bool) {
        //calls strategy for buffer funds
        //TODO: how to bulk rebalance strategies, is this possible?
        // for (true in Strategies) {
        //     strategy.rebalance();
        //     return true;
        // }
    }

    /*///////////////////////////////////////////////////////////////
                    Tracer Custom View Functions
    //////////////////////////////////////////////////////////////*/
    // The Vault contracts buffer balance should be above 0.05 of total
    function buffer() public view returns (uint256) {
        // todo
        //return (balanceOf(address(this)) + balanceOf(address(strategyAddr))) * buffer_ceil;
        return 0;
    }

    //safe vault balance should be above 0.025 of total
    function safeVaultBalance() public view returns (uint256) {
        // todo
        return 0;
        //return (buffer_floor * (balanceOf(address(this)) + balanceOf(address(strategy))));
    }

    //Checks the strategys balance
    function getValue(address strategy) external view returns (uint256) {
        // some logic to call strategy value
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /** 
        Get the exchange rate between shares and underlying tokens.
    */

    function exchangeRate() internal view returns (uint256) {
        uint256 cTokenSupply = totalSupply;

        if (cTokenSupply == 0) return BASE_UNIT;

        return UNDERLYING.balanceOf(address(this)).fdiv(cTokenSupply, BASE_UNIT);
    }

    /** 
      @notice The underlying token the Vault accepts.
      @return the ERC20 underlying implementation address.
    */
    function underlying() public view virtual override returns (address) {
        return address(UNDERLYING);
    }

    /** 
      @notice Returns a user's Vault balance in underlying tokens.
      @param user The user to get the underlying balance of.
      @return balance The user's Vault balance in underlying tokens.
    */
    function balanceOfUnderlying(address user) public view virtual override returns (uint256 balance) {
        return balanceOf[user].fmul(exchangeRate(), BASE_UNIT);
    }

    /** 
      @notice Calculates the total amount of underlying tokens the Vault holds.
      @return totalUnderlyingHeld The total amount of underlying tokens the Vault holds.
    */
    function totalHoldings() public view virtual override returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
        //add logic to return current buffer balance
    }

    /** 
      @notice Calculates the amount of shares corresponding to an underlying amount.
      @param underlyingAmount the amount of underlying tokens to convert to shares.
      @return shareAmount the amount of shares corresponding to a given underlying amount
    */
    function calculateShares(uint256 underlyingAmount) public view virtual override returns (uint256 shareAmount) {
        shareAmount = underlyingAmount.fdiv(exchangeRate(), BASE_UNIT);
    }

    /** 
      @notice Calculates the amount of underlying corresponding to a share amount.
      @param shareAmount the amount of shares to convert to an underlying amount.
      @return underlyingAmount the amount of underlying corresponding to a given amount of shares.
    */
    function calculateUnderlying(uint256 shareAmount) public view virtual override returns (uint256 underlyingAmount) {
        underlyingAmount = shareAmount.fmul(exchangeRate(), BASE_UNIT);
    }
}
