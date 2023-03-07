// SPDX-License-Identifier: MIT
pragma solidity ^0.8.14;

import "openzeppelin/access/Ownable.sol";
import "openzeppelin/token/ERC721/extensions/IERC721Enumerable.sol";
import "openzeppelin/utils/math/SafeMath.sol";

import "chainlink/VRFConsumerBaseV2.sol";
import "chainlink/interfaces/VRFCoordinatorV2Interface.sol";


contract MarquisBanquet is Ownable, VRFConsumerBaseV2 {

    using SafeMath for uint256;

    struct KeyInfo {
        bool shuffle;
        uint256 ownerTokenId;
        uint256 changeBlockNumber;
        bytes32 ownerSignature;
    }

    struct Payment {
        bool approved;
        bool paid;
        uint256 amount;
        address to;
        uint256 expirationBlock;
    }

    uint256 private constant INVALID_TOKEN_ID = type(uint256).max;
    uint256 private constant ONE_HOUR_BLOCKS = 300; // ~ an hour

    bool public isRunning;
    uint256 public bountyBalance;
    uint256 private shuffleRequestId;
    uint256 private shuffleStartBlock;

    // Verified Random Function (VRFv2) variables
    bytes32 public keyHash;
    uint256 public subscriptionId;
    VRFCoordinatorV2Interface vrfCoordinatorIface;

    IERC721Enumerable mainContract;

    KeyInfo[4] private keys;

    // Bounty balance and reward variables
    uint256 cleanPaymentsIndex;
    uint256[] private allPaymentIds;
    mapping(address => uint256[]) private userPaymentIds;
    mapping(uint256 => Payment) private payments;

    event RewardPaid(address to, uint256 amount);

    modifier whenRunning() {
        require(isRunning, "not running");
        _;
    }

    modifier whenNotShuffling() {
        require(block.number.sub(shuffleStartBlock) > (ONE_HOUR_BLOCKS * 24), "shuffling");
        _;
    }

    constructor(address _vrfCoordinator, bytes32 _keyHash, uint256 _subscriptionId) VRFConsumerBaseV2(_vrfCoordinator) {
        vrfCoordinatorIface = VRFCoordinatorV2Interface(_vrfCoordinator);
        keyHash = _keyHash;
        subscriptionId = _subscriptionId;

        keys[0].ownerSignature = 0xf892afaa24442adb2ac89ab748bf4690e224a9f20c2a6ce10c067f8cabd8b5d2;
        keys[1].ownerSignature = 0xd6e7a87deffdf73e47a03e5ba13787cb7be05b8c772a6c0f13dade69ba7a6aa4;
        keys[2].ownerSignature = 0x9a2865ea99380dcd0f2d3f2905ecf562920f6b186ccae7187bd5dbd9d56b54c9;
        keys[3].ownerSignature = 0x116bcd8a7089a68db23d0bb8294ccaaf147e20b5b23547b9d7a9522727392476;

        // this is to avoid those cases where token 0 could appear as key-owner, when It is not.
        keys[0].ownerTokenId = INVALID_TOKEN_ID;
        keys[1].ownerTokenId = INVALID_TOKEN_ID;
        keys[2].ownerTokenId = INVALID_TOKEN_ID;
        keys[3].ownerTokenId = INVALID_TOKEN_ID;
    }
    
    /**
     * @dev This method will recieve all sent Eth
     */
    receive() external payable {
        bountyBalance += msg.value;
    }

    function setMainContract(address _mainContractAddress) public onlyOwner {
        mainContract = IERC721Enumerable(_mainContractAddress);
    }

    function start() public onlyOwner {
        require(address(mainContract) != address(0));

        keys[0].changeBlockNumber = block.number;
        keys[1].changeBlockNumber = block.number;
        keys[2].changeBlockNumber = block.number;
        keys[3].changeBlockNumber = block.number;

        isRunning = true;
    }

    function getOwnerSignature(uint256 keyId) public view returns(bytes32) {
        require(keyId < 4, "invalid keyId");
        return keys[keyId].ownerSignature;
    }

    function getKeyOwner(uint256 keyId) public view returns(uint256) {
        require(keyId < 4, "invalid keyId");
        return keys[keyId].ownerTokenId;
    }

    function getKeyInfo(uint256 keyId) public view returns (KeyInfo memory) {
        return keys[keyId];
    }

    /* 
     * 
     */
    function claimKey(uint256 keyId, uint256 tokenId, bytes32 secret) public whenNotShuffling {
        require(keys[keyId].ownerTokenId == INVALID_TOKEN_ID, "key already owned");
        require(mainContract.ownerOf(tokenId) == address(msg.sender), "not tokenId owner");

        bytes32 signture = keccak256(abi.encodePacked(tokenId, secret));
        require(signture == keys[keyId].ownerSignature, "wrong signatue");

        keys[keyId].changeBlockNumber = block.number;
        keys[keyId].ownerTokenId = tokenId;
    }

    function transferKey(uint256 keyId, uint256 toTokenId) public whenNotShuffling {
        require(keyId < 4, "invalid keyId");
        require(mainContract.ownerOf(keys[keyId].ownerTokenId) == address(msg.sender), "key owner error");
        require(mainContract.ownerOf(toTokenId) == address(msg.sender), "toTokenId error");
        require(block.number.sub(keys[keyId].changeBlockNumber) > ONE_HOUR_BLOCKS, "one transfer x hour");
        require(keys[keyId].ownerTokenId != toTokenId, "already own the key");

        keys[keyId].changeBlockNumber = block.number;
        keys[keyId].ownerTokenId = toTokenId;
    }

    function fulfillRandomWords(uint256 requestId, uint256[] memory randomWords) internal override {
        if (requestId != shuffleRequestId)
            return;

        uint256 randomWord = randomWords[0];

        for(uint8 keyId = 0; keyId < 4; keyId++) {
            if (keys[keyId].shuffle) {
                keys[keyId].ownerTokenId = randomWord.mod(mainContract.totalSupply());
                randomWord = randomWord >> 16;
                keys[keyId].shuffle = false;
                keys[keyId].changeBlockNumber = block.number;
            }
        }

        payments[requestId].approved = true;
        shuffleStartBlock = 0;
    }

    function _requestShuffle(uint256 _amount, address _to) private {
        require(subscriptionId > 0, "VRF no set up");
        shuffleStartBlock = block.number;

        shuffleRequestId = vrfCoordinatorIface.requestRandomWords(
            keyHash,
            uint64(subscriptionId),
            3,
            200000,
            1
        );

        payments[shuffleRequestId] = Payment({
            approved: false,
            paid: false,
            amount: _amount,
            to: _to,
            expirationBlock: (block.number + (ONE_HOUR_BLOCKS * 24 * 7))
        });
        userPaymentIds[_to].push(shuffleRequestId);
        allPaymentIds.push(shuffleRequestId);
    }

    function shuffle() public whenRunning whenNotShuffling {
        uint128 keysToShuffle = 0;
        uint128 keyId = 0;
        uint256 _rewardAmount;

        for(; keyId < 4; keyId++) {
            keys[keyId].shuffle = (block.number.sub(keys[keyId].changeBlockNumber) > (ONE_HOUR_BLOCKS * 24 * 30));
            if (keys[keyId].shuffle)
                keysToShuffle += 1;
        }

        if (keysToShuffle == 0)
            revert("no keys to shuffle");

        _rewardAmount = bountyBalance.div(100).mul(keysToShuffle); // In this case, 1% of bounty per key, is paid as reward
        bountyBalance -= _rewardAmount;

        _requestShuffle(_rewardAmount, address(msg.sender));
    }

    function claimBounty() public whenRunning whenNotShuffling {
        require(bountyBalance > 0, "no balance to claim");

        uint256 _rewardAmount = bountyBalance;
        bountyBalance = 0;

        for(uint8 keyId = 0; keyId < 4; keyId++) {
            require(mainContract.ownerOf(keys[keyId].ownerTokenId) == address(msg.sender), "not key owner");
            keys[keyId].shuffle = true;
        }

        _requestShuffle(_rewardAmount, address(msg.sender));
    }

    function getUserPayments(address user) public view returns(uint256[] memory) {
        return userPaymentIds[user];
    }

    function getPaymentInfo(uint256 paymentId) public view returns (Payment memory) {
        return payments[paymentId];
    }

    function claimPayment(uint256 paymentId) public {
        require(payments[paymentId].approved && !payments[paymentId].paid, "not approved or already paid");
        require(payments[paymentId].to == address(msg.sender), "payment owner error");
        require(payments[paymentId].expirationBlock >= block.number, "expired payment");

        payments[paymentId].paid = true;

        (bool success, ) = payments[paymentId].to.call{value: payments[paymentId].amount}("");
        require(success, 'transaction error');
    }

    function cleanPayments() public {
        require(cleanPaymentsIndex < allPaymentIds.length);
        require(
            payments[allPaymentIds[cleanPaymentsIndex]].expirationBlock < block.number,
            "no expired payments"
        );

        for(; cleanPaymentsIndex < allPaymentIds.length; cleanPaymentsIndex++) {
            Payment memory _payment = payments[allPaymentIds[cleanPaymentsIndex]];

            if(_payment.paid == true) {
                continue;
            }

            // Is It not expired?
            if(_payment.expirationBlock >= block.number) {
                break;
            }

            // If we are here is because the payment was not paid and It is expired
            bountyBalance += _payment.amount;
        }
    }
}