// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

//todo fix import paths to solmate
import "@rari-capital/solmate/src/tokens/ERC20.sol";
import "@rari-capital/solmate/src/utils/SafeTransferLib.sol";
//important! Importing this library from solmate will cause the contract to fail compile
import "./utils/ERC4626.sol";
import "./utils/FixedPointMathLib.sol";


// An ERC4626 compliant vault that interacts with a strategy address 
// BUFFER is the minimun amount of tokens that can be stored in the vault and should 
// be compared with bufBal to determine if the vault neeed topup
// TOP_UP indicates if funds are needed from bot to facilitate a large withdrawal
abstract contract EVault is ERC4626 {
    using SafeTransferLib for ERC20;
    //lets track balances for now
    mapping(address => uint256) balances;
    address payable public owner;

    //the underlying token the vault accepts
    ERC20 public immutable UNDERLYING;
    //the strategy address
    address public STRATEGY;
    //the buffer amount
    uint256 public BUFFER;
    //top up amount
    uint256 public TOP_UP;
    
    constructor(ERC20 underlying) ERC4626(underlying, "EVault", "EVLT") {
        UNDERLYING = ERC20(underlying);
        owner = payable(msg.sender);
    }

    modifier onlyOwner() {
        require(isOwner());
        _;
    }

    function totalAssets() public view override returns (uint256) {
        // account for balances outstanding in bot/strategy, check balances
        return UNDERLYING.balanceOf(address(this)) + UNDERLYING.balanceOf(address(STRATEGY));
    }

    //sets the strategy address to send funds
    //Funds get sent to strategy address
    function setStrategy(address strategy) internal onlyOwner returns (bool) {
        STRATEGY = strategy;
        return true;
    }
    //sets the buffer amount to leave in vault
    //Bot queries vault Balance and compares to buffer amount
    function setBuffer(uint256 buffer) internal onlyOwner returns (bool) {
        BUFFER = buffer;
        return true;
    }
    function bufBalance() public view returns (uint256) {
        return UNDERLYING.balanceOf(address(this));
    }
    //sends funds from the vault to the strategy address
    function afterDeposit(uint256 amount) internal virtual override {
        //todo logic to distribute funds to Strategy (for bot)
        UNDERLYING.safeTransfer(STRATEGY, amount);
        //increment balance of sender
        balances[msg.sender] += amount;
    }

    //Claims rewards and sends funds from the Harvester to Vault
    function beforeWithdraw(uint256 amount) internal virtual override {
        if(UNDERLYING.balanceOf(address(this)) >= amount){
            UNDERLYING.safeTransfer(STRATEGY, amount);
            //increment balance of sender
            balances[msg.sender] += amount;
            TOP_UP = 0;
        } else {
            //todo throw error
            TOP_UP = amount - UNDERLYING.balanceOf(address(this));
            revert();
        }
        require(UNDERLYING.balanceOf(address(this)) >= amount, "Insufficient funds in vault");
        previewWithdraw(amount);
        balances[msg.sender] -= amount;
    }
    function isOwner() public view returns (bool) {
        return msg.sender == owner;
    }
}
