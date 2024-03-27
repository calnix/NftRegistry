// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { Ownable } from "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { OApp, Origin, MessagingFee } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

// issues
contract NftRegistry is OApp, Ownable2Step {
    using OptionsBuilder for bytes;
   
    // Chain id of locker contract 
    uint32 public immutable dstEid;

    address public pool;

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

    event NftStaked(address indexed user, uint256 indexed tokenId, bytes32 indexed vaultId);
    event NftUnstaked(address indexed user, uint256 indexed tokenId, bytes32 indexed vaultId);

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

        // if tokenIds.length = 1
        uint256 baseGas = 73_000;
        // gas multiplier
        uint256 gasMultiplier = 18_403 * (length - 1);
        uint256 totalGas = baseGas + gasMultiplier;

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
   
    function setPool(address pool_) external onlyOwner {
        pool = pool_;
        emit PoolUpdated(pool_);
    }

    ///@dev only callable by pool
    function recordStake(address onBehalfOf, uint256 tokenId, bytes32 vaultId) external {
        require(msg.sender == pool, "Only pool");

        // cache 
        TokenData memory data = nfts[tokenId];

        // ensure tokenId does not belong to someone else
        require(data.owner == onBehalfOf, "Incorrect tokenId");
        // ensure NFT has not been staked
        require(data.vaultId == bytes32(0), "Nft is staked");
        
        // update storage
        data.vaultId = vaultId;
        nfts[tokenId] = data;
        
        emit NftStaked(onBehalfOf, tokenId, vaultId);
    }

    ///@dev only callable by pool
    function recordUnstake(address onBehalfOf, uint256 tokenId, bytes32 vaultId) external {
        require(msg.sender == pool, "Only pool");

        // cache 
        TokenData memory data = nfts[tokenId];

        // ensure tokenId does not belong to someone else
        require(data.owner == onBehalfOf, "Incorrect tokenId");
        // ensure correct vaultId
        require(data.vaultId == vaultId, "Incorrect vaultId");
        
        // update storage
        delete data.vaultId;
        nfts[tokenId] = data;
        
        emit NftUnstaked(onBehalfOf, tokenId, vaultId);
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
                               LAYERZERO
    //////////////////////////////////////////////////////////////*/

    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param payload The message payload.
     * @param options Message execution options
     * @param payInLzToken boolean for which token to return fee in
     * @return nativeFee Estimated gas fee in native gas.
     * @return lzTokenFee Estimated gas fee in ZRO token.
     */
    function quote(bytes calldata payload, bytes calldata options, bool payInLzToken) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        
        MessagingFee memory fee = _quote(dstEid, payload, options, payInLzToken);
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

