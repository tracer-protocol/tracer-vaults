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
      @param amount The amount of the underlying token to deposit.
      @return shares The shares in the vault credited to `to`
    */
    function deposit(uint256 amount, address to) public override returns (uint256) {
        return _deposit(amount, to);
    }

    /**
      @notice Mint an exact amount of shares for a variable amount of underlying tokens.
      @param shares The amount of vault shares to mint.
      @param to The address to receive shares corresponding to the mint.
      @return amount The amount of the underlying tokens deposited from the mint call.
    */
    function mint(uint256 shares, address to) public override returns (uint256) {
        // convert shares to underlying amount
        uint256 amount = shares.fmul(exchangeRate(), BASE_UNIT);
        return _deposit(amount, to);
    }

    /**
     * @notice Internal deposit function
     * @param amount of underlying tokens being deposited
     * @param to the address receiving the shares for this deposit
     */
    function _deposit(uint256 amount, address to) internal returns (uint256) {
        uint256 shares = amount.fdiv(exchangeRate(), BASE_UNIT);
        // mint shares and pull in tokens
        _mint(to, shares);
        UNDERLYING.safeTransferFrom(msg.sender, address(this), amount);

        // distribute funds to the strategies
        distributeFunds(amount);
        return shares;
    }

    /**
      @notice Withdraw a specific amount of underlying tokens.
      @param amount The amount of the underlying token to withdraw.
      @param to The address to receive underlying corresponding to the withdrawal.
      @param from The address to burn shares from corresponding to the withdrawal.
      @return shares The shares in the vault burned from sender
    */
    function withdraw(
        uint256 amount,
        address to,
        address from
    ) public override returns (uint256) {
        // todo any public validation goes here
        return _withdraw(amount, to, from);
    }

    /**
      @notice Redeem a specific amount of shares for underlying tokens.
      @param from The address to burn shares from corresponding to the redemption.
      @param to The address to receive underlying corresponding to the redemption.
      @param shares The amount of shares to redeem.
      @return value The underlying amount transferred to `to`.
    */
    function redeem(
        uint256 shares,
        address from,
        address to
    ) public override returns (uint256) {
        // todo
        require(this.balanceOf(msg.sender) >= shares, "INSUFFICIENT_SHARES");
        uint256 amount = shares.fmul(exchangeRate(), BASE_UNIT);
        return _withdraw(amount, from, to);
    }

    /**
     * @notice Internal withdraw function
     * @param amount of underlying tokens being withdraw
     * @param from the address sending the withdraw request
     * @param to the address receiving the withdrawn funds
     */
    function _withdraw(
        uint256 amount,
        address from,
        address to
    ) internal returns (uint256) {
        uint256 shares = amount.fdiv(exchangeRate(), BASE_UNIT);
        require(this.balanceOf(msg.sender) >= shares, "INSUFFICIENT_SHARES");
        // check how much underlying we have "on hand"
        uint256 startUnderlying = UNDERLYING.balanceOf(address(this));

        // if we have enough, simply pay the user
        if (startUnderlying >= amount) {
            _burn(msg.sender, shares);
            UNDERLYING.safeTransfer(to, amount);
            return shares;
        }

        // can't simply pay out of the current balance, compute outstanding amount
        uint256 outstandingUnderlying = amount - startUnderlying;

        // withdraw from the strategies one by one until withdraw is complete
        // or we run out of funds
        uint256 postUnderlying = startUnderlying;
        for (uint256 i = 0; i < strategies.length; i++) {
            IStrategy strategy = IStrategy(strategies[0]);
            strategy.withdraw(outstandingUnderlying);
            postUnderlying = UNDERLYING.balanceOf(address(this));

            if (postUnderlying >= amount) {
                // have enough to pay, stop withdraw
                _burn(msg.sender, shares);
                UNDERLYING.safeTransfer(to, amount);
                return shares;
            } else {
                // must continue to withdraw, figure out excess
                // PREDICATE: outstandingUnderlying >= 0
                outstandingUnderlying = amount - postUnderlying;
            }
        }

        // were not able to withdraw enough to pay the user. Simply pay what is
        // possible for now.
        uint256 actualShares = postUnderlying.fdiv(exchangeRate(), BASE_UNIT);
        _burn(msg.sender, actualShares);
        UNDERLYING.safeTransfer(to, postUnderlying);
        return actualShares;
    }

    /*///////////////////////////////////////////////////////////////
                    Tracer Custom Mutable Functions
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Distributes funds to strategies
     */
    function distributeFunds(uint256 _amount) internal {
        require(_amount > 0 && _amount <= UNDERLYING.balanceOf(address(this)), "BALANCE_OUT_OF_RANGE");

        // keep track of total percentage to make sure we're summing up to 100%
        uint256 sumPercentage;
        for (uint8 i = 0; i < strategies.length; i++) {
            uint256 percent = percentAllocations[i];
            sumPercentage += percent;
            require(sumPercentage <= BASE_UNIT, "PERCENTAGE_SUM_EXCEED_MAX");
            uint256 transferAmount = (_amount * percent) / BASE_UNIT;

            if (transferAmount > 0) {
                UNDERLYING.safeTransfer(strategies[i], transferAmount);
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
    function exchangeRate() public view override returns (uint256) {
        uint256 cTokenSupply = totalSupply;

        if (cTokenSupply == 0) return BASE_UNIT;

        // CAUTION: the exchange rate depends on the ratio of expected outstanding
        // tokens to the current cToken supply. This may mean users get a worse or
        // better exchange rate depending on the state of each strategy
        return totalAssets().fdiv(cTokenSupply, BASE_UNIT);
    }

    /** 
      @notice The underlying token the Vault accepts.
      @return the ERC20 underlying implementation address.
    */
    function asset() public view override returns (address) {
        return address(UNDERLYING);
    }

    /** 
      @notice Returns a user's Vault balance in underlying tokens.
      @param user The user to get the underlying balance of.
      @return amount The user's Vault balance in underlying tokens.
    */
    function assetsOf(address user) public view override returns (uint256) {
        return balanceOf[user].fmul(exchangeRate(), BASE_UNIT);
    }

    /** 
      @notice Calculates the total amount of underlying tokens the Vault holds including in strategies.
      * @dev CAUTION. Do not confuse this with the amount of underlying tokens being held in the vault. This
      * function takes into account the balance of strategies as well.
      @return totalUnderlyingHeld The total amount of underlying tokens the vault and
      * its strategies are holding.
    */
    function totalAssets() public view virtual override returns (uint256) {
        uint256 strategyValueSum;
        for (uint256 i = 0; i < strategies.length; i++) {
            uint256 value = IStrategy(strategies[i]).value();
            strategyValueSum += value;
        }

        // the amount of estimated capital held by the vault
        return UNDERLYING.balanceOf(address(this)) + strategyValueSum;
    }

    /**
      @notice Returns the amount of vault tokens that would be obtained if depositing a given amount of underlying tokens in a `deposit` call.
      @param amount the input amount of underlying tokens
      @return shares the corresponding amount of shares out from a deposit call with `amount` in
     */
    function previewDeposit(uint256 amount) public view override returns (uint256) {
        // todo
        return 0;
    }

    /**
      @notice Returns the amount of underlying tokens that would be deposited if minting a given amount of shares in a `mint` call.
      @param shares the amount of shares from a mint call.
      @return amount the amount of underlying tokens corresponding to the mint call
     */
    function previewMint(uint256 shares) public view override returns (uint256) {
        // todo
        return 0;
    }

    /**
      @notice Returns the amount of vault tokens that would be burned if withdrawing a given amount of underlying tokens in a `withdraw` call.
      @param amount the input amount of underlying tokens
      @return shares the corresponding amount of shares out from a withdraw call with `amount` in
     */
    function previewWithdraw(uint256 amount) public view override returns (uint256) {
        // todo
        return 0;
    }

    /**
      @notice Returns the amount of underlying tokens that would be obtained if redeeming a given amount of shares in a `redeem` call.
      @param shares the amount of shares from a redeem call.
      @return amount the amount of underlying tokens corresponding to the redeem call
     */
    function previewRedeem(uint256 shares) public view override returns (uint256) {
        // todo
        return 0;
    }
}
