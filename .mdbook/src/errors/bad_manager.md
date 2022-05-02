## `BadManager()` — Reverts with `0xbe6b4759`
**Occurs when the the requested address is not a `TokenPriceManager`, and does not follow the
standard `ITokenPriceManagerMinimal` interface.**

When calling `managerAdd(...)`, or `managerUpgrade(...)` with an address that does not adhere to the `ITokenPriceManagerMinimal` interface, the controller has no method for accessing the required information, and so it fails: returning this error.