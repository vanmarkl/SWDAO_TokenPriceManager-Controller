[tpc]: https://github.com/Peter-Flynn/SWDAO_TokenPriceManager-Controller/blob/master/contracts/TokenPriceController.sol
[tpm]: https://github.com/Peter-Flynn/SWDAO_TokenPriceManager-Controller/blob/master/contracts/TokenPriceManager.sol

# Troubleshooting
Both the [`TokenPriceManager`][tpm], and [`TokenPriceController`][tpc] contracts are written in
a version of Solidity which allows "functions" to be returned as errors. Depending on your
scanner, wallet, or development software, the contract may revert with legible function names,
or with an 8-digit hex. code. All (accessible) error codes are presented in the following
sections with descriptions, and suggestions.