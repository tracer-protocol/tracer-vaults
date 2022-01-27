// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface TracerVault {
    /*///////////////////////////////////////////////////////////////
                    Tracer Custom Mutable Functions
    //////////////////////////////////////////////////////////////*/
    // Sets an approved stategy for the ERC-4626 shares contract.
    function setApprovedStrategy(address strategy) external returns (bool);

    //removes a strategy from approved mapping
    function removeApprovedStrategy(address strategy) external returns (bool);

    //deposits into approved strategy
    function depositStrategy(address strategy, uint256 amount) external returns (uint256 balance);

    //withdraws from approved strategy
    function withdrawFromStrategy(address strategy, uint256 amount) external returns (uint256 balance);

    //Rabalances from approved strategy
    function rebalance(address strategy) external returns (bool);

    /*///////////////////////////////////////////////////////////////
                    Tracer Custom View Functions
    //////////////////////////////////////////////////////////////*/

    // Checks an address is an approved strategy
    function isStrategy() external view returns (bool);

    // Checks buffer balance is greater than 0.05 of total balance
    function buffer() external view returns (uint256);

    // Checks the Rollover of the strategy
    function getRollover() external view returns (uint256);

    // Checks the total balance of the strategy
    function getValue(address strategy) external view returns (uint256);

    /*///////////////////////////////////////////////////////////////
                            View Functions
    //////////////////////////////////////////////////////////////*/
    /** 
      @notice The underlying token the Vault accepts.
      @return the ERC20 underlying implementation address.
    */
    function underlying() external view returns (address);

    /** 
      @notice Returns a user's Vault balance in underlying tokens.
      @param user The user to get the underlying balance of.
      @return balance The user's Vault balance in underlying tokens.
    */
    function balanceOfUnderlying(address user) external view returns (uint256 balance);

    /** 
      @notice Calculates the total amount of underlying tokens the Vault holds.
      @return totalUnderlyingHeld The total amount of underlying tokens the Vault holds.
    */
    function totalHoldings() external view returns (uint256);

    /** 
      @notice Calculates the amount of shares corresponding to an underlying amount.
      @param underlyingAmount the amount of underlying tokens to convert to shares.
      @return shareAmount the amount of shares corresponding to a given underlying amount
    */
    function calculateShares(uint256 underlyingAmount) external view returns (uint256 shareAmount);

    /** 
      @notice Calculates the amount of underlying corresponding to a share amount.
      @param shareAmount the amount of shares to convert to an underlying amount.
      @return underlyingAmount the amount of underlying corresponding to a given amount of shares.
    */
    function calculateUnderlying(uint256 shareAmount) external view returns (uint256 underlyingAmount);
}
