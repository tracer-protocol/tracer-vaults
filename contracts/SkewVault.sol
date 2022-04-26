// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

import {Ownable} from "../lib/openzeppelin-contracts/contracts/access/Ownable.sol";
import {ERC20, ERC4626} from "../lib/solmate/src/mixins/ERC4626.sol";
import {SafeTransferLib} from "../lib/solmate/src/utils/SafeTransferLib.sol";
import "./LongFarmer.sol";

/**
 * @notice An ERC4626 compliant vault for farming long sided skew against tracer perpetual pools
 * @dev inherets LongFarmer, which contains skew specific logic
 * @dev vault accepts usdc deposits and withdrawals from whitelisted users
 */
contract SkewVault is ERC4626, Ownable {
    using SafeTransferLib for ERC20;
    LongFarmer longFarmer;

    // the underlying token the vault accepts
    ERC20 public immutable underlying;

    mapping(address => bool) public whiteList;

    constructor(address _underlying) ERC4626(ERC20(_underlying), "TracerVault", "TVLT") {
        underlying = ERC20(_underlying);
        // longFarmer = new LongFarmer();
        // longFarmer.initialize(pooladdr, _threshold, _committer, _encoder, ERC20(this));
    }

    function totalAssets() public view override returns (uint256) {
        uint256 bal = longFarmer.value();
        uint256 _t = underlying.balanceOf(address(this));
        bal += _t;
        return bal;
    }

    function setWhiteList(address _addr, bool status) external onlyOwner {
        whiteList[_addr] = status;
    }

    function setLongFarmer(address _longFarmer) public onlyOwner {
        longFarmer = LongFarmer(_longFarmer);
        underlying.approve(address(longFarmer), 1e18);
        ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6).allowance(
            address(0xC3d2052479dBC010480Ae16204777C1469CEffC9),
            address(longFarmer)
        );
    }

    function afterDeposit(uint256 assets, uint256 shares) internal virtual override {
        require(whiteList[msg.sender] == true);
        // underlying.safeTransfer(address(longFarmer), assets);
        longFarmer.rxFunds(assets);
    }

    function beforeWithdraw(uint256 assets, uint256 shares) internal virtual override {
        require(whiteList[msg.sender] == true);
        longFarmer.returnFunds(assets);
    }

    modifier onlyWhitelist() {
        require(whiteList[msg.sender], "only whitelisted addresses can use vault");
        _;
    }
}
