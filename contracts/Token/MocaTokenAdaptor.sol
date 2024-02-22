// SPDX-License-Identifier: MIT
pragma solidity ^0.8.22;

import "@layerzerolabs/contracts/OFTAdapter.sol";

contract MocaTokenAdaptor is OFTAdapter {

    constructor(
        address _token, // a deployed, already existing ERC20 token address
        address _layerZeroEndpoint, // local endpoint address
        address _owner // token owner
        ) OFTAdapter(_token, _layerZeroEndpoint, _owner) {
            //
            // your custom contract logic here
            //
        }
}


/**

This standard has already implemented OApp related functions like _lzSend and _lzReceive.
 Instead, you will override and use _debit and _credit when writing your own custom OFT logic.

Token Supply Cap
 default OFT Standard has a max token supply 2^64 - 1
 cos on-EVM environments use uint64
 This ensures that token transfers won't fail due to a loss of precision or unexpected balance conversions
 
Shared Decimals
 By default, an OFT has 6 sharedDecimals, which is optimal for most ERC20 use cases that use 18 decimals.

Owner and delegate
 contract owner is set as the delegate in cosntructor
 delegate has the ability to handle various critical tasks such as setting configurations and MessageLibs
 delegate can be changed via
    
    function setDelegate(address _delegate) public onlyOwner {
        endpoint.setDelegate(_delegate);
    }

 delegate can be assigned to implement custom configurations on behalf of the contract owner.
 

 */