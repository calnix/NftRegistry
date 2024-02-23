# Background

1. EIP2621 is broken: https://www.trust-security.xyz/post/permission-denied
2. We want to still offer gasless transaction for our users.
3. Solution: EIP3009

EIP3009 has been successfully used by Circle, in its USDC implementation since v1. This offers us a degree of confidence.

EIP3009.sol and its dependencies were taken from the repo linked below. They were initally built with solidity version 0.6; we have updated them to 0.8.
As part of the update, the only refactoring done was chanigng `now` to `block.timestamp`.

src: https://github.com/CoinbaseStablecoin/eip-3009/blob/master/contracts/lib/EIP2612.sol