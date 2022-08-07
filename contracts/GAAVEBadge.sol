//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "hardhat/console.sol";

import "./interface/IGAAVEBadge.sol";

contract GAAVEBadge is ERC1155, Pausable, Ownable {
    // Contract name
    string public name;
    // Contract symbol
    string public symbol;

    mapping(uint256 => address) public creators;
    mapping(uint256 => uint256) public tokenSupply;

    mapping(uint256 => uint256) private _totalSupply;
    mapping(uint256 => string) private _tokenURIs;
    string private baseTokenURI;
    uint256 private _currentTokenID = 0;

    // ------------------------- EVENTS --------------------------

    // ----------------------- MODIFIERS -------------------------

    /**
     * @dev Require msg.sender to be the creator of the token id
     */
    modifier creatorOnly(uint256 _id) {
        require(
            creators[_id] == msg.sender,
            "GAAVEBadge: ONLY_CREATOR_ALLOWED"
        );
        _;
    }

    /**
     * @dev Require msg.sender to own more than 0 of the token id
     */
    modifier ownersOnly(uint256 _id) {
        require(
            balanceOf(msg.sender, _id) > 0,
            "GAAVEBadge: ONLY_OWNERS_ALLOWED"
        );
        _;
    }

    constructor(
        string memory _name,
        string memory _symbol,
        string memory baseURI,
        address owner
    ) ERC1155(baseURI) {
        name = _name;
        symbol = _symbol;
        setBaseMetadataURI(baseURI);
        transferOwnership(owner);
    }

    // ------------------------- VIEW FUNCTIONS ------------------------------

    /**
     * @dev Total amount of tokens in with a given id.
     */
    function totalSupply(uint256 id) public view returns (uint256) {
        return _totalSupply[id];
    }

    function uri(uint256 tokenId) public view override returns (string memory) {
        require(
            _exists(tokenId),
            "GAAVEBadge: URI query for nonexistent token"
        );

        string memory base = _baseURI();
        string memory _tokenURI = _tokenURIs[tokenId];

        return
            string(
                abi.encodePacked(
                    base,
                    _tokenURI,
                    Strings.toString(tokenId),
                    ".json"
                )
            );
    }

    // ------------------------- ADMIN FUNCTIONS ------------------------------

    /**
     * @dev Creates a new token type and assigns _initialSupply to an address
     * NOTE: remove onlyOwner if you want third parties to create new tokens on your contract (which may change your IDs)
     * @param _initialOwner address of the first owner of the token
     * @param _initialSupply amount to supply the first owner
     * @param _uri Optional URI for this token type
     * @param _data Data to pass if receiver is contract
     * @return The newly created token ID
     */
    function create(
        address _initialOwner,
        uint256 _initialSupply,
        string calldata _uri,
        bytes calldata _data
    ) external onlyOwner returns (uint256) {
        uint256 _id = _getNextTokenID();
        _incrementTokenTypeId();
        creators[_id] = msg.sender;

        if (bytes(_uri).length > 0) {
            _tokenURIs[_id] = _uri;
            emit URI(_uri, _id);
        }

        _mint(_initialOwner, _id, _initialSupply, _data);
        tokenSupply[_id] = _initialSupply;
        return _id;
    }

    /**
     * @dev Will update the base URL of token's URI
     * @param _newBaseMetadataURI New base URL of token's URI
     */
    function setBaseMetadataURI(string memory _newBaseMetadataURI)
        public
        onlyOwner
    {
        baseTokenURI = _newBaseMetadataURI;
    }

    /// @dev Will update the token URL of token's URI
    function setTokenURI(uint256 tokenId, string memory _newTokenURI)
        public
        onlyOwner
    {
        _tokenURIs[tokenId] = _newTokenURI;
    }

    /**
     * @dev Mints some amount of tokens to an address
     * @param _to          Address of the future owner of the token
     * @param _id          Token ID to mint
     * @param _quantity    Amount of tokens to mint
     * @param _data        Data to pass if receiver is contract
     */
    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public creatorOnly(_id) {
        _mint(_to, _id, _quantity, _data);
    }

    /**
     * @dev Mint tokens for each id in _ids
     * @param _to          The address to mint tokens to
     * @param _ids         Array of ids to mint
     * @param _quantities  Array of amounts of tokens to mint per id
     * @param _data        Data to pass if receiver is contract
     */
    function batchMint(
        address _to,
        uint256[] memory _ids,
        uint256[] memory _quantities,
        bytes memory _data
    ) public {
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 _id = _ids[i];
            require(
                creators[_id] == msg.sender,
                "GAAVEBadge: ONLY_CREATOR_ALLOWED"
            );
        }
        _mintBatch(_to, _ids, _quantities, _data);
    }

    /**
     * @dev Change the creator address for given tokens
     * @param _to   Address of the new creator
     * @param _ids  Array of Token IDs to change creator
     */
    function setCreator(address _to, uint256[] memory _ids) public {
        require(_to != address(0), "GAAVEBadge: INVALID_ADDRESS.");
        for (uint256 i = 0; i < _ids.length; i++) {
            uint256 id = _ids[i];
            _setCreator(_to, id);
        }
    }

    /**
     * @notice Airdrop
     * @param _addresses List of addresses
     */
    function airdrop(address[] memory _addresses, uint256 _id)
        external
        onlyOwner
    {
        for (uint256 i; i < _addresses.length; i++) {
            mint(_addresses[i], _id, 1, "0x00");
        }
    }

    // ------------------------- INTERNAL FUNCTIONS ------------------------------

    /**
     * @dev See {ERC1155-_mint}.
     */
    function _mint(
        address account,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) internal override {
        super._mint(account, id, amount, data);
        _totalSupply[id] += amount;
    }

    /**
     * @dev See {ERC1155-_mintBatch}.
     */
    function _mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._mintBatch(to, ids, amounts, data);
        for (uint256 i = 0; i < ids.length; ++i) {
            _totalSupply[ids[i]] += amounts[i];
        }
    }

    /// @dev Gets baseToken URI
    function _baseURI() internal view returns (string memory) {
        return baseTokenURI;
    }

    /**
     * @dev See {ERC1155-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);

        require(!paused(), "ERC1155Pausable: token transfer while paused");
    }

    /**
     * @dev Change the creator address for given token
     * @param _to   Address of the new creator
     * @param _id  Token IDs to change creator of
     */
    function _setCreator(address _to, uint256 _id) internal creatorOnly(_id) {
        creators[_id] = _to;
    }

    /**
     * @dev Returns whether the specified token exists by checking to see if it has a creator
     * @param _id uint256 ID of the token to query the existence of
     * @return bool whether the token exists
     */
    function _exists(uint256 _id) internal view returns (bool) {
        return creators[_id] != address(0);
    }

    // ------------------------- PRIVATE FUNCTIONS ------------------------------

    /**
     * @dev calculates the next token ID based on value of _currentTokenID
     * @return uint256 for the next token ID
     */
    function _getNextTokenID() private view returns (uint256) {
        return _currentTokenID + 1;
    }

    /**
     * @dev increments the value of _currentTokenID
     */
    function _incrementTokenTypeId() private {
        _currentTokenID++;
    }
}
