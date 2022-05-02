// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {ISetToken} from "@tokensets/contracts/interfaces/ISetToken.sol";
import {ISetValuer} from "@tokensets/contracts/interfaces/ISetValuer.sol";
import {IController} from "@tokensets/contracts/interfaces/IController.sol";

import {ResourceIdentifier} from "@tokensets/contracts/protocol/lib/ResourceIdentifier.sol";

library SpecialMath {
	error MathOverflow();

	// Multiplication technique by Remco Bloemen.
	// https://medium.com/wicketh/mathemagic-full-multiply-27650fec525d
	function safeMul(uint256 x, uint256 y) internal pure returns (uint256 r0) {
		uint256 r1;
		assembly {
			let mm := mulmod(x, y, not(0))
			r0 := mul(x, y)
			r1 := sub(sub(mm, r0), lt(mm, r0))
		}
		if (r1 != 0) revert MathOverflow();
	}
}

/// @title Price maintainer for arbitrary tokens
/// @author Peter T. Flynn
/// @notice Maintains a common interface for requesting the price of the given token, with
/// special functionality for TokenSets.
/// @dev Contract must be initialized before use. Price should always be requested using 
/// getPrice(PriceType), rather than viewing the [price] variable. Price returned is dependent
/// on the transactor's SWD balance. Constants require adjustment for deployment outside Polygon. 
contract TokenPriceManager {
	using ResourceIdentifier for IController;

	// @notice Affects the application of the "spread fee" when requesting token price.
	enum PriceType { BUY, SELL, RAW }

	// Storing small variables within a single slot to save gas.
	struct Slot0 {
		// Current owner
		address owner;
		// Balance of SWD required before getPrice() returns spot
		uint80 swdThreshold;
		// Buy/sell spread (in tenths of a percent)
		uint8 pricePercentFeeSpread;
		// Whether [tokenPrimary] is a TokenSet or not
		bool isTokenset;
	}

	struct Slot1 {
		uint40 expiration;
		bytes27 priceModifier;
	}

	address constant SWD = 0xaeE24d5296444c007a532696aaDa9dE5cE6caFD0;
	IController constant TOKENSET_CONTROLLER =
		IController(0x75FBBDEAfE23a48c0736B2731b956b7a03aDcfB2);

	uint216 constant MOST_SIGNIFICANT_BIT_BYTES27 = 
		0x800000000000000000000000000000000000000000000000000000;
	uint8 constant FIRST_BIT = 0x01;

	/// @notice Gas-saving storage slot
	Slot0 public slot0;
	/// @notice Contains info for slowly adjusting buy/sell prices after a manual setPrice()
	Slot1 public priceChangeModifier;
	/// @notice New owner for ownership transfer
	/// @dev May contain the max address for unlocking contract destruction
	address public ownerNew;
	/// @notice Timestamp for ownership transfer timeout
	uint256 public ownerTransferTimeout;
	/// @notice Address of the token to be priced
	address private immutable tokenPrimary;
	/// @notice Token address that denominates the primary token's pricing (ex. USDC/wETH)
	/// @dev In the vast majority of cases, USDC or address(0) is recommended. Address(0)
	/// may be used to indicated USD as a denominator. Using a token with no TokenSet oracle
	/// coverage is not supported, and will result in undefined behavior.
	address private immutable tokenDenominator;
	/// @notice Internal variable used for price tracking
	uint256 public price;
	/// @notice Timestamp timeout for allowing large price changes
	uint256 private priceOverride;

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

	/// @dev Requires that the specified address is a contract
	modifier onlyContract(address _address) {
		if (isNotContract(_address)) revert AddressNotContract();
		_;
	}

	/// @notice See respective variable descriptions for appropriate values. The primary token
	/// must exist prior to contract creation. The msg.sender is the initial contract owner.
	constructor(address _tokenPrimary, address _tokenDenominator)
		onlyContract(_tokenPrimary)
	{
		slot0.owner = msg.sender;
		tokenPrimary = _tokenPrimary;
		tokenDenominator = _tokenDenominator;
		emit ContractCreation(msg.sender, _tokenPrimary, _tokenDenominator);
	}

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
	) external {
		Slot0 memory _slot0 = slot0;
		onlyOwner(_slot0.owner);
		if ((price != 0) || _slot0.isTokenset) revert AlreadySet();
		if (_isTokenset) {
			setTokenset(true);
			_slot0.isTokenset = true;
		} else {
			price = _price;
			emit SetPrice(_slot0.owner, _price);
		}
		_slot0.pricePercentFeeSpread = _fee;
		emit SetPriceFeeSpread(_slot0.owner, _fee);
		_slot0.swdThreshold = _threshold;
		emit SetSwdThreshold(_slot0.owner, _threshold);
		slot0 = _slot0;
	}

	/// @notice Sets the price (Can only be called by the owner)
	/// @param _price The new price in [tokenDenominator], per primary token, which can only
	/// be 10% off from the previous price without an override
	/// (provided in UInt256 format, with 18 decimals of precision, regardless of token's decimals)
	/// @dev Computes a modifier which helps mitigate front-running of price changes
	function setPrice(uint256 _price) external {
		Slot0 memory _slot0 = slot0;
		uint oldPrice = price;
		if (_price == oldPrice) revert AlreadySet();
		onlyOwner(_slot0.owner);
		if (_slot0.isTokenset) revert TokensetPricing();
		if (_price == 0) revert NotTokenset();
		requiresOverride(_price);
		if (priceOverride != 0) priceOverride = 0;
		if (oldPrice != 0) {
			Slot1 memory _priceChangeModifier = priceChangeModifier;
			if (_price > oldPrice) {
				_priceChangeModifier.expiration = uint40(block.timestamp + 1 weeks);
				_priceChangeModifier.priceModifier =
					bytes27(uint216((_price - oldPrice) / 1 weeks));
				if (uint216(_priceChangeModifier.priceModifier) & MOST_SIGNIFICANT_BIT_BYTES27 != 0)
					revert SpecialMath.MathOverflow();
				_priceChangeModifier.priceModifier =
					bytes27(uint216(_priceChangeModifier.priceModifier << 1) | FIRST_BIT);
			} else {
				_priceChangeModifier.expiration = uint40(block.timestamp + 1 weeks);
				_priceChangeModifier.priceModifier =
					bytes27(uint216((oldPrice - _price) / 1 weeks));
				if (uint216(_priceChangeModifier.priceModifier) & MOST_SIGNIFICANT_BIT_BYTES27 != 0)
					revert SpecialMath.MathOverflow();
				_priceChangeModifier.priceModifier =
					_priceChangeModifier.priceModifier << 1;
			}
			priceChangeModifier = _priceChangeModifier;
		}
		price = _price;
		emit SetPrice(_slot0.owner, _price);
	}

	/// @notice Initiates a pricing override (Can only be called by the owner)
	function setPriceOverride() external {
		address _owner = slot0.owner;
		onlyOwner(_owner);
		uint256 _endTime = block.timestamp + 1 hours;
		priceOverride = _endTime;
		emit SetPriceOverride(_owner, _endTime);
	}

	/// @notice Sets the buy/sell fee, in the form of a price spread
	/// (Can only be called by the owner)
	/// @dev Fee can range from 0% to 25.5%, in 0.1% increments, and is stored as such
	/// to fit into [slot0]
	/// @param _fee The fee, with a max of 25.5% (in tenths of a percent: ex. 1 = 0.1%)
	function setPriceFeeSpread(uint8 _fee) external {
		Slot0 memory _slot0 = slot0;
		onlyOwner(_slot0.owner);
		_slot0.pricePercentFeeSpread = _fee;
		slot0 = _slot0;
		emit SetPriceFeeSpread(_slot0.owner, _fee);
	}

	/// @notice Sets whether the primary token is treated as a TokenSet
	/// (Can only be called by the owner)
	/// @param _isTokenset "True" for TokenSet, or "false" for standard
	function setTokenset(bool _isTokenset) public {
		Slot0 memory _slot0 = slot0;
		address _tokenPrimary = tokenPrimary;
		onlyOwner(_slot0.owner);
		if (_isTokenset) {
			if (_slot0.isTokenset) revert AlreadySet();
			if (!TOKENSET_CONTROLLER.isSet(_tokenPrimary)) revert NotTokenset();
			uint256 _price = getTokensetPrice();
			requiresOverride(_price);
			_slot0.isTokenset = true;
			price = 0;
			emit SetPrice(_slot0.owner, _price);
		} else {
			if (!_slot0.isTokenset) revert AlreadySet();
			_slot0.isTokenset = false;
			uint256 _price = getTokensetPrice();
			requiresOverride(_price);
			price = _price;
			emit SetPrice(_slot0.owner, _price);
		}
		slot0 = _slot0;
		emit SetTokenset(_slot0.owner, _isTokenset);
	}

	/// @notice  Sets the number of SWD in a transactor's address required for getPrice()
	/// to return spot, rather than charging a fee (Can only be called by the owner)
	/// @dev Stored as uint80 to fit into [slot0], as SWD's max supply is sufficiently low 
	/// @param _threshold Number of SWD (UInt256 format, with 18 decimals)
	function setSwdThreshold(uint80 _threshold) external {
		Slot0 memory _slot0 = slot0;
		onlyOwner(_slot0.owner);
		_slot0.swdThreshold = _threshold;
		slot0 = _slot0;
		emit SetSwdThreshold(_slot0.owner, _threshold);
	}

	/// @notice Initiates an ownership transfer, but the new owner must call ownerConfirm()
	/// within 36 hours to finalize (Can only be called by the owner)
	/// @param _ownerNew The new owner's address
	function ownerTransfer(address _ownerNew) external {
		onlyOwner(slot0.owner);
		ownerNew = _ownerNew;
		ownerTransferTimeout = block.timestamp + 36 hours;
		emit OwnerTransfer(msg.sender, _ownerNew);
	}

	/// @notice Finalizes an ownership transfer (Can only be called by the new owner)
	function ownerConfirm() external {
		if (msg.sender != ownerNew) revert Unauthorized();
		if (block.timestamp > ownerTransferTimeout) revert TimerExpired();
		address _ownerOld = slot0.owner;
		slot0.owner = ownerNew;
		ownerNew = address(0);
		ownerTransferTimeout = 0;
		emit OwnerConfirm(msg.sender, _ownerOld);
	}

	/// @notice Used to rescue mis-sent tokens from the contract address (Can only be called
	/// by the contract owner)
	/// @param _token The address of the token to be rescued
	function withdrawToken(address _token) external {
		address _owner = slot0.owner;
		onlyOwner(_owner);
		bool success = IERC20(_token).transfer(
			_owner,
			IERC20(_token).balanceOf(address(this))
		);
		if (!success) revert TransferFailed();
		emit WithdrawToken(_owner, _token);
	}

	/// @notice Destroys the contract when it's no longer needed (Can only be called by the owner)
	/// @dev Only allows selfdestruct() after the variable [ownerNew] has been set to its
	/// max value, in order to help mitigate human error
	function destroyContract() external {
		address payable _owner = payable(slot0.owner);
		onlyOwner(_owner);
		if (ownerNew != 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)
			revert UnlockDestruction();
		emit SelfDestruct(_owner);
		selfdestruct(_owner);
	}

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
	/// @return address Current [tokenDenominator]
	function getPrice(PriceType priceType) public view returns (uint256, address) {
		Slot0 memory _slot0 = slot0;
		uint256 _price;
		if (_slot0.isTokenset) {
			_price = getTokensetPrice();
			if (_price == 0) revert TokensetContractError();
			return (
				addSubFee(
					_price,
					_slot0.pricePercentFeeSpread,
					priceType,
					_slot0.swdThreshold,
					true
				),
				tokenDenominator
			);
		}
		_price = price;
		if (_price == 0) revert NotInitialized();
		return (
			addSubFee(
				_price,
				_slot0.pricePercentFeeSpread,
				priceType,
				_slot0.swdThreshold,
				false
			),
			tokenDenominator
		);
	}

	/// @return address Current [tokenPrimary]
	function getTokenPrimary() external view returns (address) {
		return tokenPrimary;
	}

	/// @return address Current [tokenDenominator]
	function getTokenDenominator() external view returns (address) {
		return tokenDenominator;
	}

	// Prevents calls from non-owner. Purposefully not made a modifier, so as to work well
	// with [slot0], and save gas.
	function onlyOwner(address _owner) private view {
		if (msg.sender != _owner) revert Unauthorized();
	}

	// Abstraction for better readability. 
	function getTokensetPrice() private view returns (uint256) {
		revert("TokenSet pricing disabled");
		return
			TOKENSET_CONTROLLER.getSetValuer().calculateSetTokenValuation(
				ISetToken(tokenPrimary),
				tokenDenominator
			);
	}

	// Requires on override if the price is to be changed by more than 10%. Done to mitigate
	// human error.
	function requiresOverride(uint256 _price) private view {
		if (price == 0) return;
		if (block.timestamp > priceOverride) {
			if (
				(_price > SpecialMath.safeMul(price, 11) / 10) ||
				(_price < SpecialMath.safeMul(price, 9) / 10)
			) revert RequiresOverride();
		}
	}

	// Checks if a given address is not a contract.
	function isNotContract(address _addr) private view returns (bool) {
		return (_addr.code.length == 0);
	}

	// Adds a fee, dependent on whether tx.origin holds SWD above the threshold,
	// whether there's a time-based modifier in place, and whether it's a buy/sell.
	function addSubFee(
		uint256 _price,
		uint8 _fee,
		PriceType priceType,
		uint80 _threshold,
		bool isTokenset
	) private view returns (uint256) {
		Slot1 memory _priceChangeModifier = priceChangeModifier;
		if (
			_priceChangeModifier.expiration > block.timestamp &&
			priceType != PriceType.RAW &&
			isTokenset == false
		) {
			uint priceUnmod;
			if (IERC20(SWD).balanceOf(tx.origin) >= _threshold) {
				priceUnmod = _price;
			} else {
				// Values below are not arbitrary. Math utilizes [_fee] as a percentage in tenths
				// of a percent.
				priceUnmod = SpecialMath.safeMul(
					_price,
					(uint8(priceType) != 0) ? 1000 - _fee : 1000 + _fee
				) / 1000;
			}
			if (uint216(_priceChangeModifier.priceModifier) & FIRST_BIT == 0) {
				if (priceType == PriceType.BUY) {
					_price += SpecialMath.safeMul(
						uint216(_priceChangeModifier.priceModifier >> 1),
						(_priceChangeModifier.expiration - block.timestamp)
					);
					return (priceUnmod > _price) ? priceUnmod : _price;
				}
			} else {
				if (priceType == PriceType.SELL) {
					_price -= SpecialMath.safeMul(
						uint216(_priceChangeModifier.priceModifier >> 1),
						(_priceChangeModifier.expiration - block.timestamp)
					);
					return (priceUnmod < _price) ? priceUnmod : _price;
				}
			}
		}
		if (
			IERC20(SWD).balanceOf(tx.origin) >= _threshold ||
			priceType == PriceType.RAW
		) return _price;
		// Values below are not arbitrary. Math utilizes [_fee] as a percentage in tenths
		// of a percent.
		return
			SpecialMath.safeMul(
				_price,
				(uint8(priceType) != 0) ? 1000 - _fee : 1000 + _fee
			) / 1000;
	}
}