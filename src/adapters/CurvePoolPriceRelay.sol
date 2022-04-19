// SPDX-License-Identifier: Apache 2.0
pragma solidity ^0.8.0;

import {ITokenPriceManagerMinimal} from "../interfaces/ITokenPriceManagerMinimal.sol";

interface CurvePool {
	function get_virtual_price() external view returns (uint);
}

interface CurveToken {
	function minter() external view returns (CurvePool);
}

/// @title TokenPriceManager-style interface for Curve LP tokens
/// @author Peter T. Flynn
/// @notice Creates an interface, common with other TokenPriceManagers, which gets data from a
/// a Curve pool, corresponding to the selected LP token
/// @dev All variables are set at creation time - both for security, and for simplicity
contract CurvePoolPriceRelay is ITokenPriceManagerMinimal {
	/// @notice The address of the token to be priced
	CurveToken private immutable tokenPrimary;
	/// @notice The address of the Curve pool used for pricing [tokenPrimary]
	CurvePool private immutable curvePool;

	/// @notice Returns when the chosen [tokenPrimary] does not use the known Curve interface
	error BadToken();
	/// @notice Returns when the Curve pool returns a [virtual_price] of 0
	error BadPrice();

	/// @notice Fetches the appropriate Curve pool used for pricing the requested [tokenPrimary]
	constructor(CurveToken _tokenPrimary) {
		tokenPrimary = _tokenPrimary;
		curvePool = _tokenPrimary.minter();
		if (address(curvePool) == address(0)) revert BadToken();
		if (curvePool.get_virtual_price() == 0) revert BadPrice();
	}

	/// @return price The price reported by the Curve pool for the [tokenPrimary]
	/// (denominated in USD, with 18 decimals of precision)
	/// @return address Address(0), indicating pricing in USD, and conforming with
	/// the TokenPriceManager interface
	/// @dev Takes in an [ITokenPriceManagerMinimal.PriceType] for compatibility with the
	/// ITokenPriceManagerMinimal interface, but it is not used here.
	function getPrice(PriceType) external view returns (uint price, address) {
		price = curvePool.get_virtual_price();
		if (price == 0) revert BadPrice();
	}

    /// @return address The token which is being priced
    function getTokenPrimary() external view returns (address) { return address(tokenPrimary); }

    /// @return address Always address(0), indicating that the price is in USD,
	/// in accordance with the ITokenPriceManager interface
    function getTokenDenominator() external pure returns (address) { return address(0); }
}
