pragma solidity ^0.8.0;

// 0.8.0 support for Uni / Sushi V2
interface UniswapV2Router02 {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual returns (uint[] memory amounts);
}