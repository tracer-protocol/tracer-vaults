// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "@rari-capital/solmate/src/utils/FixedPointMathLib.sol";
import "./interfaces/IERC4626.sol";
import "./interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Vault is ERC20("Tracer Vault Token", "TVT", 18), IERC4626, Ownable {
    using SafeTransferLib for ERC20;
    using FixedPointMathLib for uint256;

    ERC20 public immutable UNDERLYING;
    uint256 public BASE_UNIT;

    // strategy variables
    address[] public strategies;
    uint256[] public percentAllocations;

    constructor(
        address _underlying,
        uint256 baseUnit,
        address[] memory _strategies,
        uint256[] memory _percentAllocations
    ) {
        UNDERLYING = ERC20(_underlying);
        BASE_UNIT = baseUnit;

        require(_strategies.length == _percentAllocations.length, "LEN_MISMATCH");

        // add in base strategies
        for (uint256 i = 0; i < _strategies.length; i++) {
            // check all items before actions[i], does not equal to action[i]
            for (uint256 j = 0; j < i; j++) {
                require(_strategies[i] != _strategies[j], "DUP_STRAT");
            }
            strategies.push(_strategies[i]);
        }

        // ensure percent sum holds
        uint256 sumPercent = 0;
        for (uint256 j = 0; j < _percentAllocations.length; j++) {
            uint256 percent = _percentAllocations[j];
            sumPercent += percent;
            percentAllocations.push(percent);
        }
        require(sumPercent <= BASE_UNIT, "PERC_SUM_MAX");
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
        // distribute funds to the strategies
        distributeFunds();
    }

    /**
      @notice Withdraw a specific amount of underlying tokens.
      @param to The address to receive underlying corresponding to the withdrawal.
      @param underlyingAmount The amount of the underlying token to withdraw.
      @return shares The shares in the vault burned from sender
    */
    function withdraw(address to, uint256 underlyingAmount) public override returns (uint256) {
        // check how much underlying we have "on hand"
        uint256 startUnderlying = UNDERLYING.balanceOf(address(this));

        // if we have enough, simply pay the user
        if (startUnderlying >= underlyingAmount) {
            console.log("A");
            uint256 shares = underlyingAmount.fdiv(exchangeRate(), BASE_UNIT);
            _burn(msg.sender, shares);
            UNDERLYING.safeTransfer(to, underlyingAmount);
            return shares;
        }

        // can't simply pay out of the current balance, compute outstanding amount
        uint256 outstandingUnderlying = underlyingAmount - startUnderlying;

        // withdraw from the strategies one by one until withdraw is complete
        // or we run out of funds
        uint256 postUnderlying = startUnderlying;
        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategy strategy = IStrategy(strategies[0]);
            strategy.withdraw(outstandingUnderlying);
            postUnderlying = UNDERLYING.balanceOf(address(this));

            if (postUnderlying >= underlyingAmount) {
                console.log("B");
                // have enough to pay, stop withdraw
                uint256 shares = underlyingAmount.fdiv(exchangeRate(), BASE_UNIT);
                _burn(msg.sender, shares);
                UNDERLYING.safeTransfer(to, underlyingAmount);
                return shares;
            } else {
                // must continue to withdraw, figure out excess
                // PREDICATE: outstandingUnderlying >= 0
                outstandingUnderlying = underlyingAmount - postUnderlying;
            }
        }

        console.log("underlying");
        console.logUint(postUnderlying);

        // were not able to withdraw enough to pay the user. Simply pay what is
        // possible for now.
        uint256 er = exchangeRate();
        console.logUint(er);
        uint256 actualShares = postUnderlying.fdiv(exchangeRate(), BASE_UNIT);
        console.log("actual shares");
        console.logUint(actualShares);
        _burn(msg.sender, actualShares);
        UNDERLYING.safeTransfer(to, postUnderlying);
        return actualShares;
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
        // todo
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
        // todo
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
        // todo
        value = shareAmount.fdiv(exchangeRate(), BASE_UNIT);

        _burn(from, value);

        UNDERLYING.safeTransfer(to, shareAmount);
    }

    /*///////////////////////////////////////////////////////////////
                    Tracer Custom Mutable Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Distributes funds to strategies
     */
    function distributeFunds() internal {
        uint256 totalBalance = totalHoldings();

        // keep track of total percentage to make sure we're summing up to 100%
        uint256 sumPercentage;
        for (uint8 i = 0; i < strategies.length; i++) {
            uint256 percent = percentAllocations[i];
            sumPercentage += percent;
            require(sumPercentage <= BASE_UNIT, "PERCENTAGE_SUM_EXCEED_MAX");
            uint256 newAmount = (totalBalance * percent) / BASE_UNIT;

            if (newAmount > 0) {
                UNDERLYING.safeTransfer(strategies[i], newAmount);
            }
        }
    }

    function updatePercentAllocations(uint256[] memory _newPercents) public onlyOwner {
        delete percentAllocations;
        require(_newPercents.length == strategies.length, "LEN_MISMATCH");
        uint256 sumPercent = 0;
        for (uint256 j = 0; j < _newPercents.length; j++) {
            uint256 percent = _newPercents[j];
            sumPercent += percent;
            percentAllocations.push(percent);
        }
        require(sumPercent <= BASE_UNIT, "PERC_SUM_MAX");
    }

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice returns the exchange rate in underlying per share of vault
     * @dev this relies on the expected value held by strategies. Until profit
     * is harvested this may be inaccurate.
     */
    function exchangeRate() internal view returns (uint256) {
        uint256 cTokenSupply = totalSupply;

        if (cTokenSupply == 0) return BASE_UNIT;

        // CAUTION: the exchange rate depends on the ratio of expected outstanding
        // tokens to the current cToken supply. This may mean users get a worse or
        // better exchange rate depending on the state of each strategy

        return totalHoldings().fdiv(cTokenSupply, BASE_UNIT);
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
      @return totalUnderlyingHeld The total amount of underlying tokens the Vault and
      * its strategies are holding.
    */
    function totalHoldings() public view virtual override returns (uint256) {
        uint256 strategyValueSum;
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 value = IStrategy(strategies[i]).value();
            strategyValueSum += value;
        }

        // the amount of estimated capital held by the vault
        return UNDERLYING.balanceOf(address(this)) + strategyValueSum;
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
