pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

//Just another strategy idea to test our current assumptions
//Maintains accounting records of inflows and outflows in a struct
abstract contract StrategyExperimental is IStrategy {
    //strategist inflow/outflow records
    struct Target {
        address pool;
        uint256 Amount;
    }

    IERC20 public immutable VAULT_ASSET;
    address public owner;
    address public pool;
    address public strategist;
    address public vault;
    uint256 public totalDebt;

    //asset whitelist
    mapping(address => bool) AssetWhitelist;

    //TimeStamped Records IN
    mapping(uint256 => Target) TSRI;
    //timstamped Records OUT
    mapping(uint256 => Target) TSRO;

    constructor(
        address _owner,
        address _strategist,
        IERC20 _vaultAsset
    ) {
        owner = _owner;
        strategist = _strategist;
        VAULT_ASSET = _vaultAsset;
    }

    //Sets the vault address
    function setVault(address _vault) public {
        require(msg.sender == owner);
        vault = _vault;
    }

    //Returns strategy value + outstanding debt
    function value() public view override returns (uint256) {
        return VAULT_ASSET.balanceOf(address(this)) + totalDebt;
    }

    //Returns funds held in this strategy
    function withdrawable() external view override returns (uint256) {
        return VAULT_ASSET.balanceOf(address(this));
    }

    //facilitates withdrawal of funds from strategy to vault
    function withdraw(uint256 amount) external override {
        require(msg.sender == vault, "only vault can withdraw");
        // 1. Compute amount available to be transfered. Cap at balance of the strategy
        uint256 currentBalance = VAULT_ASSET.balanceOf(address(this));
        uint256 amountToTransfer = amount >= currentBalance ? currentBalance : amount;

        // 2. Emit event for whitelisters to watch and return capital
        if (amount > currentBalance) {
            // emit amount of outstanding withdraw that is being requested
            uint256 outstandingAmount = amount - currentBalance;
            emit FUNDS_REQUEST(outstandingAmount, address(VAULT_ASSET));
        }

        // 3. perform transfer
        VAULT_ASSET.transfer(vault, amountToTransfer);
    }

    //Allows the strategist to transfer funds from strategy
    function pullAsset(uint256 amount, address _pool) public {
        require(msg.sender == strategist);
        require(VAULT_ASSET.balanceOf(address(this)) >= amount, "Not enough balance");
        VAULT_ASSET.transfer(address(this), amount);
        TSRO[block.timestamp].Amount = amount;
        TSRO[block.timestamp].pool = _pool;
        totalDebt += amount;
        emit FundsPulled(_pool, amount);
    }

    //Logic for strategist to return funds to vault accounting for debts
    function returnAsset(
        uint256 amount,
        address asset,
        address _pool
    ) public onlyStrategist {
        if (amount >= totalDebt) {
            totalDebt = 0;
        }
        if (amount < totalDebt) {
            totalDebt -= amount;
        }
        //account for inflows
        TSRI[block.timestamp].Amount = amount;
        TSRI[block.timestamp].pool = _pool;
        IERC20(asset).transferFrom(msg.sender, address(this), amount);
        emit FundsReturn(_pool, amount);
    }

    //Events
    event FundsPulled(address _pool, uint256 _amount);
    event FundsReturn(address indexed pool, uint256 amount);
    event FUNDS_REQUEST(uint256 amount, address collateral);

    //setters and modifiers
    function setAssetWhitelist(address asset, bool permission) public {
        require(msg.sender == owner);
        AssetWhitelist[asset] = permission;
    }

    modifier onlyStrategist() {
        require(msg.sender == strategist, "SENDER_NOT_STRATEGIST");
        _;
    }
}
