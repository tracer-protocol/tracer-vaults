// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/ds-test/src/test.sol";
import "../lib/foundry-playground/src/ERC20TokenFaker.sol";
import "../lib/foundry-playground/src/FakeERC20.sol";
import {LongFarmer} from "../contracts/LongFarmer.sol";
import {SkewVault} from "../contracts/SkewVault.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";

interface Vm {
    function warp(uint256 x) external;

    function expectRevert(bytes calldata) external;

    function roll(uint256) external;

    function prank(address) external;
}

contract SkewVaulttest is DSTest, ERC20TokenFaker {
    LongFarmer longFarmer;
    SkewVault skewVault;
    FakeERC20 fUSD;
    ERC20 tUSD;

    // Vm VM = Vm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);
    // Use below for forked network testing
    // forge test -vvv --fork-url https://arb-rinkeby.g.alchemy.com/v2/2LMiiNiXkk1CYIlXLjVFottvrUUnz4ps

    function setUp() public {
        fUSD = fakeOutERC20(address(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6));
        skewVault = new SkewVault(address(fUSD));
        longFarmer = new LongFarmer();
        fUSD.approve(address(skewVault), 1e18);
        fUSD._setBalance(address(this), 1e18);
        skewVault.setWhiteList(address(this), true);
        longFarmer.initialize(
            0x5dC60E2AB4bE89691264445401d427A15Bb897C6,
            1000,
            0xa5C800867C42fa506E2384f3Da18F400E8E208FB,
            0xCB4fc400Cf54fC62db179F7e0C9867B6f52cd58d,
            skewVault
        );
        longFarmer.setSkewVault(address(skewVault));
        skewVault.setLongFarmer(address(longFarmer));
        fUSD.approve(address(longFarmer), 1e18);
    }

    function testDeposit() public {
        skewVault.deposit(1000000, address(this));
        assert(ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6).balanceOf(address(longFarmer)) == 1000000);
    }

    function testWithdraw() public {
        skewVault.deposit(1000000, address(this));
        skewVault.withdraw(1000000, address(this), address(this));
        assert(ERC20(0x9e062eee2c0Ab96e1E1c8cE38bF14bA3fa0a35F6).balanceOf(address(longFarmer)) == 0);
    }
}
