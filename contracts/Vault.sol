// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";

import {IERC4626} from "../../interfaces/IERC4626.sol";

abstract contract MockVault is ERC20("Mock cERC20 Strategy", "cERC20", 18), IERC4626 {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                Immutables
    //////////////////////////////////////////////////////////////*/

    ERC20 immutable UNDERLYING;
    uint256 immutable BASE_UNIT;
    address immutable ACTIONS;

    constructor(ERC20 underlying, uint256 baseUnit) {
        UNDERLYING = underlying;
        BASE_UNIT = baseUnit;
    }

    /*///////////////////////////////////////////////////////////////
                            Mutable Functions
    //////////////////////////////////////////////////////////////*/

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
    }

    /**
      @notice Withdraw a specific amount of underlying tokens.
      @param to The address to receive underlying corresponding to the withdrawal.
      @param underlyingAmount The amount of the underlying token to withdraw.
      @return shares The shares in the vault burned from sender
    */
    function withdraw(address to, uint256 underlyingAmount) public override returns (uint256 shares) {
        shares = underlyingAmount.fdiv(exchangeRate(), BASE_UNIT);

        _burn(msg.sender, shares);

        UNDERLYING.safeTransfer(to, underlyingAmount);
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


/// Function to deposit into strategy contract
 function depositToStrategy(address to, uint256 vaultUnderlyingAmount, address strategyAddr) public returns (uint256 shares) {
        //Todo: Declare shares -> Transfer to Strategy
        shares = vaultUnderlying.fdiv(exchangeRate(), BASE_UNIT);
        _mint(to, shares);
         UNDERLYING.safeTransferFrom(msg.sender, address(this), vaultUnderlyingAmount);
        // Rebalance: check buffer is >5%, else, rebalance
        uint buffer = (balanceOf(address(this))+ balanceOf(address(strategyAddr))* 0.05);
        if (buffer < balanceOf(address(this))){
            // Rebalance
            // uint256 shares = (balanceOf(address(this)) - buffer) / exchangeRate();
            // _mint(address(this), shares);
            // _burn(address(this), shares);
        }
        // shares = vaultUnderlying.fdiv(exchangeRate(), BASE_UNIT);

        // _mint(to, shares);

       
    }

    //Function to withdraw from Strategy
     function withdrawFromStrategy(
        address from,
        address to,
        uint256 underlyingAmount
    ) public returns (uint256 shares) {
      //todo: Burn shares for underlying - > transfer underlying to vault
        // shares = underlyingAmount.fdiv(exchangeRate(), BASE_UNIT);

        // _burn(from, shares);

        // UNDERLYING.safeTransfer(to, underlyingAmount);
    }
   
   function setApprovedStrategy(address[] memory _actions) internal onlyAdmin returns (bool) {
     //some logic to set strategy as approved strategy, if not implemented on the strategy contract
     address = _actions;
     for (uint256 i = 0; i < _actions.length; i++) {
      // check all items before actions[i], does not equal to action[i]
      for (uint256 j = 0; j < i; j++) {
        require(_actions[i] != _actions[j], "duplicated action");
      }
      actions.push(_actions[i]);
    }
   }
// need helpm for logic to find if 5% of total left in vault
   function rebalance() external returns (bool) {
     //Some logic to implement rebalance from strategy to buffer to keep 5%
     //check buffer > 5%
     uint buffer = (balanceOf(address(this))+ balanceOf(address(strategyAddr))* 0.05);
     UNDERLYING.balanceOf(address(this)) > buffer;) {
      // if true, then rebalance
      // if false, then do nothing
   }

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /** 
        Get the exchange rate between shares and underlying tokens.
    */

    function getStrategyCount() internal view returns (uint256) {
      //some logic to query max strategies for contract and their balance
    }
    function getRollover() external view returns (uint256) {
      // some logic to check if strategy has rolled over
    }

    function exchangeRate() internal view returns (uint256) {
        uint256 cTokenSupply = totalSupply;

        if (cTokenSupply == 0) return BASE_UNIT;

        return UNDERLYING.balanceOf(address(this)).fdiv(cTokenSupply, BASE_UNIT);
    }

    /** 
      @notice The underlying token the Vault accepts.
      @return the ERC20 underlying implementation address.
    */
    function underlying() public view virtual override returns (ERC20) {
        return UNDERLYING;
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
