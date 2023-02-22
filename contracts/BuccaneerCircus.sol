// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "openzeppelin/utils/math/SafeMath.sol";
import "openzeppelin/token/ERC721/extensions/ERC721Enumerable.sol";
import "openzeppelin/token/ERC721/extensions/ERC721Pausable.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/access/Ownable.sol";


contract BuccaneerCircus is ERC721Enumerable, Ownable {
    using SafeMath for uint256;

    modifier whenRunning() {
        require(isRunning, "not running");
        _;
    }

    /* This hash only exist for those who wants to checks metadata integrity */
    string public constant METADATA_SHA256_CHECKSUM = "8fd6b8de43d757e72137dcf36c0812011a5fdc768084329fbccc5146c1c61010";
    uint256 public constant PRICE_PER_ROVER = 100000000000000000; //0.1 ETH

    address public theCursedOneAddress;
    address public wantedCaptainsAddress;
    address public marquisBanquetAddress;

    uint256 public maxNumberOfRovers;
    bool public isRunning;

    string private baseTokenURI;

    constructor(uint256 _robersForMinting) ERC721("BuccaneerCircus", "XBC") {
        maxNumberOfRovers = _robersForMinting;
        isRunning = false;
    }

    /**
     * @dev Base URI for computing {tokenURI}. If set, the resulting URI for each
     * token will be the concatenation of the `baseURI` and the `tokenId`. Empty
     * by default, can be overriden in child contracts.
     */
    function _baseURI() internal view override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseTokenURI(string memory _baseTokenURI) public onlyOwner {
        baseTokenURI = _baseTokenURI;
    }

    function setupBaseContracts(
        address _theCursedOneAddress,
        address _wantedCaptainsAddress,
        address _teamWallet
    ) public onlyOwner {
        require(theCursedOneAddress == address(0), "addresses already setted up");
        require(_theCursedOneAddress != address(0), "address zero not allowed");
        require(_wantedCaptainsAddress != address(0), "address zero not allowed");
        require(_teamWallet != address(0), "address zero not allowed");

        theCursedOneAddress = _theCursedOneAddress;
        wantedCaptainsAddress = _wantedCaptainsAddress;

        /* First we have to mint the special tokens*/
        _mintRovers(_theCursedOneAddress, 1); // The Cursed One
        _mintRovers(_wantedCaptainsAddress, 10); // 10 Captains;
        _mintRovers(_teamWallet, 4); // 3 for team members and 1 for presenter

        maxNumberOfRovers += totalSupply();
    }

    function setMarquisBanquetContract(address _marquisBanquetAddress) public onlyOwner {
        require(_marquisBanquetAddress != address(0), "address zero not allowed");
        marquisBanquetAddress = _marquisBanquetAddress;
    }

    /**
     * @dev
     */
    function start() public onlyOwner {
        isRunning = true;
    }

    function _mintRovers(address to, uint256 amount) private {
        uint256 tokenId = totalSupply();
        uint256 nextAvailableId = tokenId + amount;

        for (; tokenId < nextAvailableId; tokenId++) {
            _safeMint(to, tokenId);
        }
    }

    /**
     * @dev Mint new Rovers
     */
    function mintRovers(uint256 amount) public payable whenRunning {
        require(amount <= 16, "you can only mint until 16 tokens per tx");
        require(totalSupply().add(amount) <= maxNumberOfRovers, "this tx exceeds max number of available tokens");
        require(PRICE_PER_ROVER.mul(amount) <= msg.value, "not enough Eth sent for this tx");

        _mintRovers(_msgSender(), amount);
    }

    /**
     * @dev Withdraw balance to the specified address
     */
    function withdraw(address to) public payable onlyOwner {
        require(marquisBanquetAddress != address(0), "contract not yet setted up");
        require(address(this).balance > 0, "no funds to withdraw");

        bool success;
        (success, ) = marquisBanquetAddress.call{value: (address(this).balance.div(100))}("");
        require(success, "marquis withdraw failed");

        (success, ) = to.call{value: address(this).balance}("");
        require(success, "withdraw failed");
    }

    /**
     * @dev 
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId) public view virtual override(ERC721Enumerable) returns (bool) {
        return super.supportsInterface(interfaceId);
    }
}