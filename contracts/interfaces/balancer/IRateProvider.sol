pragma solidity ^0.8.0;

// A minimal wrapper on the Balancer Rate Provider interface. Created to support Solidity ^0.8.0
interface IRateProvider {
    /**
    * @notice Gets the rate provider for a given metastable pool
    */
    function getRate() external view returns(uint256);
}