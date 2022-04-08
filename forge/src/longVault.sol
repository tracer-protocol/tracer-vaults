// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.1;
import {ILeveragedPool} from "./interfaces/ILeveragedPool.sol";
import {L2Encoder} from "./utils/L2Encoder.sol";
import {IPoolCommitter} from "./interfaces/IPoolCommitter.sol";
import {ILeveragedPool} from "./interfaces/ILeveragedPool.sol";
import {ERC20} from "../lib/solmate/src/tokens/ERC20.sol";
import {SafeMath} from "openzeppelin/utils/math/SafeMath.sol";

contract longVault {
    using SafeMath for uint256;
    ERC20 USDC;
    ERC20 THREELBTC;
    IPoolCommitter poolCommitter;
    ERC20 vault;
    address poolAddress;
    bool public tradeLive;
    uint256 public threshold;
    ILeveragedPool public pool;
    L2Encoder encoder;
    event holding(uint256 _amt);
    event unwind(uint256 _amt);
    event releasing(uint256 _amt);
    event noAction(uint256 _skew);
    event Log(string _msg);
    event acquired(uint256 _amt);

    constructor(
        address _poolAddress,
        uint256 _threshold,
        address _committer,
        address _encoder,
        ERC20 _vault
    ) public {
        poolAddress = _poolAddress;
        threshold = _threshold;
        pool = ILeveragedPool(poolAddress);
        poolCommitter = IPoolCommitter(_committer);
        encoder = L2Encoder(_encoder);
        tradeLive = false;
        _vault = vault;
    }

    function checkSkew() public onlyPlayer {
        uint256 _skew = skew();
        uint256 _bal = THREELBTC.balanceOf(address(this)).add(agBal());
        if (_skew > threshold) {
            uint256 target = target();

            if (_bal < target) {
                uint256 aq = acquiring();
                acquire(aq);
            }
            if (_bal > target) {
                uint256 ds = disposing();
                dispose(ds);
            }
            if (_bal == target) {
                emit holding(_bal);
            }
            emit noAction(_skew);
        }
        if (_skew < threshold) {
            // TODO: check if this is correct
            dispose(_bal);
            emit unwind(_bal);
        }
    }

    function skew() public view returns (uint256) {
        uint256 _skew = pool.shortBalance() / pool.longBalance();
        return _skew;
    }

    function target() public view returns (uint256) {
        uint256 _bal = THREELBTC.balanceOf(address(this)).add(agBal());
        uint256 _skew = skew();
        uint256 _target = pool.longBalance() / threshold;
        uint256 target = _target.sub(pool.shortBalance());
        return target;
    }

    function acquiring() public view returns (uint256) {
        uint256 _bal = THREELBTC.balanceOf(address(this)).add(agBal());
        return target().sub(_bal);
    }

    function disposing() public view returns (uint256) {
        uint256 _bal = THREELBTC.balanceOf(address(this)).add(agBal());
        return _bal.sub(target());
    }

    function acquire(uint256 _amount) private {
        bytes32 args = encoder.encodeCommitParams(
            _amount,
            IPoolCommitter.CommitType.LongMint,
            agBalBool(_amount),
            true
        );
        poolCommitter.commit(args);
        emit acquired(_amount);
        tradeLive = true;
    }

    function dispose(uint256 _amount) private {
        bytes32 args = encoder.encodeCommitParams(
            _amount,
            IPoolCommitter.CommitType.LongBurn,
            agBalBool(_amount),
            true
        );
        poolCommitter.commit(args);
        tradeLive = false;
    }

    function agBalBool(uint256 _amt) public view returns (bool) {
        uint256 lTokens = poolCommitter.getAggregateBalance(address(this)).longTokens;
        lTokens > _amt ? true : false;
    }

    function agBal() public view returns (uint256) {
        uint256 lTokens = poolCommitter.getAggregateBalance(address(this)).longTokens;
        return lTokens;
    }

    modifier onlyPlayer() {
        require(vault.balanceOf(address(msg.sender)) > 1, "Only player can execute");
        _;
    }
}
