## `NotTokenset()` — Reverts with `0x70dea83f`
**Occurs when you've tried to manually set the price to zero.**

A `TokenPriceManager` may keep an internal `price` of zero, but only when it's in "TokenSet
mode", and it does not need to be set manually.