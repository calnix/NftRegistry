# Nft Locker + Registry

We have NFTs currently deployed on Ethereum, which we want to involve as part of staking, which occurs on Polygon.
Instead of bridging the NFTS over to polygon, we opt to have them 'locked' on Ethereum via NftLocker.sol, and correspondingly updated on NftRegistry.sol on Polygon.

## Setup

- forge install

## Execution flow

### Locking

- Users call `lock` on NftLocker.sol
- NFTs are transferred to the contract, and a mapping records which tokenId belongs to whom
- As part of `lock`, a cross-chain message is sent via LayerZero to the registry contract on polygon.
- This cross-chain message executes `_register` on NftRegistry.sol, which updates a mapping reflecting the association between tokenId and user.

Note that users can commit a maximum of 5 tokenIds per execution of `lock`. This is due to the use of loops.

### Staking

- Once users have their NFTs registered on Polygon, they can commit them to staking by calling `stakeNfts` on the pool contract.
- As part of `stakeNfts`, the pool contract will call `recordStake` on the registry contract.
- `recordStake` will ensure that the caller matches the recorded owner, and that the Nft was not previously staked to some other vault.

### Unstaking

- When user calls `unstakeAll` on the pool contract, as part of that, `recordUnstake` on the registry contract is executed.
- `recordUnstake` will dissociate the tokenId from its previously assigned vaultId.

### Unlocking

- A user must call `release` on NftRegistry.sol, to have his NFTs returned to him.
- `release` can only be successfully executed if `recordUnstake` was previously called, thereby clearing any vault associations.
- As part of `release`, a cross-chain message is sent via LayerZero to the Locker contract on Ethereum.
- This cross-chain message executes `_unlock` on NftLocker.sol, which transfers the NFTs to the user, amongst other state updates.

## Testnet Deployments

1. mockNftAddress = [0x3bACB53a7f5Eda5A784127aa0E9C1b3812B1b7a6](https://sepolia.etherscan.io/address/0x54d4e6adc4f152ed4919c940cb3ea13b912519c9)
2. nftLockerAddress = [0xb3C3bd52354857C40909333219C0dC7925AaCB65](https://sepolia.etherscan.io/address/0x18f786ae5fb1639baa4fce4b8f29c783949a66a8)
3. nftRegistryAddress = [0xaACe57A9300afB8e32b1240DE0C74432E085474c](https://sepolia.arbiscan.io/address/0x03d9842e73b061ac6e20b7376fe3feedf55bc71a)

Deployed with DeployTest.s.sol.

