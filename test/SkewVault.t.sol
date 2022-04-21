// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/ds-test/src/test.sol";
import "../lib/foundry-playground/src/ERC20TokenFaker.sol";
import "../lib/foundry-playground/src/FakeERC20.sol";
import "../contracts/LongFarmer.sol";
import "../contracts/SkewVault.sol";

interface Vm {
    function warp(uint256 x) external;

    function expectRevert(bytes calldata) external;

    function roll(uint256) external;

    function prank(address) external;
}

contract SkewVaulttest is DSTest, ERC20TokenFaker {
    FakeERC20 FAKE;
    LongFarmer longFarmer;
    SkewVault skewVault;
    Vm VM = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

    function setUp() {
        fUSD = new FakeERC20(0xd1f6A92a9a4FA84e7D4d2E1Ab010B4032B678EdE);
        longFarmer = new LongFarmer();
        skewVaults = new SkewVault(fUSD);
        longFarmer.setSkewVault(skewVault);
        fUSD._setBalance(address(this), 1e18);
        fUSD.approve(address(skewVault), 1e18);
    }

    //test deposit
    function deposit(uint256 assets) public {
        skewVault.deposit(assets);
        assert(fUSD.balanceOf(address(skewVault)) == assets);
    }
}
