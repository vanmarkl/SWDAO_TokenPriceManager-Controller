[init]: ../functions/tpm/write/initialize.md

## `NotInitialized()` — Reverts with `0x87138d5c`
**Occurs if the contract fails an internal consistency check during a price request.**

This error only emits from a `TokenPriceManager`. Is the manager in use properly initialized? If
the manager is not in "TokenSet mode", and the price is set to zero, this error will occur. Such
a thing should only be possible before the manager has been initialized.

Call [`initialize(...)`][init] to resolve.