// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    Full Uniswap V3 ETH -> Token Swap Example

    Features:
    - Swaps native ETH
    - Uses Uniswap V3 SwapRouter
    - Supports ETH -> Any ERC20 token
    - Includes slippage protection via amountOutMinimum
    - Sends output tokens directly to user
    - Wrap Eth to Weth

    Router (Ethereum Mainnet):
    0xE592427A0AEce92De3Edee1F18E0157C05861564
*/

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
}
interface ISwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee; // 500 = 0.05%, 3000 = 0.3%, 10000 = 1%
        address recipient;
        uint256 amountIn;
        uint256 deadline;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    function exactInputSingle(
        ExactInputSingleParams calldata params
    ) external payable returns (uint256 amountOut);
}

contract UniswapV3ETHSwapper {
    // Uniswap V3 Router (Mainnet)
    ISwapRouter public constant swapRouter =
        ISwapRouter(0xE592427A0AEce92De3Edee1F18E0157C05861564);

    // Mainnet WETH Address
    address public constant WETH =0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    event SwapExecuted(
        address indexed user,
        address indexed tokenOut,
        uint256 ethIn,
        uint256 amountOut
    );

    /*
        Swap ETH -> Any Token

        Example:
        ETH -> WETH
        ETH -> USDC
        ETH -> DAI
        ETH -> UNI

        Parameters:
        _tokenOut = token you want to receive
        _fee = pool fee tier (usually 3000)
        _amountOutMin = slippage protection
    */
    function swapTokenForToken(
    address _tokenIn,
    address _tokenOut,
    uint24 _fee,
    uint256 _amountIn,
    uint256 _amountOutMin
) external returns (uint256 amountOut) {
    require(_tokenIn != address(0), "Invalid tokenIn");
    require(_tokenOut != address(0), "Invalid tokenOut");
    require(_tokenIn != _tokenOut, "Same token");
    require(_amountIn > 0, "Amount must be > 0");

    // Transfer tokenIn from user to this contract
    IERC20(_tokenIn).transferFrom(
        msg.sender,
        address(this),
        _amountIn
    );

    // Approve Uniswap router to spend tokenIn
    IERC20(_tokenIn).approve(
        address(swapRouter),
        _amountIn
    );

    ISwapRouter.ExactInputSingleParams memory params =
        ISwapRouter.ExactInputSingleParams({
            tokenIn: _tokenIn,
            tokenOut: _tokenOut,
            fee: _fee,
            recipient: msg.sender, // tokens go directly to user
            deadline:block.timestamp,
            amountIn: _amountIn,
            amountOutMinimum: _amountOutMin,
            sqrtPriceLimitX96: 0
        });

    // Execute swap
    amountOut = swapRouter.exactInputSingle(params);

    emit SwapExecuted(
        msg.sender,
        _tokenOut,
        _amountIn,
        amountOut
    );
}

    /*
        Helper: Swap ETH -> WETH directly

        Uses standard 0.3% pool fee = 3000
    */
   



    function wrapETH() external payable {
    require(msg.value > 0, "Send ETH");

    IWETH(WETH).deposit{value: msg.value}();

    IWETH(WETH).transfer(msg.sender, msg.value);
}

 function wethBalance() public view returns (uint256) {
            IERC20 WETH = IERC20(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);

             return WETH.balanceOf(msg.sender);
        }


    // Allow contract to receive ETH
    receive() external payable {}
}