// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interface/IGAAVECore.sol";
import "./interface/IWETHGateway.sol";
import "./interface/IPool.sol";

// import IERC20 from openzeppelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GAAVECore is IGAAVECore {
    // Maps campaignId to Campaign
    mapping(uint256 => Campaign) private campaigns;

    // campaign id to user address to user info
    mapping(uint256 => mapping(address => User)) public userInfo;

    // Maps token address to Chainlink Price Feed
    mapping(address => address) public tokenToPriceFeed;

    // To deposit ETH/MATIC
    IWETHGateway public WETH_GATEWAY;

    // To deposit token assets (USDT, DAI, USDC, AAVE, etc)
    IPool public AAVE_POOL;

    // Address for WETH
    address public WETH;

    constructor(
        IWETHGateway _WETH_GATEWAY,
        IPool _AAVE_POOL,
        address _WETH,
        address[] memory _tokenAddresses,
        address[] memory _priceFeeds
    ) {
        require(
            _tokenAddresses.length == _priceFeeds.length,
            "GAAVECore: number of token addresses must match price feeds"
        );
        WETH_GATEWAY = _WETH_GATEWAY;
        WETH = _WETH;
        AAVE_POOL = _AAVE_POOL;

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            tokenToPriceFeed[_tokenAddresses[i]] = _priceFeeds[i];
        }
    }

    /**
     * @notice Deposit Crypto into GAAVE
     * @param _tokenAddress The address of the token to deposit
     * @param _amount The amount of tokens to deposit
     */
    function deposit(
        uint256 _campaignId,
        address _tokenAddress,
        uint256 _amount
    ) external {
        User storage user = userInfo[_campaignId][msg.sender];
        uint256 timestamp = block.timestamp;
        uint256 currentPrice = getLatestPrice(tokenToPriceFeed[_tokenAddress]);
        // if this is user's first time depositing this token, set powerAccumulated to 0,
        // log amount and timestamp
        if (user.tokenAmount[_tokenAddress] == 0) {
            user.powerAccumulated = 0;
            user.tokenAmount[_tokenAddress] = uint256(_amount);
            user.lastPrice[_tokenAddress] = currentPrice;
            user.timeEntered = timestamp;
        } else {
            // else, retrieve already accumulated power and reset timestamp to current timestamp
            // Power = currentAmount * (prevPrice + currentPrice) / 2 * (currentTimestamp - startTimestamp)
            user.powerAccumulated +=
                ((user.tokenAmount[_tokenAddress] *
                    (currentPrice + user.lastPrice[_tokenAddress])) / 2) *
                (timestamp - user.timeEntered);
            user.tokenAmount[_tokenAddress] += _amount; // Update Token Deposited
            user.timeEntered = timestamp; // Update Time Entered
            user.lastPrice[_tokenAddress] = currentPrice; // Update Last Entry Price of current token
        }

        // Deposit to AAVE and lend
        AAVE_POOL.deposit(_tokenAddress, _amount, address(this), 0);

        // Emit Event
        emit Deposited(msg.sender, _tokenAddress, _amount);
    }

    /**
     * @notice Withdraw Crypto from GAAVE
     * @param _tokenAddress The address of the token to withdraw
     * @param _amount The amount of tokens to withdraw
     */
    function withdraw(
        uint256 _campaignId,
        address _tokenAddress,
        uint256 _amount
    ) external {
        User storage user = userInfo[_campaignId][msg.sender];
        require(
            user.tokenAmount[_tokenAddress] > _amount,
            "GAAVECore: Withdraw amount more than existing amount"
        );
        uint256 currentPrice = getLatestPrice(tokenToPriceFeed[_tokenAddress]);
        // withdraw from AAVE
        AAVE_POOL.withdraw(_tokenAddress, _amount, msg.sender);
        uint256 timestamp = block.timestamp;
        user.powerAccumulated +=
            ((user.tokenAmount[_tokenAddress] *
                (currentPrice + user.lastPrice[_tokenAddress])) / 2) *
            (timestamp - user.timeEntered);
        user.tokenAmount[_tokenAddress] -= _amount; // Update Token Deposited
        user.timeEntered = timestamp;

        // emit event
        emit Withdrawn(msg.sender, _tokenAddress, _amount);
    }

    /**
     * @notice Deposit ETH into GAAVE
     */
    function depositETH(uint256 _campaignId) external payable {
        User storage user = userInfo[_campaignId][msg.sender];
        uint256 timestamp = block.timestamp;
        uint256 currentPrice = getLatestPrice(tokenToPriceFeed[WETH]);
        // if this is user's first time depositing this token, set powerAccumulated to 0,
        // log amount and timestamp
        if (user.ethAmount == 0) {
            user.powerAccumulated = 0;
            user.ethAmount = uint256(msg.value);
            user.lastPrice[WETH] = currentPrice;
            user.timeEntered = timestamp;
        } else {
            // else, retrieve already accumulated power and reset timestamp to current timestamp
            // Power = currentAmount * (prevPrice + currentPrice) / 2 * (currentTimestamp - startTimestamp)
            user.powerAccumulated +=
                ((user.ethAmount * (currentPrice + user.lastPrice[WETH])) / 2) *
                (timestamp - user.timeEntered);
            user.ethAmount += msg.value; // Update Token Deposited
            user.timeEntered = timestamp; // Update Time Entered
            user.lastPrice[WETH] = currentPrice; // Update Last Entry Price of current token
        }
        // Transfer ETH from user to GAAVE
        WETH_GATEWAY.depositETH{value: msg.value}(
            0x6C9fB0D5bD9429eb9Cd96B85B81d872281771E6B,
            address(this),
            0
        );
        emit DepositedETH(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw ETH from GAAVE
     * @param _amount The amount of tokens to withdraw
     */
    function withdrawETH(uint256 _amount) external {}

    /**
     * @notice Claim badges from GAAVE
     * @return The address of the registered for the specified id
     */
    function claimBadge() external returns (uint256) {}

    /**
     * @notice Calculate the value of deposit based on the token's address
     * @return The value of the token in USD
     */

    function getLatestPrice(address _priceFeed) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (
            ,
            /*uint80 roundID*/
            int256 price, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function deposit(address _tokenAddress, uint256 _amount)
        external
        override
    {}

    function withdraw(address _tokenAddress, uint256 _amount)
        external
        override
    {}

    function claimBadge(uint256 _campaignId, uint256 _milestone)
        external
        override
    {}

    function proposeCampaign(
        uint256[] memory _thresholds,
        string[] memory _cids
    ) external override {}

    function getCampaignCount() external view override returns (uint256) {}
}
