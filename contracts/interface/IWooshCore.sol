// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

interface IWooshCore {
    event StartLoaning(
        address indexed user,
        address indexed token,
        uint256 amount
    );
    event StopLoaning(
        address indexed user,
        address indexed token,
        uint256 amount
    );

    function startloanDAI() external;

    function stopLoanDAI() external;
}
