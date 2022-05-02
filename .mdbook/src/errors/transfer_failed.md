## `TransferFailed()` — Reverts with `0x90b8ec18`
**Occurs when the attempted ERC-20 transfer fails.**

This happens when the ERC-20 in question has rejected your attempt at a transfer. Typically, this
means that the token should be ignored. If it is important that this transfer succeed, reach out
to the creator of the token to diagnose why the transfer is failing.