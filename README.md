# Setup

forge init
copy package.json
forge test
npm install
update foundry.toml for remmapings

## Sphinx

- Install Sphinx CLI: `npm install --save-dev @sphinx-labs/plugins`
- Install Sphinx Foundry fork: `npx sphinx install`
- Update .gitignore: `node_modules/`
- Add remapping: `@sphinx-labs/contracts/=lib/sphinx/packages/contracts/contracts/foundry`
- Update your deployment script
- propose:`npx sphinx propose script/DeploySphinx.s.sol --networks testnets --tc ContractName`


## Testnet Deployments

1. mockNftAddress = [0x3bACB53a7f5Eda5A784127aa0E9C1b3812B1b7a6](https://sepolia.etherscan.io/address/0x3bacb53a7f5eda5a784127aa0e9c1b3812b1b7a6)
2. nftLockerAddress = [0xb3C3bd52354857C40909333219C0dC7925AaCB65](https://sepolia.etherscan.io/address/0xb3c3bd52354857c40909333219c0dc7925aacb65#readContract)
3. nftRegistryAddress = [0xaACe57A9300afB8e32b1240DE0C74432E085474c](https://sepolia.arbiscan.io/address/0xaace57a9300afb8e32b1240de0c74432e085474c)

