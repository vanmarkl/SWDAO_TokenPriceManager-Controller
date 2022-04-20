// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import "../interfaces/ITokenPriceManagerMinimal.sol";
import {AggregatorV2V3Interface} from "@chainlink/src/v0.8/interfaces/AggregatorV2V3Interface.sol";

/// @title TokenPriceManager-style interface for ChainLink price aggregators
/// @author Peter T. Flynn
/// @notice Creates an interface, common with other TokenPriceManagers, which gets data from a
/// a ChainLink price aggregator
/// @dev All variables are set at creation time - both for security, and for simplicity
contract ChainlinkPriceRelay is ITokenPriceManagerMinimal {
	/// @notice The address of the ChainLink price aggregator used to 
	/// price [tokenPrimary] in [tokenDenominator]
	/// @dev The aggregator's decimal precision may vary
	AggregatorV2V3Interface public immutable chainlinkOracle;
	/// @notice The address of the token which the ChainLink price aggregator prices
	/// @dev Must match what's returned by the [chainlinkOracle]
	address private immutable tokenPrimary;
	/// @notice The address of the token which the ChainLink price aggregator
	/// prices [tokenPrimary] in (must be address(0) for USD denomination)
	/// @dev Must match what's returned by the [chainlinkOracle]
	address private immutable tokenDenominator;

	/// @notice Returned when the ChainLink price aggregator returns bad data
	error ChainlinkPriceNegative();
	/// @notice Returned when the ChainLink price aggregator returns data older than 24 hours
	error ChainlinkDataStale();

	/// @notice See respective variable comments for guidance on arguments
	constructor(
		AggregatorV2V3Interface _chainlinkOracle,
		address _tokenPrimary,
		address _tokenDenominator
	) {
		chainlinkOracle = _chainlinkOracle;
		tokenPrimary = _tokenPrimary;
		tokenDenominator = _tokenDenominator;
	}

	/// @return uint256 The price reported by ChainLink for the [tokenPrimary]
	/// (denominated in [tokenDenominator], with 18 decimals of precision)
	/// @return address The [tokenDenominator]
	/// @dev Takes in an [ITokenPriceManagerMinimal.PriceType] for compatibility with the
	/// ITokenPriceManagerMinimal interface, but it is not used here.
	function getPrice(PriceType) external view returns (uint256, address) {
		(, int256 answer,, uint256 updatedAt,) = chainlinkOracle.latestRoundData();
		if (answer <= 0) revert ChainlinkPriceNegative();
		if (updatedAt < block.timestamp - 1 days) revert ChainlinkDataStale();
		return (
			uint(answer) * (10 ** (18 - chainlinkOracle.decimals())), // Scale for 18 decimals
			tokenDenominator
		);
	}

	/// @return address The token which is being priced
	function getTokenPrimary() external view returns (address) { return tokenPrimary; }

	/// @return address The token which prices the primary token, may be address(0) to indicate USD
	function getTokenDenominator() external view returns (address) { return tokenDenominator; }
}
