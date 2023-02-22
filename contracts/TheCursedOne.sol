// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/IERC721.sol";
import "openzeppelin/token/ERC721/IERC721Receiver.sol";


contract TheCursedOne is Ownable, IERC721Receiver {
    
    IERC721 mainContract;

    mapping(uint256 => bytes32[]) private groupHashes;
    mapping(bytes32 => uint256) private hashGroup;

    mapping(address => mapping(uint256 => uint256)) private seenTokens;

    bool public claimed;

    constructor() {
        addGroupHash(1, 0x0a00dce89905967eb1ae59b9759a9b3b8f4a4c8214a949a993459d3513468adc);
        addGroupHash(1, 0x34bf5c7bc9e83fe52d8b798df034cdfe51b198a1a4f91e30029d13db68dd0615);
        addGroupHash(1, 0x5041a7ddb7c6623a0351a9326672f42daf787a8f9510284e3cb143ca771c9a5f);
        addGroupHash(1, 0xaa735a24e218b065b1b0a81149068abbb8774400f6abdaff6bd90e7bb6addd2c);
        addGroupHash(2, 0x48ec22f2a4d8c041d913e59e68ff3b02906102b6f9dfa9efc0c6650b585a15e2);
        addGroupHash(2, 0x647f67b7b8323bbbe8bfd16b7bd511108fa0a6bf524d1b5d5bf30e38502756fd);
        addGroupHash(2, 0x8ed66c288948443721a3ae30fefd80d4be943051769ead7ee91a5d978f2c7932);
        addGroupHash(2, 0xf2d4b576b4e44c244ba77349462cb5a0d6ca4faee3dd09f84c7a103e9c2ad195);
        addGroupHash(3, 0x34ffb49b0e126804e9032b649821ba0dd13b1513e3d09cd40345e22032deeb61);
        addGroupHash(3, 0x8f907b1b60ecd888d687e891900a975ce9819ad9d20f2a24d79067c62c2387ad);
        addGroupHash(3, 0xb5e8b7e2014660b9aea28d021914610aebf4295e1394108fedba0818874fe3db);
        addGroupHash(3, 0xf271511f4426e95bd79bb66a2ea25fb6f2def455cd5ae12e14bb33919f7996c4);
        addGroupHash(4, 0x0d15864a29799f314a3ffa7f6e73f20ee66adce5a041baa4ab340822917f416f);
        addGroupHash(4, 0x1dc966496e8450575a26fcbda8c38ad3513c87a13f3f7c67a06d3343c867c359);
        addGroupHash(4, 0x648a4e0b86e67fcee59b6095053b36962f3dc57eaf012a8abb438ad3585a9c37);
        addGroupHash(4, 0x6621624e768884375931167d5f08d321aae4c5dc1a43063f8a785006ec36c1fe);
        addGroupHash(5, 0x2112076ce19942e12bab294e03b698a24d3e39fcc487e9c8697a82bffe1cd1ce);
        addGroupHash(5, 0x256649b4fb53bc128aa2653788cb89dabff0a18eb5f7f389178f1d5467c44d5f);
        addGroupHash(5, 0x32b92341a46ee0b17a85a76655725ce42899f94d951b2f560bdf2e91cd4fe150);
        addGroupHash(5, 0x9be8f663d9e9c8c4afd6b1e94216d11b276c568cea731883b4c37badf0152fa0);
        addGroupHash(6, 0x303147ed0a31e9bed731e1a7cbc6ddc0e5bd64570d3de8e3db504fa020413e5d);
        addGroupHash(6, 0x7cf8b3395147e21414545a7089cabfb3c4dc91881bfe913d108c146c3765a516);
        addGroupHash(6, 0xe42a35fcc02cc4ae48c1c7f57702c70efe8c5d971596b59946accbb3761399b1);
        addGroupHash(6, 0xeef7f564c6353ed1c47ada12abd02f9ed547105e87fb12af226ccf1a536d7a12);
        addGroupHash(7, 0x26552e3bc49d5a6ac9170d5fb61b27f3b0c6569428dc790b744d3850b8895cbb);
        addGroupHash(7, 0x58101bf189620ce722338e0d698d871539c8a12b431d1ca5430562bd46841b05);
        addGroupHash(7, 0x9b30a2fe6eba96b869cfae57ced63820ab447030c92e1061dc80991430ce8f56);
        addGroupHash(7, 0xa7e2c031b6e803f3d6c7a987f26e3a36545fc902751ca219a9b956c0fa9074cd);
        addGroupHash(8, 0x272402fd985c219c618309ae895fc3883a8cbfe1d194b6df1e6498879ec65052);
        addGroupHash(8, 0x4f4cacc1ed48ff1d12188af65bc7314fc0c9f02343c6a8021c34efab175cba33);
        addGroupHash(8, 0x52ddf55f08b1d9c1f59e250cd6ff354ff0ba0cfd82af3053497e0d7d98a53cd0);
        addGroupHash(8, 0x6e5825ea8c97279881ec1626e2369d252446da44b123bd7e9dd476c4ad4b3b62);
    }

    function setMainContract(address mainContractAddress) public onlyOwner {
        mainContract = IERC721(mainContractAddress);
    }
    
    function addGroupHash(uint256 groupId, bytes32 hash) private {        
        groupHashes[groupId].push(hash);
        hashGroup[hash] = groupId;
    }

    function getGroupHashes(uint256 groupId) public view returns (bytes32[] memory) {
        return groupHashes[groupId];
    }

    function isValidSecret(uint8 groupId, uint256 tokenId, bytes32 secret) public view returns (bool) {
        return _isValidSecret(groupId, tokenId, secret);
    }

    function _isValidSecret(uint8 groupId, uint256 tokenId, bytes32 secret) private view returns (bool) {
        bytes32 hash = keccak256(abi.encodePacked(tokenId, secret));
        return (hashGroup[hash] == groupId);
    }

    function setSeenToken(uint8 groupId, uint256 tokenId, bytes32 secret) public {
        require(mainContract.ownerOf(tokenId) == _msgSender(), "you must be the token owner");
        require(_isValidSecret(groupId, tokenId, secret), "invalid group member");

        seenTokens[_msgSender()][groupId] = tokenId;
    }

    function getSeenToken(address owner, uint256 groupId) public view returns (uint256) {
        return seenTokens[owner][groupId];
    }

    function claim() public {
        require(!claimed, "Deken was already claimed");

        uint8 stillOwned = 0;
        for(uint8 groupId = 1; groupId <= 8; groupId++) {
            uint256 tokenId = seenTokens[_msgSender()][groupId];
            require(tokenId != 0, "not all groups seen");

            if (mainContract.ownerOf(tokenId) == _msgSender())
                stillOwned += 1;
        }

        require(stillOwned > 3, "you must still own more than 3 tokens");

        // Mark the captain as claimed to avoid reentracies
        claimed = true;

        // Starts Deken transfer to claimer
        mainContract.safeTransferFrom(address(this), _msgSender(), 0);
    }

    // This function is to be able to receive ERC721 tokens
    function onERC721Received(address, address, uint256, bytes calldata) public virtual override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}