## `AlreadySet()` — Reverts with `0xa741a045`
**Occurs when a requested change has already been set.**

If a transaction would result in no change, you may see this error. Additionally, you will see
this error if you're trying to `initialize(...)` a contract which has already been initialized.