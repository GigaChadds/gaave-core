// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interface/IGAAVECore.sol";
import "./interface/IWETHGateway.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract GAAVECore is IGAAVECore {
    mapping(uint256 => Campaign) public campaigns;

    // campaign id to user address to user info
    mapping(uint256 => mapping(address => User)) public userInfo;
    mapping(address => mapping(address => uint256)) public averagePrice;
    mapping(address => address) public tokenToPriceFeed;
    mapping(address => mapping(address => uint256)) public balances;
    IWETHGateway public WETH_GATEWAY;
    IPool public AAVE_POOL;
    address ETH_PRICE = 0x0715A7794a1dc8e42615F059dD6e406A6594651A;
    address ETH_ADDRESS =;
    constructor(
        IWETHGateway _WETH_GATEWAY,
        IPool _AAVE_POOL,
        address[] memory _tokenAddresses,
        address[] memory _priceFeeds
    ) public {
        require(
            _tokenAddresses.length == _priceFeeds.length,
            "GAAVECore: number of token addresses must match price feeds"
        );
        WETH_GATEWAY = _WETH_GATEWAY;
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
        // Transfer tokens from user to GAAVE
        IERC20(_tokenAddress).transferFrom(
            msg.sender,
            address(this),
            _amount
        );

        User storage user = userInfo[_campaignId][msg.sender];
        uint256 balance = balances[msg.sender][_tokenAddress];
        uint256 timestamp = block.timestamp;
        uint256 price = getLatestPrice(tokenToPriceFeed[_tokenAddress]);
        uint256 lastPrice = averagePrice[msg.sender][_tokenAddress];
        // if this is user's first time depositing this token, set powerAccumulated to 0,
        // log amount and timestamp
        if (balance == 0) {
            balances[msg.sender][_tokenAddress] = _amount;
            user.powerAccumulated = 0;
            averagePrice[msg.sender][_tokenAddress] = price;
        } else {
            // else, retrieve already accumulated power and reset timestamp to current timestamp
            user.powerAccumulated += powerAccumulated(
                _campaignId,
                msg.sender,
                _tokenAddress
            );
            balances[msg.sender][_tokenAddress] +=  _amount;
            averagePrice[msg.sender][_tokenAddress] = (price + lastPrice) /2;
        }
        
        user.timeEntered = timestamp;

        // deposit to AAVE and lend
        AAVE_POOL.deposit(_tokenAddress, _amount, address(this), 0);

        // emit event
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
        uint256 balance = balances[msg.sender][_tokenAddress];
        require(
            balance >= _amount,
            "GAAVECore: Withdraw amount more than existing amount"
        );

        uint256 price = getLatestPrice(tokenToPriceFeed[_tokenAddress]);
        uint256 lastPrice = averagePrice[msg.sender][_tokenAddress];
        // withdraw from AAVE
        AAVE_POOL.withdraw(_tokenAddress, _amount, msg.sender);
        uint256 timestamp = block.timestamp;
        user.powerAccumulated += powerAccumulated(_campaignId, msg.sender, _tokenAddress);
        balances[msg.sender][_tokenAddress] -= _amount;
        user.timeEntered = timestamp;

        // emit event
    }

    /**
     * @notice Deposit ETH into GAAVE
     * @param _amount The amount of tokens to deposit
     */
    function deposit() external payable {
        // Transfer ETH from user to GAAVE
        require(msg.value > 0,"GAAVECore: 0 ETH received");
        _WETH_GATEWAY.depositETH(AAVE_POOL, address(this), 0){value: msg.value};
        uint256 balance = balances[msg.sender][ETH_ADDRESS];
        User storage user = userInfo[_campaignId][msg.sender];
        uint256 timestamp = block.timestamp;
        uint256 price = getLatestPrice(ETH_PRICE);
        uint256 lastPrice = averagePrice[msg.sender][ETH_ADDRESS];
          if (balance == 0) {
            balances[msg.sender][ETH_ADDRESS] = _amount;
          
            user.powerAccumulated = 0;
            averagePrice[msg.sender][_tokenAddress] = price;
        } else {
            // else, retrieve already accumulated power and reset timestamp to current timestamp
            user.powerAccumulated += powerAccumulated(
                _campaignId,
                msg.sender,
                _tokenAddress
            );
            balances[msg.sender][ETH_ADDRESS] += _amount;
            averagePrice[msg.sender][_tokenAddress] = (price + lastPrice) /2;
        }
         user.timeEntered = timestamp;
    }

    /**
     * @notice Withdraw ETH from GAAVE
     * @param _amount The amount of tokens to withdraw
     */
    function withdraw(uint256 _amount) external {
        require
        
    }

    /**
     * @notice Claim badges from GAAVE
     * @return The address of the registered for the specified id
     */
    function claimBadge() external {}

    function powerAccumulated(
        uint256 _campaignId,
        address _user,
        address _tokenAddress
    ) public view returns (uint256) {
        User memory user = userInfo[_campaignId][_user];
        return
            user.powerAccumulated +
            (user.amount *
                getLatestPrice(tokenToPriceFeed[_tokenAddress])(
                    block.timestamp - user.timeEntered
                ));
    }

    /**
     * @notice Calculate the value of deposit based on the token's address
     * @return The value of the token in USD
     */

    function getLatestPrice(address _priceFeed) public view returns (uint256) {
        AggregatorV3Interface priceFeed = AggregatorV3Interface(_priceFeed);
        (
            ,
            /*uint80 roundID*/
            uint256 price, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();
        return uint256(price);
    }
}
