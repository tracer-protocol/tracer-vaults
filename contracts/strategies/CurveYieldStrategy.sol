pragma solidity ^0.8.0;

import "../interfaces/IStrategy.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/**
* Curve Yield Strategy
* inspired by Vovo Finance
* Steps:
*   Deposits vault asset into curve pool
*   Farms curve yield and uses yield to go long or short perpetual pool
*   Continously farms yield and reinvests in pool tokens
*   No liquidations means you are only reinvesting yield
*/

contract PermissionedStrategy is IStrategy, AccessControl {
    // target perpetual pool and cached params
    address public immutable POOL;
    address public immutable VAULT;
    IERC20 public immutable POOL_TOKEN; // long or short depending on if vault is long or short

    // vault collateral asset
    IERC20 public immutable VAULT_ASSET; //eg DAI in a ETH/USD+DAI pool

    // curve

    // withdraw logic
    uint256 public totalRequestedWithdraws;

    // events
    event FUNDS_REQUEST(uint256 amount, address collateral);

    constructor(
        address pool,
        address poolToken,
        address vaultAsset,
        address _vault
    ) {
        // setup roles
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);

        // cache state
        POOL = pool;
        POOL_TOKEN = IERC20(poolToken);
        VAULT_ASSET = IERC20(vaultAsset);
        // todo validate above poolShortToken and vaultAsset
        VAULT = _vault;
    }

    function value() external view override returns (uint256) {
        // assets in curve + perpetual pool tokens
        return 0;
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
     * @notice allows the vault to notify the strategy of a request to withdraw
     * @param amount the amount being requested to withdraw
     */
    function requestWithdraw(uint256 amount) external override onlyVault {
        totalRequestedWithdraws += amount;
    }

    /**
     * @notice withdraws a maximum of amount underlying from the strategy. Only callable
     * by the vault.
     * @param amount the amount of underlying tokens request to be withdrawn.
     */
    function withdraw(uint256 amount) external override onlyVault {
        // get value without current curve rewards

        // close out perpetual pools position if needed to perform withdraw

        // take fees to the DAO
    }

    /**
     * @notice deposits into the strategy
     * @dev this hook can be used to update and strategy state / deposit into external contracts
     */
    function deposit(uint256 amount) external override onlyVault {
        // deposit funds into curve

        // check curve gauges

        // harvest rewards if needed and open new positions
    }

    /*///////////////////////////////////////////////////////////////
                            Access Control Functions
    //////////////////////////////////////////////////////////////*/

    modifier onlyVault() {
        require(msg.sender == VAULT, "only vault can withdraw");
        _;
    }
}
