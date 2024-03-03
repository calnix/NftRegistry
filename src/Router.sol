// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import { RevertMsgExtractor } from "./utils/RevertMsgExtractor.sol";
import { IERC721 } from "node_modules/@openzeppelin/contracts/token/ERC721/IERC721.sol";

import {NftLocker} from "./NftLocker.sol";

contract Router {

    IERC721 public immutable MOCA_NFT;
    NftLocker public immutable NFT_LOCKER;

    constructor(address mocaNFT, address nftLocker) {

        MOCA_NFT = IERC721(mocaNFT);
        NFT_LOCKER = NftLocker(nftLocker);
    }


    /// @dev Allows batched call to self (this contract).
    /// @param calls An array of inputs for each call.
    function batch(bytes[] calldata calls) external payable returns (bytes[] memory results) {
        results = new bytes[](calls.length);

        for (uint256 i; i < calls.length; i++) {

            (bool success, bytes memory result) = address(this).delegatecall(calls[i]);
            if (!success) revert(RevertMsgExtractor.getRevertMsg(result));
            results[i] = result;
        }
    }


    function lock(uint256 tokenId, uint32 dstEid, bytes calldata options) external {

        NFT_LOCKER.lock(msg.sender, tokenId, dstEid, options);
    }

    


}
