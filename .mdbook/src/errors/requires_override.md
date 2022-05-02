## `RequiresOverride()` — Reverts with `0xf8245615`
**Occurs when the requested price will change the price by more than 10%**

Changing the price by more than 10% is prevented by default. This protection is in place to
prevent costly human-error. This protection can be overridden by calling `setPriceOverride()`.
This override will only last for one hour, or until a price change is made (whichever comes
first).