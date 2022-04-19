// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

/// @title Price maintainer for arbitrary tokens
/// @author Peter T. Flynn
/// @notice Maintains a common interface for requesting the price of the given token, with
/// special functionality for TokenSets.
/// @dev Contract must be initialized before use. Price should always be requested using 
/// getPrice(PriceType), rather than viewing the [price] variable. Price returned is dependent
/// on the transactor's SWD balance. Constants require adjustment for deployment outside Polygon. 
interface ITokenPriceManager {
    // @notice Affects the application of the "spread fee" when requesting token price.
    enum PriceType { BUY, SELL, RAW }

    /// @notice Sets all variables that are required to operate the contract
    /// (Can only be called once) (Can only be called by the owner)
    /// @dev Setting [_isTokenset] to "true" will cause [_price] to be ignored
    /// @param _price The starting price in [tokenDenominator], per primary token
    /// (provided in UInt256 format, with 18 decimals of precision, regardless of token's decimals)
    /// @param _isTokenset Whether the priced token is a TokenSet or not
    /// @param _fee The buy/sell spread fee (in tenths of a percent)
    /// @param _threshold The number of SWD required before getPrice() returns spot
    function initialize(
        uint256 _price,
        bool _isTokenset,
        uint8 _fee,
        uint80 _threshold
    ) external;

    /// @notice Sets the price (Can only be called by the owner)
    /// @param _price The new price in [tokenDenominator], per primary token, which can only
    /// be 10% off from the previous price without an override
    /// (provided in UInt256 format, with 18 decimals of precision, regardless of token's decimals)
    function setPrice(uint256 _price) external;

    /// @notice Initiates a pricing override (Can only be called by the owner)
    function setPriceOverride() external;

    /// @notice Sets the buy/sell fee, in the form of a price spread
    /// (Can only be called by the owner)
    /// @dev Fee can range from 0% to 25.5%, in 0.1% increments, and is stored as such
    /// to fit into [slot0]
    /// @param _fee The fee, with a max of 25.5% (in tenths of a percent: ex. 1 = 0.1%)
    function setPriceFeeSpread(uint8 _fee) external;

    /// @notice Sets whether the primary token is treated as a TokenSet
    /// (Can only be called by the owner)
    /// @param _isTokenset "True" for TokenSet, or "false" for standard
    function setTokenset(bool _isTokenset) external;

    /// @notice  Sets the number of SWD in a transactor's address required for getPrice()
    /// to return spot, rather than charging a fee (Can only be called by the owner)
    /// @dev Stored as uint80 to fit into [slot0], as SWD's max supply is sufficiently low 
    /// @param _threshold Number of SWD (UInt256 format, with 18 decimals)
    function setSwdThreshold(uint80 _threshold) external;

    /// @notice Initiates an ownership transfer, but the new owner must call ownerConfirm()
    /// within 36 hours to finalize (Can only be called by the owner)
    /// @param _ownerNew The new owner's address
    function ownerTransfer(address _ownerNew) external;

    /// @notice Finalizes an ownership transfer (Can only be called by the new owner)
    function ownerConfirm() external;

    /// @notice Used to rescue mis-sent tokens from the contract address (Can only be called
    /// by the contract owner)
    /// @param _token The address of the token to be rescued
    function withdrawToken(address _token) external;

    /// @notice Gets the current price of the primary token, denominated in [tokenDenominator]
    /// @dev Returns a different value, depending on the SWD balance of tx.origin's wallet.
    /// If the balance is over the threshold, getPrice() will return the price unmodified,
    /// otherwise it adds the dictated fee. Tx.origin is purposefully used over msg.sender,
    /// so as to be compatible with DEx aggregators. As a side effect, this makes it incompatible
    /// with relays. Price is always returned with 18 decimals of precision, regardless of token
    /// decimals. Manual adjustment of precision must be done later for [tokenDenominator]s
    /// with less precision.
    /// @param priceType "BUY" for buying, "SELL" for selling,
    /// and "RAW" for a direct price request.
    /// @return uint256 Current price in [tokenDenominator], per primary token.
    /// @return address Current [tokenDenominator], may be address(0) to indicate USD
    function getPrice(PriceType priceType) external view returns (uint256, address);

    /// @return address Current [tokenPrimary]
    function getTokenPrimary() external view returns (address);

    /// @return address Current [tokenDenominator], may be address(0) to indicate USD
    function getTokenDenominator() external view returns (address);

    /// @notice Emitted when the contract is created
    /// @param sender The contract creator
    /// @param primary The token configured as [tokenPrimary]
    /// @param denominator The token configured as [tokenDenominator]
    event ContractCreation(
        address indexed sender,
        address primary,
        address denominator
    );

    /// @notice Emitted when the price is manually changed
    /// @param sender The transactor
    /// @param _price The new price
    event SetPrice(address indexed sender, uint256 _price);
    /// @notice Emitted when the price override is engaged
    /// @param sender The transactor
    /// @param endTime The timestamp when the override expires
    event SetPriceOverride(address indexed sender, uint256 endTime);
    /// @notice Emitted when the buy/sell fee is changed
    /// @param sender The transactor
    /// @param fee The new fee
    event SetPriceFeeSpread(address indexed sender, uint8 fee);
    /// @notice Emitted when primary token's TokenSet status is changed
    /// @param sender The transactor
    /// @param _isTokenset The new TokenSet status
    event SetTokenset(address indexed sender, bool _isTokenset);
    /// @notice Emitted when the SWD threshold is changed
    /// @param sender The transactor
    /// @param threshold The new SWD threshold
    event SetSwdThreshold(address indexed sender, uint80 threshold);
    /// @notice Emitted when an ownership transfer has been initiated
    /// @param sender The transactor
    /// @param newOwner The address designated as the potential new owner
    event OwnerTransfer(address indexed sender, address newOwner);
    /// @notice Emitted when an ownership transfer is confirmed
    /// @param sender The transactor, and new owner
    /// @param oldOwner The old owner
    event OwnerConfirm(address indexed sender, address oldOwner);
    /// @notice Emitted when a mis-sent token is rescued from the contract
    /// @param sender The transactor
    /// @param token The token rescued
    event WithdrawToken(address indexed sender, address indexed token);
    /// @notice Emitted when the contract is destroyed
    /// @param sender The transactor
    event SelfDestruct(address sender);

    /// @notice Returned when the sender is not authorized to call a specific function
    error Unauthorized();
    /// @notice Returned when the contract has not been initialized
    error NotInitialized();
    /// @notice Returned when one, or more, of the parameters is 
    /// required to be a contract, but is not
    error AddressNotContract();
    /// @notice Returned when a requested configuration would result in no state change.
    error AlreadySet();
    /// @notice Returned when manual pricing is attempted on a TokenSet
    error TokensetPricing();
    /// @notice Returned when TokenSet-based pricing is requested for a token that is not a Set.
    error NotTokenset();
    /// @notice Returned when the external TokenSet Controller fails
    error TokensetContractError();
    /// @notice Returned when the requested pricing change requires an override
    error RequiresOverride();
    /// @notice Returned when the block's timestamp is passed the expiration timestamp for
    /// the requested action
    error TimerExpired();
    /// @notice Returned when the requested contract destruction requires an unlock
    error UnlockDestruction();
    /// @notice Returned when the requested token can not be transferred
    error TransferFailed();
}