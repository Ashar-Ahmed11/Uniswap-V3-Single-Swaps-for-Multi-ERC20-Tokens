// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

/*
    Full Uniswap V3 ETH -> Token Swap Example

    Features:
    - Swaps native ETH
    - Uses Uniswap V3 SwapRouter
    - Supports ETH -> WETH
    - Supports ETH -> Any ERC20 token
    - Includes slippage protection via amountOutMinimum
    - Sends output tokens directly to user

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
        uint24 fee;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps amountIn of one token for as much as possible of another token
    /// @param params The parameters necessary for the swap, encoded as ExactInputSingleParams in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params)
        external
        payable
        returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 deadline;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps amountIn of one token for as much as possible of another along the specified path
    /// @param params The parameters necessary for the multi-hop swap, encoded as ExactInputParams in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params)
        external
        payable
        returns (uint256 amountOut);
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
    function swapTokenForToken (
    address _tokenIn,
    address _tokenOut,
    uint24 _fee,
    uint256 _amountIn,
    address _recepient
) public returns (uint256 amountOut) {
    require(_tokenIn != address(0), "Invalid tokenIn");
    require(_tokenOut != address(0), "Invalid tokenOut");
    require(_tokenIn != _tokenOut, "Same token");
    require(_amountIn > 0, "Amount must be > 0");
    require(_recepient != address(0), "Invalid Recepient");

    // Transfer tokenIn from user to this contract
    // IERC20(_tokenIn).transferFrom(
    //     msg.sender,
    //     address(this),
    //     _amountIn
    // );

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
            recipient: _recepient, // tokens go directly to user
            deadline:block.timestamp+500,
            amountIn: _amountIn,
            amountOutMinimum: 0,
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

contract Pool is UniswapV3ETHSwapper {
    uint256 public poolId;
    address public poolAdmin;
    address public poolToken;
    uint256 public poolTokenAmount;
    uint256 public membersOfPools;
    mapping(uint256 => address) public memberAddress;
    mapping(address => uint256) public memberTokenBalance;
     enum Status { Ongoing, Finished }

    uint256 public tradeTokens;
    struct tradeToken{
        address tokenAddress;
        uint256 tokenTotalBalance;
        uint256 tokenEntryPrice;
        uint256 tokenExitPrice;
        Status tradeStatus;
    }

    mapping(uint256 => tradeToken) public tradeTokenById;
    mapping(address => mapping(uint256=>uint256)) public tradeTokenBalance;


    constructor(uint256 _poolId, address _poolAdmin, address _poolToken,uint256 _depositTokenAmount){
            poolId = _poolId;
            poolAdmin = _poolAdmin;
            poolToken = _poolToken;
            poolTokenAmount +=_depositTokenAmount;
            membersOfPools++;
            memberAddress[membersOfPools] = _poolAdmin;
            memberTokenBalance[_poolAdmin] +=_depositTokenAmount;
    }
    


    function depositToken(uint256 _depositTokenAmount)  public{
         IERC20 depositToken = IERC20(poolToken);
         bool isMember = false;
        for(uint i=1;i<=membersOfPools;i++){
            if(memberAddress[i] == msg.sender){
                isMember=true;
                break;
            }
        }
        if(isMember){
             poolTokenAmount +=_depositTokenAmount;
             memberTokenBalance[msg.sender] +=_depositTokenAmount;
        }
        else{
        poolTokenAmount +=_depositTokenAmount;
        membersOfPools++;
        memberAddress[membersOfPools] = msg.sender;
        memberTokenBalance[msg.sender] +=_depositTokenAmount;
        }
        depositToken.transferFrom(msg.sender,address(this),_depositTokenAmount);
        
    }

    function trade(address _tradeToken, uint256 _tradeAmount) public payable {
            require(msg.sender==poolAdmin,"You are not the admin of the pool");
          // must approve pooltoken to the contract

            swapTokenForToken(address(poolToken),address(_tradeToken),3000,_tradeAmount,address(this));
            IERC20 tradedToken = IERC20(_tradeToken);
            tradeTokens++;
            uint256 tradeTokenAmount = tradedToken.balanceOf(address(this));


            // uint256 previousTokenPrice =  tradeTokenById[tradeTokens].tokenEntryPrice;
            // uint256 currentTokenPrice = tradeTokenAmount*1e18/_tradeAmount;
            // uint256 tokenEntryPrice = previousTokenPrice==0?currentTokenPrice:(previousTokenPrice+currentTokenPrice)/2;

//   uint256 previousTokenPrice =  tradeTokenById[tradeTokens].tokenEntryPrice;
            // uint256 currentTokenPrice = tradeTokenAmount*1e18/_tradeAmount;
            uint256 tokenEntryPrice = tradeTokenAmount*1e18/_tradeAmount;


            tradeTokenById[tradeTokens] = tradeToken(_tradeToken,tradeTokenAmount,tokenEntryPrice,0,Status.Ongoing);
            for(uint256 i=1;i<=membersOfPools;i++){
                    uint256 memberTradeShare =  (tradedToken.balanceOf(address(this)) * memberTokenBalance[memberAddress[i]]) / poolTokenAmount;
                    tradeTokenBalance[memberAddress[i]][tradeTokens] += memberTradeShare;
                }
                poolTokenAmount-=_tradeAmount;

    }

     function dca(uint256 tradeTokenId, uint256 _tradeAmount) public payable {
            require(msg.sender==poolAdmin,"You are not the admin of the pool");
          // must approve pooltoken to the contract
            address _tradeToken = tradeTokenById[tradeTokenId].tokenAddress;
            swapTokenForToken(address(poolToken),address(_tradeToken),3000,_tradeAmount,address(this));
            IERC20 tradedToken = IERC20(_tradeToken);
            uint256 tradeTokenAmount = tradedToken.balanceOf(address(this));
            uint256 newTradeAmount = tradedToken.balanceOf(address(this))-tradeTokenById[tradeTokenId].tokenTotalBalance;

            uint256 previousTokenPrice =  tradeTokenById[tradeTokenId].tokenEntryPrice;
            uint256 currentTokenPrice = newTradeAmount*1e18/_tradeAmount;
            uint256 tokenEntryPrice = (previousTokenPrice+currentTokenPrice)/2;



            tradeTokenById[tradeTokenId] = tradeToken(_tradeToken,tradeTokenAmount,tokenEntryPrice,0,Status.Ongoing);
            for(uint256 i=1;i<=membersOfPools;i++){
                    uint256 memberTradeShare =  (tradedToken.balanceOf(address(this)) * memberTokenBalance[memberAddress[i]]) / poolTokenAmount;
                    tradeTokenBalance[memberAddress[i]][tradeTokenId] += memberTradeShare;
                }
                poolTokenAmount-=_tradeAmount;

    }


}

contract PoolManager{

    uint256 public pools;
    mapping(uint256=>address) public poolbyId;
   
    function createPool(address _depositToken, uint256 _depositTokenAmount) public payable  {
        IERC20 depositToken = IERC20(_depositToken);
        require(depositToken.balanceOf(msg.sender)>=_depositTokenAmount,"Not Enough Amount");
        pools++;
        Pool newPool= new Pool(pools,msg.sender,_depositToken,_depositTokenAmount);
        depositToken.transferFrom(msg.sender, address(newPool), _depositTokenAmount);
        poolbyId[pools] = address(newPool);
    }

}

