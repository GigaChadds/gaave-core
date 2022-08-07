// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;

// import erc1155 interface
import "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";

interface IGAAVEBadge is IERC1155 {
    function airdrop(address[] memory _addresses, uint256 _id) external;
}
