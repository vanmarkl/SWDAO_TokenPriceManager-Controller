[aca]: contracts/adapters/ChainlinkPriceRelay.sol
[acp]: contracts/adapters/CurvePoolPriceRelay.sol
[adapters]: contracts/adapters
[ca]: https://polygonscan.com/address/0x8a46eb6d66100138a5111b803189b770f5e5df9a
[chainlink aggregators]: https://data.chain.link/polygon/mainnet
[curve pools]: https://polygon.curve.fi/pools
[fc]: https://book.getfoundry.sh/reference/forge/forge-create.html
[fi]: https://github.com/foundry-rs/foundry#installation
[foundry]: https://github.com/foundry-rs/foundry
[ITokenPriceManager.sol]: contracts/interfaces/ITokenPriceManager.sol
[itpc]: contracts/interfaces/ITokenPriceControllerMinimal.sol
[itpm]: contracts/interfaces/ITokenPriceManagerMinimal.sol
[polygonscan]: https://polygonscan.com/
[polygon&nbsp;pos]: https://polygon.technology/solutions/polygon-pos
[remix]: https://remix.ethereum.org/
[set tokens]: https://www.tokensets.com/explore
[swd]: https://www.swdao.org/products/swd-token
[sw&nbsp;dao]: https://www.swdao.org/
[test]: contracts/test
[tpc]: contracts/TokenPriceController.sol
[tpm]: contracts/TokenPriceManager.sol

<p align="center">
	<img src=".github/images/SW DAO Logo Vertical.png#gh-light-mode-only" alt="SW DAO logo" width="15%" />
	<img src=".github/images/SW DAO Logo Vertical Dark.png#gh-dark-mode-only" alt="SW DAO logo" width="15%" />
	<br />
	<h1 align="center">
		Token Price Manager & Controller<br />for <a href="https://www.swdao.org/">SW&nbsp;DAO</a> on <a href="https://polygon.technology/solutions/polygon-pos">Polygon&nbsp;PoS</a>
	</h1>
</p>

Custom solution for centralizing pricing information – allowing for price calls to be made on [SW&nbsp;DAO][] products, ~~[Set tokens][]~~, [Chainlink aggregators][], [Curve pools][], etc. all within one on-chain interface.

> **Note for [TokenPriceManager.sol][tpm]**<br />
> Code paths exist within the current version, which are inaccessible, that were designed to request pricing information directly from the TokenSets oracle. The oracle was found to be inadequate for the needs of this project, but functions have been left in place for compatibility with a future implementation of TokenSet pricing. TokenPriceManagers may not be initiated in "TokenSet mode" in the current version.

## Usage
> Documentation at this time is minimal: just enough to facilitate audits.<br />
> More "user-friendly" documentation is in the works.
### [Manager][tpm]
Token Price Managers (TPMs) are designed to create an easy interface for retrieving and maintaining the price of a given token. These are especially helpful in manually setting the price of structured products, or any other tokens which cannot find a market price through on-chain information. When requesting pricing from TPMs, or using services which request pricing from TPMs, **one must make sure that they trust the operators of these contracts to report truthful/accurate information**.

#### Functionality
- Allows for getting/setting the price of any arbitrary token, with different prices for buying versus selling.
- Allows for setting a "spread fee" which dictates the difference in price between buying, and selling.
- Allows for bypassing fees when a user (`tx.origin`) has an [SWD][] balance above a configured amount.
- Implements time-weighted pricing in order to prevent front-running, or arbitrage upon manual price changes.
- Implements contract ownership – blocking regular users from sensitive functions, and allowing for safe transfer of ownership.
- Implements checks against human error – requiring override for large/destructive changes, preventing "fat-fingering" or "autopilot" transactions.
#### User Functions
- `getTokenPrimary()`<br />
Returns the address of the token which is being priced.
- `getTokenDenominator()`<br />
Returns the address of the token which _prices_ the first token (wETH, USDC, etc.), but may also return the zero-address to indicate that the token is priced in straight USD.
- `getPrice(PriceType)`<br />
Returns both the price itself (with 18 decimals of precision), and the address returned by `getTokenDenominator()`.<br />
For `PriceType`: 0 = `BUY`, 1 = `SELL`, 2 = `RAW`.

See [ITokenPriceManagerMinimal.sol][itpm] for more detail on user functions.
#### Owner Functions
- `constructor(address,address)`<br />
Upon contract creation: sets the token to be priced, the token which the price is reported in (wETH, USDC, etc.), and the contract creator as the owner. If the second token is set to the zero-address, pricing will be reported in straight USD.
- `initialize(uint256,bool,uint8,uint80)`<br />
Activates the contract for use; and sets the price, ~~TokenSet mode~~, spread fee, and [SWD][] balance threshold all at once.
- `setPrice(uint256)`<br />
Manually sets the price, and (typically) initiates a time-weighted price modifier.
	- If the new price is _higher_ than the previous price:
		- The _buy_ price immediately changes to the new price.
		- The _sell_ price changes linearly, over the course of a week, from the previous price to the new price.
	- If the new price is _lower_ than the previous price:
		- The _buy_ price changes linearly, over the course of a week, from the previous price to the new price.
		- The _sell_ price immediately changes to the new price.
