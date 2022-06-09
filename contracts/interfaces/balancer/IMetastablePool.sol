pragma solidity ^0.8.0;

// A minimal wrapper on the Balancer Metastable Pool interface. Created to support Solidity ^0.8.0
interface IMetastablePool {
    /**
    * @notice Gets the rate provider for a given metastable pool
    */
    function getRateProviders() external view returns(address[] memory);
}