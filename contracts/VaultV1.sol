// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "./utils/ERC4626.sol";
import "./interfaces/IStrategy.sol";

// An ERC4626 compliant vault that interacts with a strategy address
// BUFFER is the minimun amount of tokens that can be stored in the vault and should
// be compared with bufBal to determine if the vault neeed topup
contract VaultV1 is ERC4626, Ownable {
    using SafeTransferLib for ERC20;

    //the underlying token the vault accepts
    ERC20 public immutable underlying;
    //the strategy address
    IStrategy public strategy;

    // Withdraw locking params
    mapping(address => uint256) public requestedWithdraws;
    mapping(address => uint256) public unlockTime;
    uint256 public withdrawWindow = 24 hours;

    constructor(ERC20 _underlying, address _strategy) ERC4626(_underlying, "TracerVault", "TVLT") {
        underlying = ERC20(_underlying);
        strategy = IStrategy(_strategy);
    }

    function totalAssets() public view override returns (uint256) {
        // account for balances outstanding in bot/strategy, check balances
        return underlying.balanceOf(address(this)) + strategy.value();
    }

    //sets the strategy address to send funds
    //Funds get sent to strategy address(controlled by bot)
    function setStrategy(address _strategy) public onlyOwner {
        require(strategy.withdrawable() == 0 && strategy.value() == 0, "strategy still active");
        strategy = IStrategy(_strategy);
    }

    //sends funds from the vault to the strategy address
    function afterDeposit(uint256 amount) internal virtual override {
        underlying.safeTransfer(address(strategy), amount);
    }

    /**
     * @notice called before the actual withdraw is executed as part of the vault
     * @dev pulls as many funds from the strategy as possible. If not enough funds are on hand, will revert.
     * @dev the withdrawer must have requested to withdraw 24 hours before withdrawing
     */
    function beforeWithdraw(uint256 amount) internal virtual override {
        // require the user has atleast this much amount pending for withdraw
        // require the users unlock time is in the past
        require(
            requestedWithdraws[msg.sender] >= amount && unlockTime[msg.sender] <= block.timestamp,
            "withdraw locked"
        );

        // all funds are stored in strategy. See how much can be pulled
        if (strategy.withdrawable() < amount) {
            // we don't have enough funds
            revert("not enough funds in vault");
        }

        // pull funds from strategy so they can be returned to the user
        strategy.withdraw(amount);

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
        require(requestedWithdraws[msg.sender] == 0, "Already requested withdraw");
        uint256 shares = previewDeposit(amount);
        require(shares <= balanceOf[msg.sender], "insufficient shares");
        // increment the amount that has been requested
        requestedWithdraws[msg.sender] += amount;
        // extend the withdraw period 24 hours
        unlockTime[msg.sender] = block.timestamp + withdrawWindow;

        // alert the strategy of the pending withdraw
        strategy.requestWithdraw(amount);
    }
}
