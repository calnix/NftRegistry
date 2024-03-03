// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;


import "node_modules/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract EndpointV2Mock {

    function setDelegate(address /*_delegate*/) external {}

    function send(MessagingParams memory messagingParams, address _refundAddress) external returns (MessagingReceipt memory receipt) {
        MessagingReceipt memory receipt;
    }
}