// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;

import "../lib/ds-test/src/test.sol";
import "../lib/foundry-playground/src/ERC20TokenFaker.sol";
import "../lib/foundry-playground/src/FakeERC20.sol";
import {LongFarmer} from "../contracts/LongFarmer.sol";
import {SkewVault} from "../contracts/SkewVault.sol";
import {ERC20} from "../lib/openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import {SafeMath} from "../lib/openzeppelin-contracts/contracts/utils/math/SafeMath.sol";

interface Cheats {
    function warp(uint256 x) external;

    function expectRevert(bytes calldata) external;

    function roll(uint256) external;

    function prank(address) external;
}

contract SkewVaulttest is DSTest {
    using SafeMath for uint256;
    LongFarmer longFarmer;
    SkewVault skewVault;
    FakeERC20 fUSD;
    FakeERC20 longT;
    ERC20 tUSD;
    event Log(string);

    Cheats cheats = Cheats(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

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
            0x8155a758a06E7e385191C119D35195Aa743cBe9f,
            1000,
            0xC3d2052479dBC010480Ae16204777C1469CEffC9,
            0xCB4fc400Cf54fC62db179F7e0C9867B6f52cd58d,
            skewVault
        );
        longFarmer.setSkewVault(address(skewVault));
        skewVault.setLongFarmer(address(longFarmer));
        fUSD.approve(address(longFarmer), 1e18);
        fUSD.allowance(address(0xC3d2052479dBC010480Ae16204777C1469CEffC9), address(longFarmer));
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

    function testLongSwap() public {
        longT = fakeOutERC20(address(0x4AaDc48087b569dD3E65dBe65B0dD036891767e3));
        longT._setBalance(address(this), 1e18);
        fUSD._setBalance(address(longFarmer), 1e18);
        longFarmer.setActive();
        longT.approve(address(longFarmer), 1e18);
        uint256 want = 10000000;
        uint256 _lP = 1;
        longFarmer._swap(10000000, _lP);
    }

    function testCommit() public {
        fUSD._setBalance(address(longFarmer), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff); // onlyPlayer
        longFarmer.setActive();
        longFarmer.acquire(100000);
        emit Log("commit");
        // VM.roll(1 days);
        // ERC20(0x4AaDc48087b569dD3E65dBe65B0dD036891767e3).approve(0xC3d2052479dBC010480Ae16204777C1469CEffC9, 1e18);
        // longFarmer.dispose(1000);
        // emit Log("commit burn");
        // VM.roll(1 days);
        // assert(ERC20(0x4AaDc48087b569dD3E65dBe65B0dD036891767e3).balanceOf(address(longFarmer)) < 10000000);
        // longT = fakeOutERC20(address(0x4AaDc48087b569dD3E65dBe65B0dD036891767e3)); // 7x Long ETH
        // longT._setBalance(address(longFarmer), 10000000000000000000000000);
        // longT._setBalance(address(this), 10000000000000000000000000);
        // longT.approve(0xC3d2052479dBC010480Ae16204777C1469CEffC9, 1e18);
        // longT.approve(address(longFarmer), 1e18);
        // uint256 want = 100;

        // longFarmer.dispose(want);
    }
}
