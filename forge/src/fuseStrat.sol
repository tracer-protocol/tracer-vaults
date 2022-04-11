// SPDX-License-Identifier: Unlicense
pragma solidity ^0.8.10;
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import "openzeppelin/token/ERC20/extensions/IERC20Metadata.sol";

// Strat functions to interact with the Fuse contract from a vault
interface IFToken {
    function accrueInterest() external returns (uint256);

    function exchangeRateStored() external view returns (uint256);

    function mint(uint256 mintAmount) external returns (uint256);

    function redeem(uint256 redeemTokens) external returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function underlying() external view returns (address);

    function isCToken() external view returns (bool);
}

contract FuseStrat {
    string public name;
    address public immutable fToken;

    address public immutable uToken;

    constructor(address _fToken) {
        require(IFToken(_fToken).isCToken(), "Tracer: not an fToken");
        fToken = _fToken;
        uToken = IFToken(_fToken).underlying();

        name = string(abi.encodePacked("Rari Fuse ", IERC20Metadata(uToken).symbol(), " Strategy"));
    }

    function _accrue() external {
        IFToken(fToken).accrueInterest();
    }

    function _deposit(uint256 amount) external {
        if (amount == 0) return;
        _approve(uToken, fToken, amount);
        require(IFToken(fToken).mint(amount) == 0, "Fuse: mint failed");
    }

    function _withdraw(uint256 amount) external {
        if (amount == 0) return;
        uint256 fAmount = 1 + FixedPointMathLib.mulDivDown(amount, 1e18, IFToken(fToken).exchangeRateStored());

        require(IFToken(fToken).redeem(fAmount) == 0, "Fuse: redeem failed");
    }

    function _balanceOf(address account) external view returns (uint256 balance) {
        IFToken _fToken = IFToken(fToken);
        return FixedPointMathLib.mulDivDown(_fToken.balanceOf(account), _fToken.exchangeRateStored(), 1e18);
    }

    function _approve(
        address token,
        address spender,
        uint256 amount
    ) private {
        if (IERC20(token).allowance(address(this), spender) < amount) {
            IERC20(token).approve(spender, type(uint256).max);
        }
    }
}
