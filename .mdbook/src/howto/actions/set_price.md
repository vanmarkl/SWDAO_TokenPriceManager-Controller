[added to a controller]: add_manager.md
[current price]: ../data/find_price.md
[deployed]: deploy_tpm.md
[fc]: https://book.getfoundry.sh/cast/index.html
[find it]: ../data/find_manager.md
[polygonscan]: https://polygonscan.com/
[separate contract]:
https://github.com/Peter-Flynn/SWDAO_TokenPriceManager-Controller/blob/master/contracts/interfaces/ITokenPriceManager.sol
[troubleshooting pages]: ../../troubleshooting.md

# How do I set the price of a token?
Pricing is managed through a `TokenPriceManager` — ensure that you have one [deployed][], and
[added to a controller][].

You'll need to initiate a transaction with the `TokenPriceManager` which manages the token you'd
like to price. Through the manager's address: one can use [Polygonscan][], [`forge cast`][fc], a
[separate contract][], etc. to perform the following actions. If you don't know the address for
the appropriate manager, you can [find it][].

If the new price is 10% more, or less, than the [current price][], an override is required.
Otherwise, skip to the section labelled "[Basic](#basic)" below.
## Override
Managers mitigate human error by requiring an override for large changes.

Call `setPriceOverride()`. This will initiate an hour-long timer, within which the manager will
allow any price changes, no matter how drastic. Please take care, and double-check your inputs
while in override mode. The only price not allowed is zero.

Continue to the section labelled "[Basic](#basic)" below.

## Basic

You'll need to call `setPrice(uint256)`.

This function takes one input: the new price (formatted with 18-decimals of precision).

{{#include ../../include/uint256_18dec.md}}

If your input is valid, the transaction will succeed. If it fails, see the
[troubleshooting pages][] for information on the given error code. If you can't find the
appropriate error code, your error may be coming from elsewhere.