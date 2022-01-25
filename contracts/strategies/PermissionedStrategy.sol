pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
contract PermissionedStrategy is IStrategy, AccessControl {

    // target perpetual pool and cached params
    address public POOL;
    IERC20 public POOL_SHORT_TOKEN;
    address public VAULT;

    // vault collateral asset
    IERC20 public VAULT_ASSET; //eg DAI in a ETH/USD+DAI pool

    // strategy current state
    // total outstanding debt owed by all addrsses
    uint256 public totalDebt;
    // amount of outstanding debt per address
    mapping(address => uint256) public debts;

    // access control
    bytes32 public constant WHITELISTER = keccak256("WHITELISTER_ROLE");
    mapping(address => bool) public whitelist;

    // events
    event FUNDS_REQUEST(uint256 amount, address collateral);

    constructor(address poolShortToken, address vaultAsset, address _vault) {
        // make contract deployer the default admin
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        POOL_SHORT_TOKEN = IERC20(poolShortToken);
        VAULT_ASSET = IERC20(vaultAsset);
        // todo validate above poolShortToken and vaultAsset
        VAULT = _vault;
    }

    function value() external view returns(uint256) {
        // todo value our assets
        // collateral on hand + outstanding debt from external contracts
        return VAULT_ASSET.balanceOf(address(this)) + totalDebt;
    }

    /**
    * @notice triggers a rebalance on the strategy.
    */
    function rebalance() external {
        //TODO I don't think this does anything since control is given to whitelisted addresses
    }

    /**
    * @notice returns the maximum amount of underlying that can be safely withdrawn
    * from this strategy instantly.
    */
    function withdrawable() external view returns(uint256) {
        return VAULT_ASSET.balanceOf(address(this));
    }

    /**
    * @notice withdraws a maximum of amount underlying from the strategy. Only callable
    * by the vault.
    * @param amount the amount of underlying tokens request to be withdrawn.
    */
    function withdraw(uint256 amount) external {
        // 1. Send to vault as much liquid VAULT_COLLATERAL as posssible
        uint256 currentBalance = VAULT_ASSET.balanceOf(address(this));
        uint256 amountToTransfer = amount >= currentBalance ? currentBalance : amount; 
        VAULT_ASSET.transfer(VAULT, amountToTransfer);
        // 2. Emit event for whitelisters to watch and return capital
        if (amount > currentBalance) {
            // we were only able to send part of the amount
            uint256 outstandingAmount = amount - currentBalance;
            emit FUNDS_REQUEST(outstandingAmount, address(VAULT_ASSET));
        }
    }
    
    /*///////////////////////////////////////////////////////////////
                            External Access Functions
    //////////////////////////////////////////////////////////////*/
    /**
    * @notice Allows a whitelisted address to pull colalteral from the contract
    * @dev Updates debt accounting
    * @param amount the amount being requested
    */
    function pullCollateral(uint256 amount) onlyWhitelisted() public {
        require(amount <= VAULT_ASSET.balanceOf(address(this)), "INSUFFICIENT FUNDS");
        // update accounting
        debts[msg.sender] += amount;
        totalDebt += amount;
        VAULT_ASSET.transfer(msg.sender, amount);
    }

    /**
    * @notice Allows a whitelisted address to return collateral
    * @dev the whitelisted address must have approved this contract as a spender of
    * VAULT_COLLATERAL before this function can be used
    * @param amount the amount of debt being repaid
    */
    function returnCollateral(uint256 amount) onlyWhitelisted() public {
        VAULT_ASSET.transferFrom(msg.sender, address(this), amount);
        // update accounting
        uint256 _senderDebt = debts[msg.sender];
        uint256 _totalDebt = totalDebt;
        if (amount >= _senderDebt) {
            // this user has no debt
            debts[msg.sender] = 0;
        } else if (amount >= _totalDebt) {
            // there is no more outstanding debt
            totalDebt = 0;
        }
    }

    /*///////////////////////////////////////////////////////////////
                            Access Control Functions
    //////////////////////////////////////////////////////////////*/
    
    /**
    * @notice Sets a certain addresses permissions on the whitelist.
    * @dev setting this to true will allow the address to pull capital from this contract
    * @param whitelisted the address being whitelisted
    * @param permission whether to grant it access or not
    */
    function setWhitelist(address whitelisted, bool permission) public onlyRole(WHITELISTER) {
        whitelist[whitelisted] = permission; 
    }

    modifier onlyWhitelisted {
        require(whitelist[msg.sender], "NOT WHITELISTED");
        _;
    }
}