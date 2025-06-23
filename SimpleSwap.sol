// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./LiquidityToken.sol";

/// @title SimpleSwap - Basic AMM similar to Uniswap V2
contract SimpleSwap {
    struct Pair {
        uint reserveA;
        uint reserveB;
        LiquidityToken liquidityToken;
    }

    mapping(address => mapping(address => Pair)) public pairs;

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity) {
        require(block.timestamp <= deadline, "Transaction expired");
        require(tokenA != tokenB, "Tokens must differ");
        require(tokenA != address(0) && tokenB != address(0), "Invalid addresses");

        Pair storage pair = pairs[tokenA][tokenB];

        if (address(pair.liquidityToken) == address(0)) {
            pair.liquidityToken = new LiquidityToken();
        }

        if (pair.reserveA == 0 && pair.reserveB == 0) {
            amountA = amountADesired;
            amountB = amountBDesired;
        } else {
            uint amountBOptimal = (amountADesired * pair.reserveB) / pair.reserveA;
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Slippage too high B");
                amountA = amountADesired;
                amountB = amountBOptimal;
            } else {
                uint amountAOptimal = (amountBDesired * pair.reserveA) / pair.reserveB;
                require(amountAOptimal <= amountADesired, "Slippage too high A");
                require(amountAOptimal >= amountAMin, "Slippage too high A");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer tokenA failed");
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer tokenB failed");

        liquidity = sqrt(amountA * amountB);
        pair.liquidityToken.mint(to, liquidity);

        pair.reserveA += amountA;
        pair.reserveB += amountB;

        return (amountA, amountB, liquidity);
    }

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB) {
        require(block.timestamp <= deadline, "Transaction expired");

        Pair storage pair = pairs[tokenA][tokenB];
        require(address(pair.liquidityToken) != address(0), "Pair does not exist");

        pair.liquidityToken.burn(msg.sender, liquidity);

        uint totalLiquidity = pair.liquidityToken.totalSupply();
        amountA = (pair.reserveA * liquidity) / totalLiquidity;
        amountB = (pair.reserveB * liquidity) / totalLiquidity;

        require(amountA >= amountAMin, "Slippage too high A");
        require(amountB >= amountBMin, "Slippage too high B");

        pair.reserveA -= amountA;
        pair.reserveB -= amountB;

        require(IERC20(tokenA).transfer(to, amountA), "Transfer A failed");
        require(IERC20(tokenB).transfer(to, amountB), "Transfer B failed");

        return (amountA, amountB);
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts) {
        require(path.length == 2, "Only 2-token path supported");
        require(block.timestamp <= deadline, "Transaction expired");

        address tokenIn = path[0];
        address tokenOut = path[1];

        Pair storage pair = pairs[tokenIn][tokenOut];
        require(address(pair.liquidityToken) != address(0), "Pair does not exist");

        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed");

        uint amountOut = getAmountOut(amountIn, pair.reserveA, pair.reserveB);
        require(amountOut >= amountOutMin, "Slippage too high");

        pair.reserveA += amountIn;
        pair.reserveB -= amountOut;

        require(IERC20(tokenOut).transfer(to, amountOut), "Transfer out failed");

        amounts = new uint[](2);
        amounts[0] = amountIn;
        amounts[1] = amountOut;
    }

    function getPrice(address tokenA, address tokenB) external view returns (uint price) {
        Pair storage pair = pairs[tokenA][tokenB];
        require(pair.reserveA > 0 && pair.reserveB > 0, "Insufficient reserves");
        return (pair.reserveB * 1e18) / pair.reserveA;
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut) {
        require(amountIn > 0, "Amount in must be > 0");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint amountInWithFee = amountIn * 997;
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 1000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}
