[foundry]: https://github.com/foundry-rs/foundry
[remix]: https://remix.ethereum.org/

# How do I deploy a Token Price Manager?
There are several methods for deployment — the easiest being [Foundry][] (the native dev. environment for these contracts), and [Remix][]. Since this documentation assumes very little developer knowledge, this guide will be using [Remix][].

## Access
Browse to [`https://remix.ethereum.org/`][remix] — on the first page you'll spot a button labelled `GitHub` under `File -> LOAD FROM:`. Press it, and you'll be greeted with a pop-up window. Enter the URL below into the field, and press `Import`.
```
https://github.com/Peter-Flynn/SWDAO_TokenPriceManager-Controller/blob/master/contracts/verify/TokenPriceManager.sol
```
In the left-hand panel, press `TokenPriceManager.sol`.
## Compilation