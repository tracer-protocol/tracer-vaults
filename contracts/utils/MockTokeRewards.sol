
pragma solidity ^0.8.0;

import {ERC20} from "../../lib/solmate/src/mixins/ERC4626.sol";

// WARNING: This contract is only for mocking interactions with Tokemak.
// DO NOT USE IN PRODUCTION
contract MockTokeRewards {

    struct Recipient {
        uint256 chainId;
        uint256 cycle;
        address wallet;
        uint256 amount;
    }

    ERC20 public token;

    constructor(address _token) {
        token = ERC20(_token);
    }

    /// @notice Mock: Claim your rewards
    /// @param recipient Published rewards payload
    function claim(
        Recipient calldata recipient,
        uint8,
        bytes32,
        bytes32
    ) external {
        // simply send tokens to the claimer
        token.transfer(recipient.wallet, recipient.amount);
    }


}