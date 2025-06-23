// SPDX-License-Identifier: MIT
pragma solidity >0.8.0;


// Standard ERC20 interface with basic functions and events
/// @title Standard ERC20 Interface
/// @notice Defines basic functions of a compliant ERC20 token
interface IERC20 {

    // Returns the total number of tokens in circulation
    function totalSupply() external view returns (uint256); 
   
    // Returns the balance of an account
    function balanceOf(address account) external view returns (uint256); 
    
    // Transfer tokens to the recipient
    function transfer(address recipient, uint256 amount) external returns (bool); 
    
    // Query the allowed assignment
    function allowance(address owner, address spender) external view returns (uint256); 
    
    // Allows another to spend tokens
    function approve(address spender, uint256 amount) external returns (bool); 
    
    // Transfer tokens on behalf of another
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool); 

    // Transfer event
    event Transfer(address indexed from, address indexed to, uint256 value); // Evento de transferencia
    
    // Approval event
    event Approval(address indexed owner, address indexed spender, uint256 value); // Evento de aprobación
}

// Basic implementation of an ERC20 token

/// @title Basic ERC20 Token Implementation
/// @notice Base token with standard features like transfer, approval, and internal mint/burn
contract ERC20 is IERC20 {
    
    // Token name
    string public name; 

    // Token symbol
    string public symbol; 
    
    // Token decimals
    uint8 public constant decimals = 18; 
    
    // Total in circulation
    uint256 public override totalSupply; 

    // Map balances for each account
    mapping(address => uint256) public override balanceOf; 
    
    // Map permissions between accounts
    mapping(address => mapping(address => uint256)) public override allowance;

    /// @notice Constructor that defines name and symbol
    constructor(string memory _name, string memory _symbol) {
        
        // Assign the name to the token
        name = _name; 
        
        // Assign the symbol to the token
        symbol = _symbol; 
    }

    // Allow the token holder to send a specified amount to another address.
    /// @notice Transfer tokens to another address
    function transfer(address recipient, uint256 amount) public override returns (bool) {
        
        // Check that there is sufficient balance
        require(balanceOf[msg.sender] >= amount, "Insufficient balance"); 
        
        // Subtraction from the issuer
        balanceOf[msg.sender] -= amount; 
        
        // Add to the receiver
        balanceOf[recipient] += amount; 
        
        // Emits event Transfer
        emit Transfer(msg.sender, recipient, amount); 
        
        return true;
    }

    // Permitir que otra dirección pueda retirar tokens en tu cuenta.
    /// @notice Approves an amount to be spent by another
    function approve(address spender, uint256 amount) public override returns (bool) {
        
        // Assign approval
        allowance[msg.sender][spender] = amount; 
        
        // Emits event Approval
        emit Approval(msg.sender, spender, amount);
        
        return true;
    }

    
    // Esta función permite que los contratos inteligentes u otros usuarios muevan tus tokens por vos, siempre con tu permiso previo.
    /// @notice Allows a third party to transfer tokens on behalf of the user
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        
        // Check balance
        require(balanceOf[sender] >= amount, "Insufficient balance"); 
        
        // Check permission
        require(allowance[sender][msg.sender] >= amount, "Allowance exceeded"); 
        
        
        // Subtraction of permission
        allowance[sender][msg.sender] -= amount; 
        
        // Subtract from the issuer's balance        
        balanceOf[sender] -= amount; 
        
        // Add to the receiver
        balanceOf[recipient] += amount; 
        
        // Emits event
        emit Transfer(sender, recipient, amount); 
        return true;
    }

    
    // creates from scratch and deposits them into the account
    /// @notice Internal function to create tokens
    function _mint(address to, uint256 amount) internal {
        
        // Add to the receiver
        balanceOf[to] += amount; 
        
        // Increase the total
        totalSupply += amount; 
        
        // Emits event Transfer from address zero
        emit Transfer(address(0), to, amount); 
    }

    
    // To destroy tokens, removing them from a user's balance and reducing the total supply.
    /// @notice Internal function to destroy tokens
    function _burn(address from, uint256 amount) internal {
        
        // Check balance
        require(balanceOf[from] >= amount, "Insufficient balance"); 
        
        // Subtraction from balance
        balanceOf[from] -= amount; 
        
        // Decrease the total
        totalSupply -= amount; 
        
        // Emits event towards address zero
        emit Transfer(from, address(0), amount); 
    }
}

