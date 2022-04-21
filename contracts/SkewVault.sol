// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import {ERC20, ERC4626} from "../lib/solmate/src/mixins/ERC4626.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "./LongFarmer.sol";

/**
 * @notice An ERC4626 compliant vault for farming long sided skew against tracer perpetual pools
 * @dev inherets LongFarmer, which contains skew specific logic
 * @dev vault accepts usdc deposits and withdrawals from whitelisted users
 */
contract SkewVault is ERC4626, Ownable, LongFarmer {
    using SafeTransferLib for ERC20;

    // the underlying token the vault accepts
    ERC20 public immutable underlying;

    mapping(address => bool) public whiteList;

    constructor(ERC20 _underlying) ERC4626(_underlying, "TracerVault", "TVLT") {
        underlying = ERC20(_underlying);
    }

    function totalAssets() public view override returns (uint256) {
        uint256 bal = value();
        return underlying.balanceOf(address(this)) + bal;
    }

    function setWhiteList(address _addr, bool status) external onlyOwner {
        whiteList[_addr] = status;
    }

    function afterDeposit(uint256 assets, uint256) internal virtual override onlyWhitelist {
        require(whiteList[msg.sender] == true);
    }

    function beforeWithdraw(uint256 assets, uint256) internal virtual override onlyWhitelist {
        require(whiteList[msg.sender] == true);
    }

    modifier onlyWhitelist() {
        require(whiteList[msg.sender], "only whitelisted addresses can use vault");
        _;
    }
}
