// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interface/IGAAVECore.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract GAAVECore is IGAAVECore {
    mapping(uint256 => Campaign) public campaigns;

    // campaign id to user address to user info
    mapping(uint256 => mapping(address => User)) public userInfo;


    mapping(address => address) public tokenToPriceFeed;
    IWETHGateway public WETH_GATEWAY;
    IPool public AAVE_POOL;

    constructor(IWETHGateway _WETH_GATEWAY, IPool _AAVE_POOL, address[] _tokenAddresses, address[] _priceFeeds) public {
        require(_tokenAddresses.length == _priceFeeds.length, "GAAVECore: number of token addresses must match price feeds");
        WETH_GATEWAY = _WETH_GATEWAY;
        AAVE_POOL = _AAVE_POOL;

        for(uint256 = 0; i< _tokenAddresses.length; i++){
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
        // Transfer tokens from user to GAAVE
        IERC20(_tokenAddress).safeTransferFrom(
            msg.sender,
            address(this),
            _amount
        );

        User storage user = userInfo[_campaignId][msg.sender];
        uint256 timestamp = block.timestamp;
        uint price = getLatestPrice(tokenToPriceFeed[_tokenAddress]);
        // if this is user's first time depositing this token, set powerAccumulated to 0,
        // log amount and timestamp
        if (user.amount == 0) {
            user = User(price*_amount, timestamp, 0);
        } else {
            // else, retrieve already accumulated power and reset timestamp to current timestamp
            user.power += powerAccumulated(_campaignId, msg.sender, _tokenAddress);
            user.amount += price*_amount;
            user.timeEntered = timestamp;
        }

        // deposit to AAVE and lend
        AAVE_POOL.deposit(_tokenAddress, _amount, address(this), 0);

        // emit ev
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
            user.amount >= _amount,
            "GAAVECore: Withdraw amount more than existing amount"
        );
        uint price = getLatestPrice(tokenToPriceFeed[_tokenAddress]);
        // withdraw from AAVE
        AAVE_POOL.withdraw(_tokenAddress, _amount, msg.sender);
        uint256 timestamp = block.timestamp;
        user.power += powerAccumulated(_campaignId, msg.sender, _tokenAddress);
        user.amount -= price * _amount;
        user.timeEntered = timestamp;

        // emit event
    }

    /**
     * @notice Deposit ETH into GAAVE
     * @param _amount The amount of tokens to deposit
     */
    function deposit(uint256 _amount) external payable {
        // Transfer ETH from user to GAAVE
        require(msg.sender.call{value: _amount}(""));
    }

    /**
     * @notice Withdraw ETH from GAAVE
     * @param _amount The amount of tokens to withdraw
     */
    function withdraw(uint256 _amount) external {}

    /**
     * @notice Claim badges from GAAVE
     * @return The address of the registered for the specified id
     */
    function claimBadge() external {}

    function powerAccumulated(uint256 _campaignId, address _user, address _tokenAddress)
        public
        view
        returns (uint256)
    {
        User memory user = userInfo[_campaignId][_user];
        return
            user.powerAccumulated +
            (user.amount * getLatestPrice(tokenToPriceFeed[_tokenAddress]) (block.timestamp - user.timeEntered));
    }

    /**
     * @notice Calculate the value of deposit based on the token's address
     * @return The value of the token in USD
     */

    function getLatestPrice(address _priceFeed) public view returns (int) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (
            /*uint80 roundID*/,
            int price,
            /*uint startedAt*/,
            /*uint timeStamp*/,
            /*uint80 answeredInRound*/
        ) = priceFeed.latestRoundData();
        return price;
    }
