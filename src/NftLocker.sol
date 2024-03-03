// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IERC721 } from "node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { OApp, Origin, MessagingFee } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { Ownable } from "node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract NftLocker is OApp {

    address public router;
    IERC721 public immutable MOCA_NFT;

    // locked nfts are assigned to the user's address
    mapping(uint256 tokenId => address user) public nfts;

    // events
    event NftLocked(address indexed user, uint256 indexed tokenId);
    event NftUnlocked(address indexed user, uint256 indexed tokenId);
    event Recovered(address indexed nft, uint256 indexed tokenId, address indexed receiver);

    // errors
    error IncorrectCaller();

//-------------------------------constructor-------------------------------------------

    constructor(address _endpoint, address _owner, address mocaNft) OApp(_endpoint, _owner) Ownable(_owner) {
        
        MOCA_NFT = IERC721(mocaNft);
    }

   
//-------------------------------------------------------------------------------------

    /*//////////////////////////////////////////////////////////////
                                EXTERNAL
    //////////////////////////////////////////////////////////////*/

    function lock(uint256[] calldata tokenIds, uint32 dstEid, bytes calldata options) external payable {
        uint256 length = tokenIds.length;
        require(length <= 5, "Array max length exceeded");

        for (uint256 i; i < length; ++i) {
            
            uint256 tokenId = tokenIds[i];
            require(nfts[tokenId] == address(0), "Already locked");                
            
            // update
            nfts[tokenId] = msg.sender;
            emit NftLocked(msg.sender, tokenId);

            // grab
            MOCA_NFT.transferFrom(msg.sender, address(this), tokenId);
        }
        
        // craft payload
        bytes memory payload = abi.encode(msg.sender, tokenIds);

        // check gas needed
        MessagingFee memory fee = _quote(dstEid, payload, options, false);
        require(msg.value >= fee.nativeFee, "Insufficient gas");

        // refund excess
        if(msg.value > fee.nativeFee) {
            uint256 excessGas = msg.value - fee.nativeFee;

            payable(msg.sender).transfer(excessGas);
            fee.nativeFee -= excessGas; 
        }

        // MessagingFee: Fee struct containing native gas and ZRO token.
        // returns MessagingReceipt struct
        _lzSend(dstEid, payload, options, fee, payable(msg.sender));

    }


    // admin can call unlock on a specific user in special cases
    // admin must ensure that in unlocking manually, Registry is updated as well 
    // this can be done via send() xchain msg or directly on the polygon contract
    function unlock(address onBehalfOf, uint256[] calldata tokenIds) external onlyOwner {

        uint256 length = tokenIds.length;

        for (uint256 i; i < length; ++i) {
            uint256 tokenId = tokenIds[i];

            // delete tagged address
            delete nfts[tokenId];

            emit NftUnlocked(onBehalfOf, tokenId);

            // return
            MOCA_NFT.transferFrom(address(this), onBehalfOf, tokenId);
        }
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

            emit NftUnlocked(user, tokenId);

            // return
            MOCA_NFT.transferFrom(address(this), user, tokenId);
        }
    }


//----------------------------- LZ FNs ---------------------------------------------------        

    /*//////////////////////////////////////////////////////////////
                                  SEND
    //////////////////////////////////////////////////////////////*/

    // Sends a message from the source to destination chain.
    // For admin use only, in case of any hiccups.
    // Note: considering restricting scope of use by specifying payload
    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param dstEid Destination chain's endpoint ID.
     * @param payload Message payload
     * @param options Message execution options (e.g., gas to use on destination).
     */
    function send(uint32 dstEid, bytes memory payload, bytes calldata options) external payable onlyOwner {
        
        // check gas needed
        MessagingFee memory fee = _quote(dstEid, payload, options, false);
        require(msg.value >= fee.nativeFee, "Insufficient gas");

        // refund excess
        if(msg.value > fee.nativeFee) {
            uint256 excessGas = msg.value - fee.nativeFee;

            payable(msg.sender).transfer(excessGas);
            fee.nativeFee -= excessGas; 
        }

        // MessagingFee: Fee struct containing native gas and ZRO token.
        // payable(msg.sender): The refund address in case the send call reverts.
        _lzSend(dstEid, payload, options, fee, payable(msg.sender));
    }

    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param dstEid Destination chain's endpoint ID.
     * @param payload The message payload.
     * @param options Message execution options
     * @param payInLzToken boolean for which token to return fee in
     * @return nativeFee Estimated gas fee in native gas.
     * @return lzTokenFee Estimated gas fee in ZRO token.
     */
    function quote(uint32 dstEid, bytes calldata payload, bytes calldata options, bool payInLzToken) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        
        MessagingFee memory fee = _quote(dstEid, payload, options, payInLzToken);
        return (fee.nativeFee, fee.lzTokenFee);
    }


    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/


    /**
     * @dev Override of _lzReceive internal fn in OAppReceiver.sol. 
            The public fn lzReceive, handles param validation
     * @param payload message payload being received
     */
    function _lzReceive(Origin calldata, bytes32, bytes calldata payload, address, bytes calldata) internal override {
       
        // owner, tokendId
        (address owner, uint256[] memory tokenIds) = abi.decode(payload, (address, uint256[]));

        _unlock(owner, tokenIds);
    }


}

