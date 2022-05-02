## `UnlockDestruction()` — Reverts with `0xb512d8b9`
**Occurs when a contract destruction is attempted, without unlocking this action.**

Contract destruction is a permanent action — as such, it's locked behind preventative measures. Ensure that the contract is not currently in use before considering destruction.

To unlock `destroyContract()`, call `ownerTransfer(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)`.
`0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF` is not a valid address, so it will not successfully
transfer ownership, but it will allow the current owner to call `destroyContract()`.