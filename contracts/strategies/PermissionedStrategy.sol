pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract PermissionedStrategy is IStrategy, AccessControl {
    // target perpetual pool and cached params
    address public immutable POOL;
    IERC20 public immutable POOL_SHORT_TOKEN; //todo: is this needed?
    address public immutable VAULT;

    // vault collateral asset
    IERC20 public immutable VAULT_ASSET; //eg DAI in a ETH/USD+DAI pool

    // strategy current state
    // total outstanding debt owed by all addrsses per asset type
    mapping(address => uint256) public totalDebt;
    // amount of outstanding debt per address per address
    // address => asset => total debt
    mapping(address => mapping(address => uint256)) public debts;

    // access control
    bytes32 public constant WHITELISTER = keccak256("WHITELISTER_ROLE");
    mapping(address => bool) public whitelist;
    mapping(address => bool) public assetWhitelist;

    // events
    event FUNDS_REQUEST(uint256 amount, address collateral);

    constructor(
        address pool,
        address poolShortToken,
        address vaultAsset,
        address _vault
    ) {
        // whitelist default assets
        setAssetWhitelist(poolShortToken, true);
        setAssetWhitelist(vaultAsset, true);

        // make contract deployer the default admin
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // cache state
        POOL = pool;
        POOL_SHORT_TOKEN = IERC20(poolShortToken);
        VAULT_ASSET = IERC20(vaultAsset);
        // todo validate above poolShortToken and vaultAsset
        VAULT = _vault;
    }

    function value() external view override returns (uint256) {
        // collateral on hand + outstanding debt from external contracts denoted in the vault asset
        // todo -> we may need to account for short tokens that are currently with any bot
        return VAULT_ASSET.balanceOf(address(this)) + totalDebt[address(VAULT_ASSET)];
    }

    /**
     * @notice triggers a rebalance on the strategy.
     */
    function rebalance() external override {
        //TODO I don't think this does anything since control is given to whitelisted addresses
    }

    /**
     * @notice returns the maximum amount of underlying that can be safely withdrawn
     * from this strategy instantly.
     */
    function withdrawable() external view override returns (uint256) {
        return VAULT_ASSET.balanceOf(address(this));
    }

    /**
     * @notice withdraws a maximum of amount underlying from the strategy. Only callable
     * by the vault.
     * @param amount the amount of underlying tokens request to be withdrawn.
     */
    function withdraw(uint256 amount) external override {
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
        VAULT_ASSET.transfer(VAULT, amountToTransfer);
    }

    /*///////////////////////////////////////////////////////////////
                            External Access Functions
    //////////////////////////////////////////////////////////////*/
    /**
     * @notice Allows a whitelisted address to pull colalteral from the contract
     * @dev Updates debt accounting. Ensures msg.sender is whitelisted and
     * asset is whitelisted
     * @param amount the amount being requested
     * @param asset the asset being pulled
     */
    function pullAsset(uint256 amount, address asset) public onlyWhitelisted(asset) {
        IERC20 _asset = IERC20(asset);
        require(amount <= _asset.balanceOf(address(this)), "INSUFFICIENT FUNDS");
        // update accounting
        debts[msg.sender][asset] += amount;
        totalDebt[asset] += amount;
        _asset.transfer(msg.sender, amount);
    }

    /**
     * @notice Allows a whitelisted address to return collateral
     * @dev the whitelisted address must have approved this contract as a spender of
     * VAULT_COLLATERAL before this function can be used. Ensures msg.sender is
     * whitelisted and asset is whitelisted
     * @param amount the amount of debt being repaid
     * @param asset the asset being returned
     */
    function returnCollateral(uint256 amount, address asset) public onlyWhitelisted(asset) {
        // update accounting
        uint256 _senderDebt = debts[msg.sender][asset];
        uint256 _totalDebt = totalDebt[asset];

        // validate if debt is paid off for msg.sender
        if (amount >= _senderDebt) {
            debts[msg.sender][asset] = 0;
        }

        // validate if debt is paid off for the entire pool
        if (amount >= _totalDebt) {
            totalDebt[asset] = 0;
        }

        IERC20(asset).transferFrom(msg.sender, address(this), amount);
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

    /**
     * @notice Sets a certain asset addresses permissions on the whitelist.
     * @dev setting this to true will allow that asset to be pulled and pushed from this vault
     * @param asset the address being whitelisted
     * @param permission whether to grant it access or not
     */
    function setAssetWhitelist(address asset, bool permission) public onlyRole(WHITELISTER) {
        assetWhitelist[asset] = permission;
    }

    /**
     * @notice modifier that checks both the sending address and the asset
     */
    modifier onlyWhitelisted(address asset) {
        require(whitelist[msg.sender], "SENDER NOT WL");
        require(assetWhitelist[asset], "ASSET NOT WL");
        _;
    }
}
