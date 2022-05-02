## `TimerExpired()` — Reverts with `0x9adbb204`
**Occurs when the new owner (during an ownership transfer) tries to call `ownerConfirm()` after
the 36-hour timer has expired.**

The current owner will have to call `ownerTransfer(...)` again to restart the timer.