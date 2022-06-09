pragma solidity ^0.8.0;

interface ILiquidityGaugeFactory {

    function getPoolGauge(address pool) external view returns (address);
    
}