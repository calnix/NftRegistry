// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { IERC721 } from "node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

import { OApp, Origin, MessagingFee } from "node_modules/@layerzerolabs/lz-evm-oapp-v2/contracts/oapp/OApp.sol";
import { Ownable } from "node_modules/@openzeppelin/contracts/access/Ownable.sol";

contract NftLocker is OApp {

    address public router;
    IERC721 public immutable MOCA_NFT;

    // locked nfts are assigned to the user's address
    mapping(uint256 tokenId => address user) public tokenIds;

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

    function lock(address onBehalfOf, uint256 tokenId, uint32 dstEid, bytes calldata options) external payable auth {
        require(tokenIds[tokenId] == address(0), "Already locked");                

        // update
        tokenIds[tokenId] = onBehalfOf;

        emit NftLocked(onBehalfOf, tokenId);

        // grab
        MOCA_NFT.transferFrom(onBehalfOf, address(this), tokenId);

        // Encodes message as bytes
        bytes memory payload = abi.encode(onBehalfOf, tokenId);
        
        // MessagingFee: Fee struct containing native gas and ZRO token.
        // returns MessagingReceipt struct
        _lzSend(dstEid, payload, options, MessagingFee(msg.value, 0), payable(onBehalfOf));
    }


    function point(address router_) external onlyOwner {
        router = router_;
    }

    // admin can call unlock on a specific user in special cases
    // admin must ensure that in unlocking manually, Registry is updated as well 
    // this can be done via send() xchain msg or directly on the polygon contract
    function unlock(address onBehalfOf, uint256 tokenId) external onlyOwner {
        // delete tagged address
        delete tokenIds[tokenId];

        emit NftUnlocked(onBehalfOf, tokenId);

        // return
        MOCA_NFT.transferFrom(address(this), onBehalfOf, tokenId);
    }


    /*//////////////////////////////////////////////////////////////
                                INTERNAL
    //////////////////////////////////////////////////////////////*/
    
    // returns the most recently locked tokenId
    // called by _lzReceive
    function _unlock(address onBehalfOf, uint256 tokenId) internal {
        require(tokenIds[tokenId] == onBehalfOf, "Incorrect owner");                

        // delete tagged address
        delete tokenIds[tokenId];

        emit NftUnlocked(onBehalfOf, tokenId);

        // return
        MOCA_NFT.transferFrom(address(this), onBehalfOf, tokenId);
    }


//----------------------------- LZ FNs ---------------------------------------------------        

    /*//////////////////////////////////////////////////////////////
                                  SEND
    //////////////////////////////////////////////////////////////*/

    // Sends a message from the source to destination chain.
    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param dstEid Destination chain's endpoint ID.
     * @param options Message execution options (e.g., gas to use on destination).
     * @param onBehalfOf Nft owner address
     */
    function send(uint32 dstEid, uint256 tokenId, bytes calldata options, address onBehalfOf) external payable onlyOwner {
        
        // Encodes message as bytes
        bytes memory payload = abi.encode(onBehalfOf, tokenId);
        
        // MessagingFee: Fee struct containing native gas and ZRO token.
        // payable(msg.sender): The refund address in case the send call reverts.
        _lzSend(dstEid, payload, options, MessagingFee(msg.value, 0), payable(msg.sender));
    }

    /** 
     * @dev Quotes the gas needed to pay for the full omnichain transaction.
     * @param _dstEid Destination chain's endpoint ID.
     * @param _options Message execution options
     * @param _payInLzToken boolean for which token to return fee in
     * @param onBehalfOf Nft owner address
     * @return nativeFee Estimated gas fee in native gas.
     * @return lzTokenFee Estimated gas fee in ZRO token.
     */
    function quote(uint32 _dstEid, bytes calldata _options, bool _payInLzToken, address onBehalfOf) public view returns (uint256 nativeFee, uint256 lzTokenFee) {
        
        // Encodes message as bytes
        bytes memory _payload = abi.encode(onBehalfOf);

        MessagingFee memory fee = _quote(_dstEid, _payload, _options, _payInLzToken);
        return (fee.nativeFee, fee.lzTokenFee);
    }


    /*//////////////////////////////////////////////////////////////
                                RECEIVE
    //////////////////////////////////////////////////////////////*/


    /**
     * @param origin struct containing info about the message sender
     * @param guid global packet identifier
     * @param payload message payload being received
     * @param executor the Executor address.
     * @param extraData arbitrary data appended by the Executor
     */
    function _lzReceive(Origin calldata origin, bytes32 guid, bytes calldata payload, address executor, bytes calldata extraData) internal virtual override {

        // owner, tokendId
        (address owner, uint256 tokenId) = abi.decode(payload, (address, uint256));

        _unlock(owner, tokenId);
    }


    /*//////////////////////////////////////////////////////////////
                                MODIFIER
    //////////////////////////////////////////////////////////////*/

    modifier auth() {

        if(msg.sender == router || msg.sender == owner()) {}
        else revert IncorrectCaller();

        _;
    }


}