- `setPriceOverride()`<br />
Unlocks price changes beyond a 10% difference from the current value.
- `setPriceFeeSpread(uint8)`<br />
Sets the spread fee, configuring the difference between the buy/sell prices.
- ~~`setTokenset(bool)`<br />
Configures whether the TPM will use the TokenSets oracle for pricing.~~
- `setSwdThreshold(uint80)`<br />
Sets the [SWD][] balance threshold at which the user will bypass the spread fees.
- `ownerTransfer(address)`<br />
Transfers the TPM's ownership from its current owner, to the new address. Must be finalized with `ownerConfirm()` within 36 hours.
- `ownerConfirm()`<br />
Finalizes an ownership transfer.
- `withdrawToken(address)`<br />
Rescues mis-sent ERC20 tokens from the contract address.
- `destroyContract()`<br />
Destroys the TPM, but requires an override to call.

See [ITokenPriceManager.sol][] for more detail on all functions.
### [Controller][tpc]
The Token Price Controller creates a centralized location for interfacing with, adding, upgrading, and removing TPMs. It consists of a simple contract which maps token symbols to their respective TMP's address, and maintains an owner who is authorized to make changes to this mapping. As long as a given token has a TPM within the controller, requesting its price becomes as simple as `CONTROLLER.getManager(symbol).getPrice(type)`.
<br /><br />
The Token Price Controller is currently deployed on [Polygon&nbsp;PoS][] at [0x8A46Eb6d66100138A5111b803189B770F5E5dF9a][ca].

#### Functionality
- Implements a mapping from token symbols to respective TPMs.
	- Automatically grabs the token's symbol.
	- Prevents collision.
- Implements contract ownership – blocking regular users from sensitive functions, and allowing for safe transfer of ownership.
#### User Functions
- `getManager(string)`<br />
Returns the address of a TPM which corresponds to the requested token's symbol. Will return the zero-address if no such TPM exists.

See [ITokenPriceControllerMinimal.sol][itpc] for more detail on user functions.
#### Owner Functions
- `constructor()`<br />
Upon contract creation: sets the contract's owner to its creator.
- `managerAdd(address)`<br />
Adds a TPM to the controller.
- `managerUpgrade(address)`<br />
Upgrades a TPM, replacing a symbol's old TPM, in the mapping, with the new one.
- `managerRemove(address)`<br />
Removes a TPM from the controller.
- `symbolRemove(string)`<br />
Removes a TPM from the controller, by its primary token's symbol.
- `ownerTransfer(address)`<br />
Transfers the contract's ownership from its current owner, to the new address. Must be finalized with `ownerConfirm()` within 36 hours.
- `ownerConfirm()`<br />
Finalizes an ownership transfer.
- `destroyContract()`<br />
Destroys the contract, but requires an override to call.

See [TokenPriceController.sol][tpc] for more detail on all functions.
### Adapters
Adapters are contracts which utilize the [ITokenPriceManagerMinimal.sol][itpm] interface, but request pricing data from third-party providers. They are found in the [adapters][] folder, and can be added to the [Token Price Controller][tpc] as if they were TPMs.
<br /><br />
Adapters currently exist for:
1. [Chainlink aggregators][aca].
2. [Curve pools][acp].
## Development
This repository utilizes [Foundry][] for its developer environment. As a result, building/testing of contracts is  relatively simple.
### Building
1. Install [Foundry][] according to its [instructions][fi].
2. `git clone` this repo. with `--recurse-submodules` enabled.
3. `cd` into the cloned repo. and run `forge build`.

### Testing
1. Follow the instructions in the [section](#building) above.
2. Instead of `forge build`, run `forge test`.

Tests can be found in the [test][] folder, and are written in Solidity. This repo. has configured [Foundry][] to fork the [Polygon&nbsp;PoS][] chain during testing. More thorough fuzz testing can be done by passing the `FOUNDRY_PROFILE=fulltest` environment variable before `forge test`.

## Deployment
A few methods are available for contract deployment, but note that the [`TokenPriceController`][tpc] requires no constructor arguments, and the [`TokenPriceManager`][tpm] requires a few ([1](#owner-functions), [2][tpm]).
### Using [Foundry][]
1. Follow the instructions in the ["Building" section](#building) above.
2. Run `forge build`, as requested.
3. Run [`forge create`][fc] with arguments according to your needs.
### Using [Remix][]
This repo. provides flattened contract code in folders titled "verify". These files correspond to each of the major contracts, and can be safely ported into [Remix][] for testing, and deployment. They're also intended for use in [Polygonscan][] verification.
