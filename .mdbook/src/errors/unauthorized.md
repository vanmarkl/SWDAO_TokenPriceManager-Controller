[oc]: ../functions/tpm/write/owner_confirm.md

## `Unauthorized()` — Reverts with `0x82b42900`
**Occurs when the function you are trying to call is not available to your wallet's address.** 

Double-check your wallet — are you using the address which owns the contract?

You may also get this error if you are attempting to use [`ownerConfirm()`][oc] with an address
which has not been designated as the new owner. Only the new owner may call
[`ownerConfirm()`][oc], so as to prevent ownership transfers to inaccessible addresses.