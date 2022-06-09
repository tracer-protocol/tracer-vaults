pragma solidity ^0.8.0;

interface ILiquidityGauge {  
    function balanceOf(address user) external view returns(uint256);

    function claim_rewards(address user, address receiver) external;
}