// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.22;


import "node_modules/@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ILayerZeroEndpointV2.sol";

contract EndpointV2Mock {

    function setDelegate(address /*_delegate*/) external {}

    function send(MessagingParams memory messagingParams, address _refundAddress) external returns (MessagingReceipt memory) {
        MessagingReceipt memory receipt;
        return receipt;
    }

    function quote(MessagingParams memory messagingParams, address) public view returns (uint256, uint256) {
        return (0, 0);
    }
}