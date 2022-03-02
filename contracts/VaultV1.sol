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
contract VaultV1 is ERC4626, Ownable {
    using SafeTransferLib for ERC20;

    //the underlying token the vault accepts
    ERC20 public immutable UNDERLYING;
    //the strategy address
    IStrategy public STRATEGY;
    //the buffer amount (indicates to bot the minimun amount of tokens that can be stored in the vault)
    uint256 public BUFFER;

    // Withdraw locking params
    mapping(address => uint256) public requestedWithdraws;
    mapping(address => uint256) public unlockTime;
    uint256 totalRequestedWithdraws;
    uint256 withdrawWindow = 24 hours;



    constructor(ERC20 underlying, address strategy) ERC4626(underlying, "TracerVault", "TVLT") {
        UNDERLYING = ERC20(underlying);
        STRATEGY = IStrategy(strategy);
    }

    function totalAssets() public view override returns (uint256) {
        // account for balances outstanding in bot/strategy, check balances
        return UNDERLYING.balanceOf(address(this)) + STRATEGY.value();
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
     * @dev pulls as many funds from the strategy as possible. If not enough funds are on hand, will revert.
     * @dev the withdrawer must have requested to withdraw 24 hours before withdrawing
     */
    function beforeWithdraw(uint256 amount) internal virtual override {
        // require the user has atleast this much amount pending for withdraw
        // require the users unlock time is in the past
        require(requestedWithdraws[msg.sender] >= amount && unlockTime[msg.sender] <= block.timestamp, "Vault is locked");

        // check how much underlying we have "on hand"
        uint256 startUnderlying = UNDERLYING.balanceOf(address(this));

        if (startUnderlying < amount && STRATEGY.withdrawable() >= amount) {
            // not enough on hand but enough in the strategy. withdraw
            STRATEGY.withdraw(amount);
        } else if (startUnderlying < amount) {
            // not enough on hand. Not enough in strategy. Revert to be safe.
            revert("not enough funds in vault");
        }

        // update the users requested withdraw status
        requestedWithdraws[msg.sender] = 0;
        unlockTime[msg.sender] = 0;
    }

    /**
    * @notice Lets a user request to withdraw funds.
    * @param amount the amount in terms of underlying asset being requested to withdraw
    * @dev sets the withdraw window to 24 hours
    */
    function requestWithdraw(uint256 amount) public {
        uint256 shares = previewDeposit(amount);
        require(shares <= balanceOf[msg.sender], "insufficient shares");
        // increment the amount that has been requested
        requestedWithdraws[msg.sender] += amount;
        // extend the withdraw period 24 hours
        unlockTime[msg.sender] = block.timestamp + withdrawWindow;
        // increment the total withdraw amount
        totalRequestedWithdraws += amount;
    }
}
