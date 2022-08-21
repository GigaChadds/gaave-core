// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interface/IWooshCore.sol";
import "./interface/IPool.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract WooshCore is IWooshCore {
    // To deposit token assets (USDT, DAI, USDC, AAVE, etc)
    IPool public AAVE_POOL = IPool(0x6C9fB0D5bD9429eb9Cd96B85B81d872281771E6B);

    // Address for WETH
    IERC20 public DAI = IERC20(0x9A753f0F7886C9fbF63cF59D0D4423C5eFaCE95B);
    IERC20 public ADAI = IERC20(0xDD4f3Ee61466C4158D394d57f3D4C397E91fBc51);

    constructor() {}

    /**
     * @notice Deposit DAI into AAVE
     */
    function startloanDAI() external {
        // Get balance of aDAI of user
        uint256 _amount = DAI.balanceOf(msg.sender);

        AAVE_POOL.deposit(address(DAI), _amount, msg.sender, 0);

        // Emit Event
        emit StartLoaning(msg.sender, address(DAI), _amount);
    }

    /**
     * @notice Withdraw DAI from AAVE
     */
    function stopLoanDAI() external {
        // Get balance of aDAI of user
        uint256 _amount = ADAI.balanceOf(msg.sender);

        // Call Withdraw Function of GAAVEPool
        AAVE_POOL.withdraw(address(DAI), _amount, msg.sender);

        // emit event
        emit StopLoaning(msg.sender, address(DAI), _amount);
    }
}
