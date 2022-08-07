// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

import "./IPool.sol";
import "./IPoolAddressesProvider.sol";
import "./IWETHGateway.sol";

interface IGAAVECore {
    struct Campaign {
        uint256[] badgeIds;
        uint256[] thresholds;
    }

    struct User {
        uint256 amount;
        uint256 timeEntered;
        uint256 powerAccumulated;
    }

    event Deposited(
        address indexed _user,
        address indexed _tokenAddress,
        uint256 indexed _amount
    );
    event Withdrawn(
        address indexed _user,
        address indexed _tokenAddress,
        uint256 indexed _amount
    );
    event DepositedETH(address indexed _user, uint256 indexed _amount);
    event WithdrawnETH(address indexed _user, uint256 indexed _amount);
    event ClaimBadge(
        address indexed _user,
        uint256 indexed _id,
        address _address
    );
    event CampaignProposed(
        address _campaignAddress,
        uint256 _campaignId,
        uint256[] _thresholds
    );

    /**
     * @notice Deposit Crypto into GAAVE
     * @param _tokenAddress The address of the token to deposit
     * @param _amount The amount of tokens to deposit
     */
    function deposit(address _tokenAddress, uint256 _amount) external;

    /**
     * @notice Withdraw Crypto from GAAVE
     * @param _tokenAddress The address of the token to withdraw
     * @param _amount The amount of tokens to withdraw
     */
    function withdraw(address _tokenAddress, uint256 _amount) external;

    /**
     * @notice Deposit ETH into GAAVE
     * @param _amount The amount of tokens to deposit
     */
    function depositETH(uint256 _amount) external payable;

    /**
     * @notice Withdraw ETH from GAAVE
     * @param _amount The amount of tokens to withdraw
     */
    function withdrawETH(uint256 _amount) external;

    /**
     * @notice Claim badges from GAAVE
     * @param _campaignId The id of the campaign to claim from
     * @param _milestone The milestone of the reward
     * @return The address of the registered for the specified id
     */
    function claimBadge(uint256 _campaignId, uint256 _milestone) external;

    function proposeCampaign(uint256[] _thresholds, string[] memory _cids)
        external;

    function getCampaignCount() external view returns (uint256);
}
