# SimpleSwap
SimpleSwap
SimpleSwap is a lightweight decentralized exchange (DEX) smart contract built in Solidity, inspired by the core functionality of Uniswap V2. It allows users to:
- Add and remove liquidity
- Swap ERC20 tokens
- Get live exchange rates between token pairs
- Calculate estimated output for token swaps
Technologies
- Solidity >0.8.0
- ERC20 Standard (OpenZeppelin-style interface)
- Custom Liquidity Token implementation
- Compatible with Hardhat, Remix or Truffle environments
- Tested on Ethereum Sepolia Testnet
Project Structure
contracts/
├── SimpleSwap.sol         # Main DEX contract
├── LiquidityToken.sol     # ERC20 LP Token issued per pair
└── TokenERC20.sol         # Custom ERC20 token for testing
Features
Add Liquidity
Allows users to deposit two tokens and mint LP tokens.
function addLiquidity(
  address tokenA,
  address tokenB,
  uint amountADesired,
  uint amountBDesired,
  uint amountAMin,
  uint amountBMin,
  address to,
  uint deadline
) external returns (uint amountA, uint amountB, uint liquidity);
Remove Liquidity
Burns LP tokens and returns token A & B in proportion.
function removeLiquidity(
  address tokenA,
  address tokenB,
  uint liquidity,
  uint amountAMin,
  uint amountBMin,
  address to,
  uint deadline
) external returns (uint amountA, uint amountB);
Swap Tokens
Performs a swap between two tokens using constant product formula.
function swapExactTokensForTokens(
  uint amountIn,
  uint amountOutMin,
  address[] calldata path,
  address to,
  uint deadline
) external returns (uint[] memory amounts);
Get Token Price
Returns the exchange rate between two tokens.
function getPrice(address tokenA, address tokenB) external view returns (uint price);
Estimate Swap Output
Estimates how many tokens you'll receive in a swap before executing.
function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) public pure returns (uint amountOut);
How to Use
1. Deploy ERC20 Tokens (for simulation)
Use TokenERC20.sol to deploy two tokens like TokenA and TokenB.
TokenERC20 tokenA = new TokenERC20("Token A", "TKA", 1_000_000 ether);
TokenERC20 tokenB = new TokenERC20("Token B", "TKB", 1_000_000 ether);
2. Deploy SimpleSwap
Deploy the SimpleSwap.sol contract on Remix or via Hardhat.
3. Add Liquidity
Call addLiquidity() by providing token amounts, minimums and a deadline.
4. Perform Swaps
Use swapExactTokensForTokens(...) with path [tokenA, tokenB].
Example LP Token Creation Logic
Each new token pair gets a unique LiquidityToken:
if (address(pair.liquidityToken) == address(0)) {
    pair.liquidityToken = new LiquidityToken();
}
Security Notes
- Includes slippage protection (amountMin checks)
- Includes deadline to avoid stale transactions
- LP token mint/burn restricted via onlySwap modifier
License
MIT License © 2025
Author
Developed by Jorge Lesme 
