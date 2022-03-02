// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
import "./interfaces/IStrategy.sol";

//important! Importing ERRC4626 from solmate will cause the contract to fail compile
import "./utils/ERC4626.sol";
import "./utils/FixedPointMathLib.sol";

// An ERC4626 compliant vault that interacts with a strategy address
// BUFFER is the minimun amount of tokens that can be stored in the vault and should
// be compared with bufBal to determine if the vault neeed topup
// TOP_UP indicates if funds are needed from bot to facilitate a large withdrawal
contract VaultV1 is ERC4626, Ownable {
    using SafeTransferLib for ERC20;

    //the underlying token the vault accepts
    ERC20 public immutable UNDERLYING;
    //the strategy address
    IStrategy public STRATEGY;
    //the buffer amount (indicates to bot the minimun amount of tokens that can be stored in the vault)
    uint256 public BUFFER;
    //top up amount (adjusted on large withdrawals)
    uint256 public TOP_UP;
    //Locks vault from withdrawals false = unlocked, true = locked
    bool public LOCKED;

    constructor(ERC20 underlying, address strategy) ERC4626(underlying, "TracerVault", "TVLT") {
        UNDERLYING = ERC20(underlying);
        STRATEGY = IStrategy(strategy);
    }

    function totalAssets() public view override returns (uint256) {
        // account for balances outstanding in bot/strategy, check balances
        return UNDERLYING.balanceOf(address(this)) + STRATEGY.value();
    }

    //Sets the withdraw lock
    function setLock(bool _lock) public onlyOwner {
        LOCKED = _lock;
    }

    //sets the strategy address to send funds
    //Funds get sent to strategy address(controlled by bot)
    function setStrategy(address strategy) public onlyOwner returns (bool) {
        STRATEGY = IStrategy(strategy);
        return true;
    }

    //sets the buffer amount to leave in vault
    //Bot queries vault Balance and compares to buffer amount
    function setBuffer(uint256 buffer) public onlyOwner returns (bool) {
        BUFFER = buffer;
        return true;
    }

    //returns current balance of underlying in vault (represents buffer amount)
    function bufBalance() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }

    //sends funds from the vault to the strategy address
    function afterDeposit(uint256 amount) internal virtual override {
        //todo logic to distribute funds to Strategy (for bot)
        UNDERLYING.safeTransfer(address(STRATEGY), amount);
    }

    /**
     * @notice called before the actual withdraw is executed as part of the vault
     * @dev pulls as many funds from the strategy as possible.
     * @dev checks locked state, if locked, revert
     */
    function beforeWithdraw(uint256 amount) internal virtual override {
        //require vault is not locked, else revert
        require(!LOCKED, "Vault is locked");
        // check how much underlying we have "on hand"
        uint256 startUnderlying = UNDERLYING.balanceOf(address(this));

        if (startUnderlying < amount && STRATEGY.withdrawable() >= amount) {
            // not enough on hand but enough in the strategy. withdraw
            STRATEGY.withdraw(amount);
        } else if (startUnderlying < amount) {
            // not enough on hand. Not enough in strategy. Update funds required from bot
            STRATEGY.withdraw(amount);
            uint256 newUnderlying = UNDERLYING.balanceOf(address(this));
            TOP_UP = amount - newUnderlying;
        }
    }
}
