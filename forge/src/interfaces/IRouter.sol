    // SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface IRouter {
    function addLiquidity(uint256 _pid, uint256 _amount, address _to) external;
    function instantRedeemLocal(uint16 _pid, uint256 _amountLP, address _to) external returns (uint256);
}