// Liquidity token issued by the SimpleSwap contract
/// @title Liquidity token for SimpleSwap
/// @notice Token that represents participation in a liquidity pool
contract LiquidityToken is ERC20 {
    
    // Authorized contract address
    address public swapContract; 

    /*
        This modifier allows a function to be executed only if the caller (msg.sender) is the SimpleSwap contract.
        It is used to protect functions like mint(...) and burn(...), preventing any user from arbitrarily creating 
        or destroying liquidity tokens.
    */
    /// @notice Modifier that restricts execution to the SimpleSwap contract
    modifier onlySwap() {
        
        // Only the main contract can execute
        require(msg.sender == swapContract, "Only SimpleSwap can mint/burn"); 
        _;
    }


    // Initialize the liquidity token and register the SimpleSwap contract as the only one authorized to issue or burn tokens.
    /// @notice Constructor that assigns the name, symbol, and authorizes the contract it deploys
    constructor() ERC20("Liquidity Token", "LPT") {
        
        // Save the deployer as the swap contract
        swapContract = msg.sender;
    }

    //It is only used when someone adds liquidity on SimpleSwap.
    /// @notice Mint LP tokens only from SimpleSwap
    /// @param to Address receiving LP tokens
    /// @param amount Amount of LP tokens to mint
    function mint(address to, uint256 amount) external onlySwap {
       
        // Mind liquidity tokens
        _mint(to, amount); 
    }


    //It is used when a user withdraws liquidity from the SimpleSwap contract
    /// @notice Remove LP tokens from circulation only from SimpleSwap
    /// @param from Address from which tokens are burned
    /// @param amount Amount of tokens to burn
    function burn(address from, uint256 amount) external onlySwap {
        
        // Remove liquidity tokens
        _burn(from, amount); // Quita tokens de liquidez
    }
}



