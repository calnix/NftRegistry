// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

interface INftStreaming {

    /**
     * @notice Stream struct containing claim data and status
     * @param claimed Total amount claimed from this stream
     * @param lastClaimedTimestamp Timestamp of last claim
     * @param isPaused Whether the stream is currently paused
     */
    struct Stream {
        uint128 claimed;
        uint128 lastClaimedTimestamp;
        bool isPaused;
    }


    /**
     * @notice Returns the stream data for a given tokenId
     * @param tokenId The NFT token ID to check
     * @return The Stream struct containing claimed amount, last claim timestamp and pause status
     */
    function streams(uint256 tokenId) external view returns (Stream memory);

    /**
     * @notice Checks if a module address is registered as trusted
     * @param module The address to check
     * @return True if the module is registered, false otherwise
     */
    function modules(address module) external view returns (bool);


    /**
     * @notice Returns the claimable amount for a given tokenId
     * @param tokenId The NFT token ID to check
     * @return The claimable amount in MOCA tokens
     */
    function claimable(uint256 tokenId) external view returns (uint256);

    /**
     * @notice Claims MOCA tokens for a single NFT
     * @param tokenId The NFT token ID to claim rewards for
     */
    function claimSingle(uint256 tokenId) external;

    /**
     * @notice Claims MOCA tokens for multiple NFTs
     * @param tokenIds Array of NFT token IDs to claim rewards for
     */
    function claimMultiple(uint256[] calldata tokenIds) external;

    /**
     * @notice Claims MOCA tokens for multiple NFTs via a trusted module
     * @param module The trusted module address initiating the claim
     * @param tokenIds Array of NFT token IDs to claim rewards for
     */
    function claimViaModule(address module, uint256[] calldata tokenIds) external;

    /**
     * @notice Enable or disable a module. Only Owner.
     * @dev Module is expected to implement fn 'streamingOwnerCheck(address,uint256[])'
     * @param module Address of contract
     * @param set True - enable | False - disable
     */ 
    function updateModule(address module, bool set) external;

    /**
     * @notice Returns the owner of the NFT streaming contract
     * @return The owner address
     */
    function owner() external view returns (address);
}

