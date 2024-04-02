# Nft Locker + Registry

We have NFTs currently deployed on Ethereum, which we want to involve as part of staking, which occurs on Polygon.

Instead of bridging the NFTS over to polygon, we opt to have them 'locked' on Ethereum via NftLocker.sol, and correspondingly updated on NftRegistry.sol on Polygon.

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

1. mockNftAddress = [0x3bACB53a7f5Eda5A784127aa0E9C1b3812B1b7a6](https://sepolia.etherscan.io/address/0x3bacb53a7f5eda5a784127aa0e9c1b3812b1b7a6)
2. nftLockerAddress = [0xb3C3bd52354857C40909333219C0dC7925AaCB65](https://sepolia.etherscan.io/address/0xb3c3bd52354857c40909333219c0dc7925aacb65#readContract)
3. nftRegistryAddress = [0xaACe57A9300afB8e32b1240DE0C74432E085474c](https://sepolia.arbiscan.io/address/0xaace57a9300afb8e32b1240de0c74432e085474c)


#

# Setup

forge init
copy package.json
forge test
npm install
update foundry.toml for remapping


## Sphinx

- Install Sphinx CLI: `npm install --save-dev @sphinx-labs/plugins`
- Install Sphinx Foundry fork: `npx sphinx install`
- Update .gitignore: `node_modules/`
- Add remapping: `@sphinx-labs/contracts/=lib/sphinx/packages/contracts/contracts/foundry`
- Update your deployment script
- propose:`npx sphinx propose script/DeploySphinx.s.sol --networks testnets --tc ContractName`