// AMM type main exchange contract
/// @title Uniswap V2-style decentralized AMM contract
/// @notice Allows swapping tokens, adding/removing liquidity, and checking prices
contract SimpleSwap {
    
    // defines the data model that represents a token pair in the SimpleSwap contract
    struct Pair {
        
        // Reserve token A
        uint256 reserveA;
        
        // Reserve token B
        uint256 reserveB; 
        
        // Associated liquidity token
        LiquidityToken liquidityToken;
    }

    // Maps token pairs to their data
    mapping(address => mapping(address => Pair)) public pairs;

    // Add liquidity to the pool
    /// @notice Agrega liquidez a un par y emite tokens LP
    /// @param tokenA Dirección del token A
    /// @param tokenB Dirección del token B
    /// @param amountADesired Cantidad deseada de token A
    /// @param amountBDesired Cantidad deseada de token B
    /// @param amountAMin Mínimo aceptable de token A
    /// @param amountBMin Mínimo aceptable de token B
    /// @param to Dirección que recibe los LP tokens
    /// @param deadline Tiempo límite de validez
    /// @return amountA Cantidad final de token A usada
    /// @return amountB Cantidad final de token B usada
    /// @return liquidity Tokens de liquidez emitidos
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity) {
        
        // Check time limit
        require(block.timestamp <= deadline, "Transaction expired");
        
        // Different tokens
        require(tokenA != tokenB, "Tokens must differ");
        
        // Not null
        require(tokenA != address(0) && tokenB != address(0), "Invalid addresses");

        // Access the pair
        Pair storage pair = pairs[tokenA][tokenB];

        
        // Create liquidity token if it doesn't exist
        if (address(pair.liquidityToken) == address(0)) {
            pair.liquidityToken = new LiquidityToken();
        }


        //Ensure that tokens A and B are added in correct proportions, based on pool reserves, to maintain balance
        //se crea el pool
        if (pair.reserveA == 0 && pair.reserveB == 0) {
            amountA = amountADesired; // If there are no reservations, accept the desired
            amountB = amountBDesired;
        } else {
            //The optimal amount of B needed to equalize is calculated
            uint256 amountBOptimal = (amountADesired * pair.reserveB) / pair.reserveA; 
           
           //If amountBOptimal is less than or equal to amountBDesired (i.e. the user entered more B than necessary):
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, "Slippage too high B");
                amountA = amountADesired;
                amountB = amountBOptimal;
           
           //If amountBOptimal is greater than what the user wants to contribute from B, A is adjusted:
            } else {
                uint256 amountAOptimal = (amountBDesired * pair.reserveA) / pair.reserveB;
                require(amountAOptimal <= amountADesired, "Slippage too high A");
                require(amountAOptimal >= amountAMin, "Slippage too high A");
                amountA = amountAOptimal;
                amountB = amountBDesired;
            }
        }

        // Transfer token A
        require(IERC20(tokenA).transferFrom(msg.sender, address(this), amountA), "Transfer tokenA failed"); 
        
        // Transfiere token B
        require(IERC20(tokenB).transferFrom(msg.sender, address(this), amountB), "Transfer tokenB failed");

        // Calculate liquidity as the square root of the product
        liquidity = sqrt(amountA * amountB);
        
        // Issue liquidity tokens
        pair.liquidityToken.mint(to, liquidity);

        // Update reservations
        pair.reserveA += amountA;
        pair.reserveB += amountB;
 
        return (amountA, amountB, liquidity);
    }

    // Allows you to withdraw liquidity from the pool
    /// @notice Allows liquidity withdrawals and receipts of underlying tokens
    /// @param tokenA Token A address
    /// @param tokenB Token B address
    /// @param liquidity Amount of LP tokens to burn
    /// @param amountAMin Minimum acceptable token A amount
    /// @param amountBMin Minimum acceptable token B amount
    /// @param to Token receiving address
    /// @param deadline Validity deadline
    /// @return amountA Token A returned
    /// @return amountB Token B returned
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

        // Remove liquidity tokens from the user
        pair.liquidityToken.burn(msg.sender, liquidity);

        //calculates how many A and B tokens a user should receive when withdrawing liquidity from the pool.
        uint256 totalLiquidity = pair.liquidityToken.totalSupply();
        amountA = (pair.reserveA * liquidity) / totalLiquidity;
        amountB = (pair.reserveB * liquidity) / totalLiquidity;

        require(amountA >= amountAMin, "Slippage too high A");
        require(amountB >= amountBMin, "Slippage too high B");

        // Update reservations
        pair.reserveA -= amountA;
        pair.reserveB -= amountB;

        // Update reservations
        require(IERC20(tokenA).transfer(to, amountA), "Transfer A failed");
        
        // Send token B
        require(IERC20(tokenB).transfer(to, amountB), "Transfer B failed");

        return (amountA, amountB);
    }

    // Exact token exchange
    /// @notice Exchanges a fixed amount of one token for another
    /// @param amountIn Number of input tokens
    /// @param amountOutMin Minimum acceptable output amount
    /// @param path Array with token addresses (2 elements)
    /// @param to Receiving address of the output token
    /// @param deadline Validity limit
    /// @return amounts Array with input and output amounts
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint[] memory amounts) {
        require(path.length == 2, "Only 2-token path supported");
        require(block.timestamp <= deadline, "Transaction expired");

        //allows you to exchange one token for another, using the pool reserves as a calculation basis.
        address tokenIn = path[0];
        address tokenOut = path[1];

        Pair storage pair = pairs[tokenIn][tokenOut];
        require(address(pair.liquidityToken) != address(0), "Pair does not exist");

        // Receive the input token
        require(IERC20(tokenIn).transferFrom(msg.sender, address(this), amountIn), "Transfer in failed"); 

        // Calculate output
        uint256 amountOut = getAmountOut(amountIn, pair.reserveA, pair.reserveB); // Calcula salida
        require(amountOut >= amountOutMin, "Slippage too high");

        // Add input
        pair.reserveA += amountIn; // Suma entrada
        
        // Subtract output
        pair.reserveB -= amountOut; // Resta salida

        // Send tokens
        require(IERC20(tokenOut).transfer(to, amountOut), "Transfer out failed");

        amounts = new uint256[](2);
        amounts[0] = amountIn; // Save amounts for return
        amounts[1] = amountOut;
    }

    // Query the price of tokens relative to tokens
    /// @notice Returns the price of tokenA in terms of tokenB
    /// @param tokenA Address of token A
    /// @param tokenB Address of token B
    /// @return price Price in units with 18 decimal places
    function getPrice(address tokenA, address tokenB) external view returns (uint256 price) {
        Pair storage pair = pairs[tokenA][tokenB];
        require(pair.reserveA > 0 && pair.reserveB > 0, "Insufficient reserves");
        return (pair.reserveB * 1e18) / pair.reserveA; // Ratio multiplied by 1e18
    }

    // Calculate the output amount using AMM formula
    /// @notice Calculates the expected output amount for a swap
    /// @param amountIn Amount of input tokens
    /// @param reserveIn Input reservation
    /// @param reserveOut Output reservation
    /// @return amountOut Tokens to be received
    function getAmountOut(uint256 amountIn, uint256 reserveIn, uint256 reserveOut) public pure returns (uint256 amountOut) {
        require(amountIn > 0, "Amount in must be > 0");
        require(reserveIn > 0 && reserveOut > 0, "Invalid reserves");

        uint256 amountInWithFee = amountIn * 997; // Apply 0.3% fee
        uint256 numerator = amountInWithFee * reserveOut; // Numerator formula
        uint256 denominator = reserveIn * 1000 + amountInWithFee; // Denominator formula
        amountOut = numerator / denominator;
    }

    // @notice Integer square root math function
    /// @notice Calculates the square root of an integer
    /// @param y Value to calculate the square root
    /// @return z Integer result of sqrt(y)
    function sqrt(uint256 y) internal pure returns (uint256 z) {
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
