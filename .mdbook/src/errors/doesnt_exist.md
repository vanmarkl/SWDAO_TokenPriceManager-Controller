## `DoesntExist()` — Reverts with `0x80375d5a`
**Occurs when `managerRemove(...)`, or `symbolRemove(...)` requests the removal of a
manager/symbol which doesn't exist within the controller.**

Double-check your address, or symbol. The manager that you're attempting to remove may have
already been removed.