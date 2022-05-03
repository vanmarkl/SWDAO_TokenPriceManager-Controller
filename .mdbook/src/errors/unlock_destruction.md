## `UnlockDestruction()` — Reverts with `0xb512d8b9`
**Occurs when a contract destruction is attempted, without unlocking this action.**

Contract destruction is a permanent action — as such, it's locked behind preventative measures. Ensure that the contract is not currently in use before considering destruction. The only reason one would want to destroy a contract is for its large gas refund, so make sure that you're performing some other action in the same transaction, otherwise the refund will be wasted. Saving up contracts to destroy, for this purpose, is recommended.

To unlock `destroyContract()`, call `ownerTransfer(...)` with
`0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF`. This is not a valid address, so it will not
successfully transfer ownership, but it will allow the current owner to call
`destroyContract()`.