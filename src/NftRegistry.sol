// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Ownable } from "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { OApp, Origin, MessagingFee } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

// issues
contract NftRegistry is OApp, Ownable2Step {
    using OptionsBuilder for bytes;

    address public pool;   
    // Chain id of locker contract 
    uint32 public immutable dstEid;

    // LZ options
    uint256 immutable BASE_GAS = 73_000;
    uint256 immutable GAS_PER_LOOP = 18_403;
    uint256 public gasBuffer;

    struct TokenData {
        address owner;
        bytes32 vaultId;         // non-zero value if staked
    }

    mapping(uint256 tokenId => TokenData data) public nfts;

    // events
    event PoolUpdated(address indexed newPool);
    event LockerUpdated(address indexed newLocker);

    event NftRegistered(address indexed user, uint256[] indexed tokenIds);
    event NftReleased(address indexed user, uint256[] indexed tokenIds);

    event NftStaked(address indexed user, uint256[] indexed tokenIds, bytes32 indexed vaultId);
    event NftUnstaked(address indexed user, uint256[] indexed tokenIds, bytes32 indexed vaultId);

//-------------------------------constructor-------------------------------------------
    constructor(address endpoint, address owner, address pool_, uint32 dstEid_) OApp(endpoint, owner) Ownable(owner) {
        pool = pool_;
        dstEid = dstEid_;
    }


    /*//////////////////////////////////////////////////////////////
                                 LOCKER
    //////////////////////////////////////////////////////////////*/

    // only callable by _lzReceive
    function _register(address user, uint256[] memory tokenIds) internal {

        uint256 length = tokenIds.length;
        for (uint256 i; i < length; ++i) {

            uint256 tokenId = tokenIds[i];

            // cache
            TokenData memory data = nfts[tokenId];

            // ensure tokenId does not belong to someone else
            require(data.owner == address(0), "Already registered");

            // update storage
            data.owner = user;
            nfts[tokenId] = data;   
        }
        
        emit NftRegistered(user, tokenIds);
    }

    /** 
     * @notice Called by user to release unstaked NFTs on mainnet, by calling NftLocker
     * @dev Max array length is 5, and txn reverts if any of the tokenIds are still attached to a vault
     * @dev msg.value check is handled by _payNative() in OAppSender.sol
     *      it is a strict equality check. excess gas cannot be sent.
     * @param tokenIds Destination chain's endpoint ID.
     */
    function release(uint256[] calldata tokenIds) external payable {
        uint256 length = tokenIds.length;
        require(length > 0, "Empty array");
        require(length <= 5, "Array max length exceeded");

        for (uint256 i; i < length; ++i) {

            uint256 tokenId = tokenIds[i];

            // cache
            TokenData memory data = nfts[tokenId];

            // check ownership + staking status
            require(data.owner == msg.sender, "Not Owner");
            require(data.vaultId == bytes32(0), "Nft is staked");
            
            // update storage
            delete nfts[tokenId];
        }

        emit NftReleased(msg.sender, tokenIds);

        // dst gas needed, only BASE_GAS needed for 1 tokenId
        uint256 totalGas = BASE_GAS + (GAS_PER_LOOP * (length - 1)) + gasBuffer;

        // create options
        bytes memory options;
        options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});  

        // craft payload
        bytes memory payload = abi.encode(msg.sender, tokenIds);

        // get updated quote
        MessagingFee memory fee = _quote(dstEid, payload, options, false);

        _lzSend(dstEid, payload, options, fee, payable(msg.sender));
    }
    

    /*//////////////////////////////////////////////////////////////
                                  POOL
    //////////////////////////////////////////////////////////////*/
   
    /** 
     * @notice Called by owner to set pool address, once the pool contract has been deployed.
     * @param pool_ Pool address
     */
    function setPool(address pool_) external onlyOwner {
        pool = pool_;
        emit PoolUpdated(pool_);
    }

    
    /** 
     * @notice Called by pool to associate a tokenId to a specific vaultId, thereby preventing repeated staking.
     * @dev Input validation and array length check handled by pool
     * @param onBehalfOf Staker's address
     * @param tokenIds Nft token ids to be staked
     * @param vaultId Vault id to be staked into
     */
    function recordStake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external {
        require(msg.sender == pool, "Only pool");

        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ++i) {
            
            // cache             
            uint256 tokenId = tokenIds[i];
            TokenData memory data = nfts[tokenId];

            // ensure tokenId does not belong to someone else
            require(data.owner == onBehalfOf, "Incorrect tokenId");
            // ensure NFT has not been staked
            require(data.vaultId == bytes32(0), "Nft is staked");
        
            // update storage
            data.vaultId = vaultId;
            nfts[tokenId] = data;
        }
        
        emit NftStaked(onBehalfOf, tokenIds, vaultId);
    }

    
    /** 
     * @notice Called by pool to disassociate a tokenId from a its vaultId, thereby freeing it to be released.
     * @dev Input validation and array length check handled by pool
     * @param onBehalfOf Staker's address
     * @param tokenIds Nft token ids to be unstaked
     * @param vaultId Vault id to be unstaked from
     */
    function recordUnstake(address onBehalfOf, uint256[] calldata tokenIds, bytes32 vaultId) external {
        require(msg.sender == pool, "Only pool");

        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ++i) {
            // cache 
            uint256 tokenId = tokenIds[i];
            TokenData memory data = nfts[tokenId];

            // ensure tokenId does not belong to someone else
            require(data.owner == onBehalfOf, "Incorrect tokenId");
            // ensure correct vaultId
            require(data.vaultId == vaultId, "Incorrect vaultId");
            
            // update storage
            delete data.vaultId;
            nfts[tokenId] = data;
        }
        
        emit NftUnstaked(onBehalfOf, tokenIds, vaultId);
    }

    
    /*//////////////////////////////////////////////////////////////
                              OWNABLE2STEP
    //////////////////////////////////////////////////////////////*/

    /**
     * @dev Starts the ownership transfer of the contract to a new account. Replaces the pending transfer if there is one.
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public override(Ownable, Ownable2Step) onlyOwner {
        Ownable2Step.transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`) and deletes any pending owner.
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal override(Ownable, Ownable2Step) {
        Ownable2Step._transferOwnership(newOwner);
    }


    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Future-proofing, in-case there are LZ changes that result in differing gas usage 
     * @dev Should be left untouched, unless there is an unexpected breaking LZ change
     * @param gasBuffer_ Amount of additional gas for execution on dstChain
     */
    function setGasBuffer(uint256 gasBuffer_) external onlyOwner {
        gasBuffer = gasBuffer_;
    }   


    /*//////////////////////////////////////////////////////////////
                               LAYERZERO
    //////////////////////////////////////////////////////////////*/

    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param tokenIds Array of tokenIds to be locked
     */
    function quote(uint256[] calldata tokenIds) external view returns (uint256 nativeFee, uint256 lzTokenFee) {

        bytes memory payload = abi.encode(msg.sender, tokenIds);

        // dst gas needed
        uint256 totalGas = BASE_GAS + (GAS_PER_LOOP * (tokenIds.length - 1)) + gasBuffer;

        // create options
        bytes memory options;
        options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});

        MessagingFee memory fee = _quote(dstEid, payload, options, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }


    /**
     * @dev Override of _lzReceive internal fn in OAppReceiver.sol. 
            The public fn lzReceive, handles param validation
     * @param payload message payload being received
     */
    function _lzReceive(Origin calldata, bytes32, bytes calldata payload, address, bytes calldata) internal override {
        
        // owner, tokendId
        (address owner, uint256[] memory tokenIds) = abi.decode(payload, (address, uint256[]));

        // update
        _register(owner, tokenIds);
    }

}

