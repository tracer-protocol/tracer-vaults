// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {onlyAdmin} from "openzeppelin-solidity/test/helpers/onlyAdmin";

import {IERC4626} from "../../interfaces/IERC4626.sol";

contract MockVault is ERC20("Mock cERC20 Strategy", "cERC20", 18) {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    /*///////////////////////////////////////////////////////////////
                                Immutables
    //////////////////////////////////////////////////////////////*/

    ERC20 immutable UNDERLYING;
    uint256 immutable BASE_UNIT;
	

    mapping (address => bool) public Strategies;

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
		//Check if requested withdraw amount is above vaults underlying balance
		if (underlyingAmount > balanceOfUnderlying(address(this))) {
		uint diff = underlyingAmount - balanceOfUnderlying(address(this));
		//withdraw differece from strategy to fund withdrawal
		strategy.withdraw(diff);
        _burn(msg.sender, shares);
		UNDERLYING.safeTransfer(to, underlyingAmount);
		bufferUpKeep()
		} else {
			_burn(msg.sender, shares);
			UNDERLYING.safeTransfer(to, underlyingAmount);
		}

        // UNDERLYING.safeTransfer(to, underlyingAmount);
		// //custom logic to pull from strategy if withdrawal caused vault to go below safeVaultBalance
		// if (balanceOf(address(this) < safeVaultBalance())) {
		// 	bufferUpKeep()
		// } else {

		// }
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
	function setApprovedStrategy(address strategy) internal onlyAdmin returns (bool) {
	Strategies[strategy]=true;
	return true;
	}
    //removes an approved strategy
    function removeApprovedStrategy(address strategy) internal onlyAdmin returns (bool) {
      Strategies[strategy]=false;
    }
	/// Old Function to deposit into strategy contract
	// function depositStrategy(address strategy, uint256 amount) internal returns (uint256 balance) {
    //     if (Strategies[strategy] = true) {
    //      strategy.deposit(amount);
    //      return balance;
    //      strategy.rebalance()
    //     } else {
    //       revert();
	// 	}
	// } 
	function depositStrategy(address strategy, uint256 amount) internal returns (uint256 balance) {
		if (Strategies[strategy] = true) {
         strategy.deposit(amount);
         strategy.rebalance()
			return balance;
        } else {
          revert();
		}
	} 

    //Function to withdraw from Strategy
    function withdrawFromStrategy(address strategy, uint256 amount) internal returns (uint256 balance) {
         uint preBalance = balanceOf(address(this));
         withdraw(strategy, amount);
         // Checks if balance prior to withdraw is equal to balance after withdraw + amount
        if (preBalance + amount = balanceOf(address(this))) {
            return balanceOf(address(this));
        } else {
            strategy.rebalance();
        }
    }
      //Function to rebalance Strategy to approach buffer
   function bufferUpKeep() external returns (bool) {
     //calls strategy for buffer funds
	 //TODO: how to bulk rebalance strategies, is this possible?
     Strategies.rebalance()
   }


    /*///////////////////////////////////////////////////////////////
                    Tracer Custom View Functions
    //////////////////////////////////////////////////////////////*/
    // The Vault contracts buffer balance should be above 0.05 of total
    function buffer() internal view returns (uint256) {
        return (balanceOf(address(this))+ balanceOf(address(strategyAddr)))* 0.05;
    }
	function safeVaultBalance() view returns (uint256) {
		return (0.025 * (balanceOf(address.(this)) + balanceOf(address(strategy))));
	}
	
    // Checks strategy is in mapping
    function isStrategy() internal view returns (uint256) {
      //some logic to query max strategies for contract and their balance
    }
    // Checks when next rollover
    function getRollover() external view returns (uint256) {
      // some logic to check if strategy has rolled over
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
