## `AlreadyExists()` — Reverts with `0x23369fa6`
**Occurs when `managerAdd(...)` is called, but such a manager already exists.**

The `TokenPriceController` manages each `TokenPriceManager` based on the symbol of the
respective, priced token. If a manager which prices "wETH" exists within the controller, no
other "wETH" manager may be added, even if each type of "wETH" uses a different address. If you
seek to replace a manager, use `managerUpgrade(...)` instead.