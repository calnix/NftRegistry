// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IERC721 } from "node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";
import { Pausable } from "node_modules/@openzeppelin/contracts/utils/Pausable.sol";
import { Ownable } from "node_modules/@openzeppelin/contracts/access/Ownable.sol";
import { Ownable2Step } from "@openzeppelin/contracts/access/Ownable2Step.sol";

import { OApp, Origin, MessagingFee } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { OptionsBuilder } from "@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/libs/OptionsBuilder.sol";

contract NftLocker is OApp, Pausable, Ownable2Step {
    using OptionsBuilder for bytes;

    bool public isFrozen;
    uint32 public immutable dstEid;
    IERC721 public immutable MOCA_NFT;

    // locked nfts are assigned to the user's address
    mapping(uint256 tokenId => address user) public nfts;

    // events
    event NftLocked(address indexed user, uint256[] indexed tokenIds);
    event NftUnlocked(address indexed user, uint256[] indexed tokenIds);
    event Recovered(address indexed nft, uint256 indexed tokenId, address indexed receiver);
    event PoolFrozen(uint256 indexed timestamp);

    // errors
    error IncorrectCaller();


    constructor(address endpoint, address owner, address mocaNft, uint32 dstEid_) OApp(endpoint, owner) Ownable(owner) {
        
        MOCA_NFT = IERC721(mocaNft);
        dstEid = dstEid_;
    }

   
    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/
    
    /**
     * @notice Lock NFTs into NFT locker - NFT registry on remote chain is updated via LayerZero call
     * @dev A maximum of 5 tokenIds can be passed at once
     * @param tokenIds Array of tokenIds to be locked
     */
    function lock(uint256[] calldata tokenIds) external whenNotPaused payable {
        uint256 length = tokenIds.length;
        require(length > 0, "Empty array");
        require(length <= 5, "Array max length exceeded");

        for (uint256 i; i < length; ++i) {
            
            uint256 tokenId = tokenIds[i];
            require(nfts[tokenId] == address(0), "Already locked");                
            
            // update
            nfts[tokenId] = msg.sender;

            // grab
            MOCA_NFT.transferFrom(msg.sender, address(this), tokenId);
        }

        emit NftLocked(msg.sender, tokenIds);

        // if tokenIds.length = 1
        uint256 baseGas = 51_950;
        // gas multiplier
        uint256 gasMultiplier = 26_600 * (length - 1);
        uint256 totalGas = baseGas + gasMultiplier;

        // create options
        bytes memory options;
        options = OptionsBuilder.newOptions().addExecutorLzReceiveOption({_gas: uint128(totalGas), _value: 0});
        
        // craft payload
        bytes memory payload = abi.encode(msg.sender, tokenIds);

        // check gas needed
        MessagingFee memory fee = _quote(dstEid, payload, options, false);
        require(msg.value >= fee.nativeFee, "Insufficient gas");

        // MessagingFee: Fee struct containing native gas and ZRO token.
        // returns MessagingReceipt struct
        _lzSend(dstEid, payload, options, fee, payable(msg.sender));
    }

    /**
     * @notice Users can extract their NFTs in case of emergency and locker is frozed
     * @dev Locker must be both paused and frozen
     * @param tokenIds Array of tokenIds to be unlocked
     */
    function emergencyExit(uint256[] calldata tokenIds) external whenPaused {
        require(isFrozen, "Locker not frozen");
        require(tokenIds.length > 0, "Empty array");

        _unlock(msg.sender, tokenIds);
    }

    /*//////////////////////////////////////////////////////////////
                                 ADMIN
    //////////////////////////////////////////////////////////////*/

    /**
     * @notice Pause pool
     */
    function pause() external onlyOwner whenNotPaused {
        _pause();
    }

    /**
     * @notice Unpause pool
     */
    function unpause() external onlyOwner whenPaused {
        require(isFrozen, "Locker is frozen");
        _unpause();
    }
    
    /**
     * @notice To freeze the locker in the event of something untoward occuring.
     * @dev Only callable from a paused state, affirming that operation should not resume.
     *      Nothing to be updated. Freeze as is.
            Enables emergencyExit() to be called.
     */
    function freeze() external whenPaused onlyOwner {
        require(isFrozen, "Locker is frozen");
        
        isFrozen = true;
        emit PoolFrozen(block.timestamp);
    }

    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    
    // returns the most recently locked tokenId
    // called by _lzReceive
    function _unlock(address user, uint256[] memory tokenIds) internal {
        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ++i) {
            uint256 tokenId = tokenIds[i];

            require(nfts[tokenId] == user, "Incorrect owner");                

            // delete tagged address
            delete nfts[tokenId];

            // return
            MOCA_NFT.transferFrom(address(this), user, tokenId);
        }

        emit NftUnlocked(user, tokenIds);
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
     */
    function quote(bytes calldata payload, bytes calldata options) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        
        MessagingFee memory fee = _quote(dstEid, payload, options, false);
        return (fee.nativeFee, fee.lzTokenFee);
    }

    /**
     * @dev Override of _lzReceive internal fn in OAppReceiver.sol. The public fn lzReceive, handles param validation.
     * @param payload message payload being received
     */
    function _lzReceive(Origin calldata, bytes32, bytes calldata payload, address, bytes calldata) internal override {
       
        // owner, tokendId
        (address owner, uint256[] memory tokenIds) = abi.decode(payload, (address, uint256[]));

        _unlock(owner, tokenIds);
    }

}

