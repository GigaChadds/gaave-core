// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interface/IGAAVECore.sol";
import "./interface/IWETHGateway.sol";
import "./interface/IPool.sol";

// import IERC20 from openzeppelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

import "./GAAVEPool.sol";

contract GAAVECore is IGAAVECore {
    // Maps campaignId to GAAVEPool
    mapping(uint256 => GAAVEPool) private campaigns;

    // Maps
    mapping(address => uint256) public campaignOwner;

    // pool address to user address to user info
    mapping(address => mapping(address => User)) public userInfo;

    // Maps token address to Chainlink Price Feed
    mapping(address => address) public tokenToPriceFeed;

    // To deposit ETH/MATIC
    IWETHGateway public WETH_GATEWAY;

    // To deposit token assets (USDT, DAI, USDC, AAVE, etc)
    IPool public AAVE_POOL;

    // Address for WETH
    address public WETH;
    address public AAVE_ETH_POOL = 0x6C9fB0D5bD9429eb9Cd96B85B81d872281771E6B;

    // Address for lib
    address public poolImplementationLib;

    // Address for tokens (DAI, MATIC)
    IERC20[] public tokenAddresses;

    // Address for ATokens (aDAI, aMATIC)
    IERC20[] public aTokenAddresses;

    uint256 public campaignId = 0;

    uint256 public badgeIdCounter = 0;

    constructor(
        IWETHGateway _WETH_GATEWAY,
        IPool _AAVE_POOL,
        address _WETH,
        address[] memory _tokenAddresses,
        address[] memory _ATokenAddresses,
        address[] memory _priceFeeds
    ) {
        require(
            _tokenAddresses.length == _priceFeeds.length,
            "GAAVECore: number of token addresses must match price feeds"
        );
        WETH_GATEWAY = _WETH_GATEWAY;
        WETH = _WETH;
        AAVE_POOL = _AAVE_POOL;
        tokenAddresses = _tokenAddresses;
        aTokenAddresses = _ATokenAddresses;

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            tokenToPriceFeed[_tokenAddresses[i]] = _priceFeeds[i];
        }

        // Create 1 Implementation, so that save gas on future clones
        GAAVEPool poolImplementation = new GAAVEPool();
        // init it so no one else can (RIP Parity Multisig)
        poolImplementation.init(address(this), msg.sender);
        poolImplementationLib = address(poolImplementation);
    }

    /**
     * @notice Deposit Crypto into a GAAVEPool
     * @param _campaignId The id of the specific campaign
     * @param _tokenAddress The address of the pool
     * @param _amount The amount of tokens to deposit
     */
    function deposit(
        uint256 _campaignId,
        address _tokenAddress,
        uint256 _amount
    ) external {
        // Get GAAVEPool from campaigns using _poolAddress
        GAAVEPool _poolAddress = campaigns[_campaignId];
        // Call Deposit Function of GAAVEPool

        _poolAddress.deposit(_tokenAddress, _amount, msg.sender);

        // Emit Event
        emit Deposited(msg.sender, _tokenAddress, _amount);
    }

    /**
     * @notice Withdraw Crypto from GAAVE
     * @param _campaignId The id of the specific campaign
     * @param _tokenAddress The address of the token to withdraw
     * @param _amount The amount of tokens to withdraw
     */
    function withdraw(
        uint256 _campaignId,
        address _tokenAddress,
        uint256 _amount
    ) external {
        // Get GAAVEPool address
        GAAVEPool _poolAddress = campaigns[_campaignId];

        // Call Withdraw Function of GAAVEPool
        _poolAddress.withdraw(_tokenAddress, _amount, msg.sender);

        // emit event
        emit Withdrawn(msg.sender, _tokenAddress, _amount);
    }

    /**
     * @notice Deposit ETH into GAAVE.
     * @param _campaignId the id of the specific campaign
     */
    function depositETH(uint256 _campaignId) external payable {
        // Get GAAVEPool from campaigns using _poolAddress
        GAAVEPool _poolAddress = campaigns[_campaignId];

        // Call depositETH Function of GAAVEPool
        _poolAddress.depositETH(msg.sender);

        // emit event
        emit DepositedETH(msg.sender, msg.value);
    }

    /**
     * @notice Withdraw ETH from GAAVE
     * @param _poolAddress The address of the pool.
     * @param _amount The amount of tokens to withdraw
     */
    function withdrawETH(uint256 _poolAddress, uint256 _amount) external {
        // Get GAAVEPool address
        GAAVEPool _poolAddress = campaigns[_campaignId];

        // Call Withdraw Function of GAAVEPool
        _poolAddress.withdraw(_tokenAddress, _amount, msg.sender);

        // emit event
        emit Withdrawn(msg.sender, WETH, _amount);
    }

    /**
     * @notice Claim badges from GAAVE
     * @return The address of the registered for the specified id
     */
    function claimBadge(uint256 _campaignId) external {
        _poolAddress.claimBadge(_campaignId, msg.sender);
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
            int256 price, /*uint startedAt*/ /*uint timeStamp*/ /*uint80 answeredInRound*/
            ,
            ,

        ) = priceFeed.latestRoundData();
        return uint256(price);
    }

    function getTokenToPriceFeed(address token)
        public
        view
        returns (address priceFeed)
    {
        priceFeed = tokenToPriceFeed[token];
    }

    function proposeCampaign(
        uint256[] memory _thresholds,
        string[] memory _cids
    ) external override {}

    function getCampaignCount() external view override returns (uint256) {}

    function deployPool(address _campaignOwner) internal returns (address) {
        require(
            campaignOwner[_campaignOwner] == 0,
            "GAAVECore: Owner already has an ongoing campaign!"
        );
        GAAVEPool pool = GAAVEPool(Clones.clone(poolImplementationLib));

        pool.init(
            address(this),
            campaignOwner,
            [badgeIdCounter, badgeIdCounter + 1]
        );
        badgeIdCounter += 2;
        campaignId += 1;
        campaignOwner[_campaignOwner] = campaignId;
        campaigns[campaignId] = pool;

        return address(pool);
    }
}
