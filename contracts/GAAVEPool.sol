// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./GAAVECore.sol";
// Import openzeppelin IERC1155
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

/// @notice Contract Logic for GAAVE Pool
/// @dev This contract is used to manage the GAAVE Pools which is spawned everytime a beneficiary creates a campaign
contract GAAVEPool {
    address public poolOwner; // The Beneficiary of the pool
    GAAVECore public CORE;

    IERC1155 public badge;
    // supporter => User
    mapping(address => User) public supporters;
    // total staked amount
    uint256 internal totalStake;

    struct Campaign {
        uint256[] badgeIds;
        uint256[] thresholds;
    }

    Campaign public campaign;

    /**
     * @notice Check if the claimant is eligible for badge id
     */
    function canClaim(address _claimant)
        public
        view
        returns (uint256[] eligibleBadges)
    {
        uint256[] eligibleBadges = [];

        Campaign storage campaign = this.campaign;

        for (
            uint256 i = 0;
            i < campaign.badgeIds.length;
            i++
        ) {
            if (
                supporters[_claimant].powerAccumulated
             >= campaign.thresholds[i]
            ) {
                eligibleBadges.push(campaign.badgeIds[i]);
            }
        }
        return eligibleBadges;
    }

    struct User {
        mapping(address => uint256) tokenAmount;
        mapping(address => uint256) lastPrice;
        uint256 ethAmount;
        uint256 timeEntered;
        uint256 powerAccumulated;
    }

    mapping(address => uint256) public totalTokenAmount;
    uint256 public totalEthAmount;

    modifier onlyCore() {
        require(msg.sender == address(CORE), "GAAVEPool: Only GAAVECore!");
        _;
    }

    function init(
        address _CORE,
        address _poolOwner,
        uint256[] _badgeIds
    ) public {
        require(poolOwner == address(0), "GAAVEPool: Already initialized");

        CORE = GAAVECore(_CORE);
        poolOwner = _poolOwner;
        badge = IERC1155(_badge);

        campaign = new Campaign(_badgeIds, [10 ether, 100 ether]);
    }

    /**
     * @notice Deposit token into pool
     * @param _tokenAddress Token Address
     * @param _amount Amount of tokens to deposit
     * @param _supporter Address of the supporter
     */
    function deposit(
        address _tokenAddress,
        uint256 _amount,
        address _supporter
    ) public onlyCore returns (uint256) {
        // Get User from storage
        User storage user = supporters[_supporter];

        // Get timestamp
        uint256 timestamp = block.timestamp;

        // Get current price of token
        uint256 currentPrice = CORE.getLatestPrice(
            CORE.getTokenToPriceFeed(_tokenAddress)
        );

        // Deposit token into AAVE
        CORE.AAVE_POOL().deposit(_tokenAddress, _amount, address(this), 0);

        // if this is user's first time depositing this token, set powerAccumulated to 0,
        // log amount and timestamp
        if (user.tokenAmount[_tokenAddress] == 0) {
            user.powerAccumulated = 0;
            user.tokenAmount[_tokenAddress] = uint256(msg.value);
            user.lastPrice[CORE.WETH()] = currentPrice;
            user.timeEntered = timestamp;
        } else {
            // else, retrieve already accumulated power and reset timestamp to current timestamp
            // Power = currentAmount * (prevPrice + currentPrice) / 2 * (currentTimestamp - startTimestamp)
            user.powerAccumulated +=
                ((user.tokenAmount[_tokenAddress] *
                    (currentPrice + user.lastPrice[_tokenAddress])) / 2) *
                (timestamp - user.timeEntered);
            user.tokenAmount[_tokenAddress] += msg.value; // Update Token Deposited
            user.timeEntered = timestamp; // Update Time Entered
            user.lastPrice[CORE.WETH()] = currentPrice; // Update Last Entry Price of current token
        }

        // Update total staked amount
        totalTokenAmount[_tokenAddress] += _amount;

        return _amount;
    }

    /**
     * @notice Withdraw token from pool
     * @param _tokenAddress Token Address
     * @param _amount Amount of tokens to deposit
     * @param _supporter Address of the supporter
     */
    function withdraw(
        address _tokenAddress,
        uint256 _amount,
        address _supporter
    ) public onlyCore returns (uint256) {
        User storage user = supporters[_supporter];
        require(
            user.tokenAmount[_tokenAddress] > _amount,
            "GAAVECore: Withdraw amount more than existing amount"
        );
        uint256 currentPrice = CORE.getLatestPrice(
            CORE.getTokenToPriceFeed(_tokenAddress)
        );
        // withdraw from AAVE
        CORE.AAVE_POOL().withdraw(_tokenAddress, _amount, msg.sender);
        uint256 timestamp = block.timestamp;
        user.powerAccumulated +=
            ((user.tokenAmount[_tokenAddress] *
                (currentPrice + user.lastPrice[_tokenAddress])) / 2) *
            (timestamp - user.timeEntered);
        user.tokenAmount[_tokenAddress] -= _amount; // Update Token Deposited
        user.timeEntered = timestamp;
        // emit event

        // Update total staked amount
        totalTokenAmount[_tokenAddress] -= _amount;

        return _amount;
    }

    // Stakes the sent ether, registering the caller as a supporter.
    function depositETH(address supporter)
        public
        payable
        onlyCore
        returns (uint256)
    {
        uint256 amount = msg.value;

        User storage user = supporters[supporter];
        uint256 timestamp = block.timestamp;
        uint256 currentPrice = CORE.getLatestPrice(
            CORE.getTokenToPriceFeed(CORE.WETH())
        );

        CORE.WETH_GATEWAY().depositETH{value: amount}(
            CORE.AAVE_ETH_POOL(),
            address(this),
            0
        );

        // if this is user's first time depositing this token, set powerAccumulated to 0,
        // log amount and timestamp
        if (user.ethAmount == 0) {
            user.powerAccumulated = 0;
            user.ethAmount = uint256(msg.value);
            user.lastPrice[CORE.WETH()] = currentPrice;
            user.timeEntered = timestamp;
        } else {
            // else, retrieve already accumulated power and reset timestamp to current timestamp
            // Power = currentAmount * (prevPrice + currentPrice) / 2 * (currentTimestamp - startTimestamp)
            user.powerAccumulated +=
                ((user.ethAmount *
                    (currentPrice + user.lastPrice[CORE.WETH()])) / 2) *
                (timestamp - user.timeEntered);
            user.ethAmount += msg.value; // Update Token Deposited
            user.timeEntered = timestamp; // Update Time Entered
            user.lastPrice[CORE.WETH()] = currentPrice; // Update Last Entry Price of current token
        }

        // Update total staked amount
        totalEthAmount += amount;

        return amount;
    }

    // Unstakes all previously staked ether by the calling supporter.
    // The poolOwner keeps all generated yield.
    function withdrawETH(uint256 _amount, address supporter)
        public
        onlyCore
        returns (uint256)
    {
        User storage user = supporters[supporter];
        require(
            user.ethAmount > _amount,
            "GAAVECore: Withdraw amount more than existing amount"
        );
        uint256 currentPrice = CORE.getLatestPrice(
            CORE.getTokenToPriceFeed(CORE.WETH())
        );
        // withdraw from AAVE
        CORE.WETH_GATEWAY().withdrawETH(CORE.WETH(), _amount, msg.sender);
        uint256 timestamp = block.timestamp;
        user.powerAccumulated +=
            ((user.ethAmount * (currentPrice + user.lastPrice[CORE.WETH()])) /
                2) *
            (timestamp - user.timeEntered);
        user.ethAmount -= _amount; // Update Token Deposited
        user.timeEntered = timestamp;

        // Update total staked amount
        totalEthAmount -= _amount;

        return _amount;
    }

    // @notice claim sends the accrued interest to the poolOwner of this pool. The
    // stake remains at the yield pool and continues generating yield.
    function claim() public onlyCore returns (uint256) {
        uint256 amount = claimableETH();
        withdraw(amount, poolOwner);
        return amount;
    }

    // claimableETH returns the total earned ether by the provided poolOwner.
    // It is the accrued interest on all staked ether.
    // It can be withdrawn by the poolOwner with claim.
    function claimableETH() public view returns (uint256) {
        return CORE.token().balanceOf(address(this)) - staked();
    }

    /**
     * @notice Transfer all yield farmed to the poolOwner
     */
    function claimAll() public onlyCore returns (uint256) {
        // Transfer ETH

        // Transfer Tokens
        uint256 amount = claimableETH();
        withdraw(amount, poolOwner);
        return amount;
    }

    function calculateYield() public view returns (uint256 value) {
        // Calculate WETH tokens
        uint256 amountETHYield = CORE.tokenAddresses[1].balanceOf(
            address(this)
        );

        // minus WETH deposited
        amountETHYield -= stakedETH();
        uint256 currentPriceETH = CORE.getLatestPrice(
            CORE.getTokenToPriceFeed(CORE.tokenAddresses[1])
        );

        value = (amountETHYield * currentPriceETH) / 10**18;

        // Calculate DAI in USD Value
        uint256 amount = CORE.tokenAddresses[0].balanceOf(address(this));
        amount -= staked();
        uint256 currentPrice = CORE.getLatestPrice(
            CORE.getTokenToPriceFeed(CORE.tokenAddresses[0])
        );

        value += (amount * currentPrice) / 10**18;
    }

    // staked returns the total staked ether by this poolOwner pool.
    function stakedETH() public view returns (uint256) {
        return totalEthAmount;
    }

    // Amount of tokens staked on the contract
    function staked(address tokenAddress) public view returns (uint256) {
        return totalTokenAmount[tokenAddress];
    }

    // claim erc1155 achievement badges
    function claimBadges(uint256 _campaignId, address _supporter) external {
        // badge.
    }

    function getUserClaimableBadges() external view {
        // thresholds
        if reach threshold 
    }
}
