### Permissions
This document outlines permissioning for the Vault and LongFarmer contracts. 

## Modifiers
`onlyPlayer`: Only vault token holders can interact with functions marked `onlyPlayer`.

`onlyWhenSkewed()`: Only perform the relevant function when a skew exists.

`onlyWhitelist`: only whitelisted addresses may interact with functions attracting this modifier. 

`mapping(address => bool) public whiteList`: Mapping containing whitelisted addresses for the above.

`onlyOwner`: Only the contract owner may perform this function. 