// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @title LiquidityToken - Represents liquidity provided to the SimpleSwap contract
contract LiquidityToken is ERC20 {
    address public swapContract;

    modifier onlySwap() {
        require(msg.sender == swapContract, "Only SimpleSwap can mint/burn");
        _;
    }

    constructor() ERC20("Liquidity Token", "LPT") {
        swapContract = msg.sender;
    }

    function mint(address to, uint amount) external onlySwap {
        _mint(to, amount);
    }

    function burn(address from, uint amount) external onlySwap {
        _burn(from, amount);
    }
}