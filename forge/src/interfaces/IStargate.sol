// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.0;

interface IStargate {
    struct UserInfo {
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
    }

    function userInfo(uint256 _pid, address _user) external view returns (uint256, uint256);

    function deposit(uint256 _pid, uint256 _amount) external;

    function withdraw(uint256 _pid, uint256 _amount) external;
}
