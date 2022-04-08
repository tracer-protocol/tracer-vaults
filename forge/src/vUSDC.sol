// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.10;
import "solmate/mixins/ERC4626.sol";
import {ERC20} from "solmate/tokens/ERC20.sol";
import {IStargate} from "./interfaces/IStargate.sol";
import {FixedPointMathLib} from "solmate/utils/FixedPointMathLib.sol";
import {SafeTransferLib} from "solmate/utils/SafeTransferLib.sol";
import {Ownable} from "openzeppelin/access/Ownable.sol";
import {IRouter} from "./interfaces/IRouter.sol";
import {IAsset, IBalancer} from "./interfaces/IBalancer.sol";
import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";
// import {ERC20} from "forge/lib/solmate/src/tokens/ERC20.sol";
// import {IStargate} from "./interfaces/IStargate.sol";
// import {FixedPointMathLib} from "forge/lib/solmate/src/utils/FixedPointMathLib.sol";
// import {SafeTransferLib} from "forge/lib/solmate/src/utils/SafeTransferLib.sol";
// import {Ownable} from "forge/lib/openzeppelin-contracts/contracts/access/Ownable.sol";
// import {IRouter} from "./interfaces/IRouter.sol";
// import {IAsset, IBalancer} from "./interfaces/IBalancer.sol";
// import {IERC20} from "forge/lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";

// Vault for depositing underlying (usdc) into stargate, compounding STG rewards through balancer for more underlying
contract vUSDC is ERC4626, Ownable{
    using FixedPointMathLib for uint256;
    event balancerSwap(uint256 _amt);
    event staked(uint256 _amt);
    event stgBal(uint256 _stgBal);
    event feeCollected(uint256 _amt);
    event Log(string message);

    //usdc
    ERC20 public immutable UNDERLYING;
    //pUSDC
    ERC20 public immutable POOLTOKEN;
    //stg token
    ERC20 public STG;
    //stg contract, import interface
    IStargate public staker;
    //fee collector
    address public feeCollector;
    //stargate pool ID (usd = 1)
    //router
    IRouter public immutable router;
    //deposit fee
    uint256 public fee;
    bytes32 public immutable _balancerPool =
        0x3a4c6d2404b5eb14915041e01f63200a82f4a343000200000000000000000065; //arbitrum balancer vault
    
    constructor(address _underlying, string memory name, string memory symbol) ERC4626(ERC20(_underlying), name, symbol){
        UNDERLYING = ERC20(_underlying);
        router = IRouter(0x53Bf833A5d6c4ddA888F69c22C88C9f356a41614); //arbitrum router
        staker = IStargate(0xeA8DfEE1898a7e0a59f7527F076106d7e44c2176); //Arbitrum LP staker
        POOLTOKEN = ERC20(0x892785f33CdeE22A30AEF750F285E18c18040c3e); //Arbitrum USDC LP token
        STG = ERC20(0x6694340fc020c5E6B96567843da2df01b2CE1eb6); //Arbitrum STG reward token
        UNDERLYING.approve(address(router), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        POOLTOKEN.approve(address(staker), 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        STG.approve(0xBA12222222228d8Ba445958a75a0704d566BF2C8,  0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
        STG.approve(0xeA8DfEE1898a7e0a59f7527F076106d7e44c2176,  0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff);
    }
    function totalAssets() public view virtual override returns (uint256){
         return value();
    }
    // $ per LP token
    function lpStats() public view virtual returns (uint256){
        uint256 sup= POOLTOKEN.totalSupply();
        uint256 bal = UNDERLYING.balanceOf(address(POOLTOKEN));
        return bal.divWadDown(sup);
    }
    function value() public view returns(uint256) {
       (uint256 amount, ) = staker.userInfo(
            0,
            address(this)
        );
        return amount.mulWadDown(lpStats());
    }
    function lpPerShare() public view returns(uint256) {
        (uint256 amount, ) = staker.userInfo(
            0,
            address(this)
        );
        return amount.divWadDown(totalSupply);
    }
    function afterDeposit(uint256 assets, uint256 shares)internal virtual override {
        router.addLiquidity(1, assets, address(this));
        stake();
    }
    function stake() internal {
        uint256 _bal = POOLTOKEN.balanceOf(address(this));
        staker.deposit(0, _bal);
    }
    function beforeWithdraw(uint256 assets, uint256 shares)internal virtual override {
        uint256 lpWant = lpPerShare().mulWadDown(shares);
        IStargate(staker).withdraw(0, lpWant);
        router.instantRedeemLocal(1, lpWant, address(this));
        require(UNDERLYING.balanceOf(address(this)) > 0, "no underlying");
    }

    function assetsToLp(uint256 assets) public view returns(uint256){
        return assets.divWadDown(lpStats());
    }
    function setFee(uint256 _fee)public onlyOwner{
        fee = _fee;
    }
    function setStaker(address _staker)public onlyOwner{
        staker = IStargate(_staker);
    }
    function setFeeCollector(address _feeCollector)public onlyOwner{
        feeCollector = _feeCollector;
    }
    //swap on balancer stg for more USDC, add liquidity, stake.
    function compound() public onlyOwner{
        uint256 _stg = STG.balanceOf(address(this));
        if(_stg > 1){
         IBalancer.SingleSwap memory swapParams = IBalancer
            .SingleSwap({
            poolId: _balancerPool,
            kind: IBalancer.SwapKind.GIVEN_IN,
            //STG token
            assetIn: IAsset(0x6694340fc020c5E6B96567843da2df01b2CE1eb6),
            //USDC
            assetOut: IAsset(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8),
            amount: _stg,
            userData: "0x"
         });
        IBalancer.FundManagement memory funds = IBalancer
        .FundManagement({
            sender: address(this),
            recipient: payable(address(this)),
            fromInternalBalance: false,
            toInternalBalance: false
        });
    // perform swap
    IBalancer(0xBA12222222228d8Ba445958a75a0704d566BF2C8).swap(swapParams, funds, 1, block.timestamp + 60);
    emit balancerSwap(_stg);
    uint256 _underlying = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(address(this));
    if(fee > 0){
        uint256 _fee = _underlying.mulWadDown(fee);
        ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).transfer(feeCollector, _fee);
        emit feeCollected(_fee);
    }
    uint256 underlying = ERC20(0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8).balanceOf(address(this));
    // Deposit stablecoin liquidity
    router.addLiquidity(
        1,
        underlying,
        address(this)
    );
    stake();
   emit staked(underlying);
   emit Log("compounded");
} return;
    }
}