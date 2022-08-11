// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./interface/IGAAVECore.sol";
import "./interface/IWETHGateway.sol";
import "./interface/IGAAVEBadge.sol";
import "./interface/IPool.sol";

// import IERC20 from openzeppelin
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
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

    // Address for ERC1155
    IGAAVEBadge public GAAVEBadge;

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
        IERC20[] memory _tokenAddresses,
        IERC20[] memory _ATokenAddresses,
        address[] memory _priceFeeds,
        IGAAVEBadge _GAAVEBadge
    ) {
        require(
            _tokenAddresses.length == _priceFeeds.length,
            "GAAVECore: number of token addresses must match price feeds"
        );
        WETH_GATEWAY = _WETH_GATEWAY;
        WETH = _WETH;
        AAVE_POOL = _AAVE_POOL;
        GAAVEBadge = _GAAVEBadge;
        tokenAddresses = _tokenAddresses;
        aTokenAddresses = _ATokenAddresses;

        for (uint256 i = 0; i < _tokenAddresses.length; i++) {
            tokenToPriceFeed[address(_tokenAddresses[i])] = _priceFeeds[i];
        }

        // Create 1 Implementation, so that save gas on future clones
        GAAVEPool poolImplementation = new GAAVEPool();

        uint256[] memory _badgeIds = new uint256[](2);
        _badgeIds[0] = 0;
        _badgeIds[1] = 1;

        poolImplementation.init(
            address(this),
            msg.sender,
            address(GAAVEBadge),
            _badgeIds
        );
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
     * @param _campaignId Pool Id
     * @param _amount The amount of tokens to withdraw
     */
    function withdrawETH(uint256 _campaignId, uint256 _amount) external {
        // Get GAAVEPool address
        GAAVEPool _poolAddress = campaigns[_campaignId];

        // Call Withdraw Function of GAAVEPool
        _poolAddress.withdrawETH(_amount, msg.sender);

        // emit event
        emit Withdrawn(msg.sender, WETH, _amount);
    }

    function claimableETH(uint256 _campaignId) external view returns (uint256) {
        GAAVEPool pool = campaigns[_campaignId];
        return pool.claimableETH();
    }

    function claimableToken(uint256 _campaignId, address _tokenAddress)
        external
        view
        returns (uint256)
    {
        GAAVEPool pool = campaigns[_campaignId];
        return pool.claimableToken(IERC20(_tokenAddress));
    }

    /**
     * @notice Claim badges from GAAVE
     */
    function claimBadge(uint256 _campaignId) external {
        // Get token ids eligible for claim
        uint256[] memory _eligibleBadges = campaigns[_campaignId].canClaim(
            msg.sender
        );

        // Loop through eligible badges
        for (uint256 i = 0; i < _eligibleBadges.length; i++) {
            if (GAAVEBadge.balanceOf(msg.sender, _eligibleBadges[i]) == 0) {
                // Mint Badges for each eligible token id
                GAAVEBadge.mint(msg.sender, _eligibleBadges[i], 1, "");
            }
        }
    }

    /**
     * @notice Check if the claimant is eligible for badge id
     */
    function canClaim(uint256 _campaignId, address _claimant)
        public
        view
        returns (uint256[] memory eligibleBadges)
    {
        campaigns[_campaignId].canClaim(_claimant);
    }

    function getSupporterBalance(
        uint256 _campaignId,
        address _supporter,
        address _tokenAddress
    ) external view returns (uint256) {
        GAAVEPool pool = campaigns[_campaignId];
        uint256 result = pool.getSupporterTokenBalance(
            _supporter,
            _tokenAddress
        );
        return result;
    }

    function getSupporterETHBalance(uint256 _campaignId, address _supporter)
        external
        view
        returns (uint256)
    {
        GAAVEPool pool = campaigns[_campaignId];
        uint256 result = pool.getSupporterETHBalance(_supporter);
        return result;
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

    function deployPool() external returns (address) {
        require(
            campaignOwner[msg.sender] == 0,
            "GAAVECore: Owner already has an ongoing campaign!"
        );
        GAAVEPool pool = GAAVEPool(Clones.clone(poolImplementationLib));

        uint256[] memory _badgeIds = new uint256[](2);
        _badgeIds[0] = badgeIdCounter;
        _badgeIds[1] = badgeIdCounter + 1;

        pool.init(address(this), msg.sender, address(GAAVEBadge), _badgeIds);
        badgeIdCounter += 2;
        campaignId += 1;
        campaignOwner[msg.sender] = campaignId;
        campaigns[campaignId] = pool;

        return address(pool);
    }

    function getTokenAddress(uint256 index) public view returns (IERC20) {
        return tokenAddresses[index];
    }
}
