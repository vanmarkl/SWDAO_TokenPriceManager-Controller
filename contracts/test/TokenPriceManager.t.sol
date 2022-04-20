// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.0;

import "ds-test/test.sol";
import "../TokenPriceManager.sol";

interface Hevm {
    function warp(uint256) external;
    // Set block.timestamp

    function roll(uint256) external;
    // Set block.number

    function fee(uint256) external;
    // Set block.basefee

    function load(address account, bytes32 slot) external returns (bytes32);
    // Loads a storage slot from an address

    function store(address account, bytes32 slot, bytes32 value) external;
    // Stores a value to an address' storage slot

    function sign(uint256 privateKey, bytes32 digest) external returns (uint8 v, bytes32 r, bytes32 s);
    // Signs data

    function addr(uint256 privateKey) external returns (address);
    // Computes address for a given private key

    function ffi(string[] calldata) external returns (bytes memory);
    // Performs a foreign function call via terminal

    function prank(address) external;
    // Sets the *next* call's msg.sender to be the input address

    function startPrank(address) external;
    // Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called

    function prank(address, address) external;
    // Sets the *next* call's msg.sender to be the input address, and the tx.origin to be the second input

    function startPrank(address, address) external;
    // Sets all subsequent calls' msg.sender to be the input address until `stopPrank` is called, and the tx.origin to be the second input

    function stopPrank() external;
    // Resets subsequent calls' msg.sender to be `address(this)`

    function deal(address who, uint256 newBalance) external;
    // Sets an address' balance

    function etch(address who, bytes calldata code) external;
    // Sets an address' code

    function expectRevert() external;
    function expectRevert(bytes calldata) external;
    function expectRevert(bytes4) external;
    // Expects an error on next call

    function record() external;
    // Record all storage reads and writes

    function accesses(address) external returns (bytes32[] memory reads, bytes32[] memory writes);
    // Gets all accessed reads and write slot from a recording session, for a given address

    function expectEmit(bool, bool, bool, bool) external;
    // Prepare an expected log with (bool checkTopic1, bool checkTopic2, bool checkTopic3, bool checkData).
    // Call this function, then emit an event, then call a function. Internally after the call, we check if
    // logs were emitted in the expected order with the expected topics and data (as specified by the booleans)

    function mockCall(address, bytes calldata, bytes calldata) external;
    // Mocks a call to an address, returning specified data.
    // Calldata can either be strict or a partial match, e.g. if you only
    // pass a Solidity selector to the expected calldata, then the entire Solidity
    // function will be mocked.

    function clearMockedCalls() external;
    // Clears all mocked calls

    function expectCall(address, bytes calldata) external;
    // Expect a call to an address with the specified calldata.
    // Calldata can either be strict or a partial match

    function getCode(string calldata) external returns (bytes memory);
    // Gets the bytecode for a contract in the project given the path to the contract.

    function label(address _addr, string calldata _label) external;
    // Label an address in test traces

    function assume(bool) external;
    // When fuzzing, generate new inputs if conditional not met
}

enum PriceType { BUY, SELL, RAW }

contract ContractTest_Manager is DSTest {

	Hevm constant VM = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

	address constant SWAP = 0x25Ad32265c9354c29e145c902aE876f6B69806F2;
	address constant SWYF = 0xDC8d88d9E57CC7bE548F76E5e413C4838F953018;
	address constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
	address constant SWD = 0xaeE24d5296444c007a532696aaDa9dE5cE6caFD0;

	address constant TREASURY = 0x480554E3e14Dd6b9d8C29298a9C57BB5fA51F926;

	TokenPriceManager swapManager;
	TokenPriceManager swyfManager;

	function setUp() public {
		swapManager = new TokenPriceManager(SWAP, USDC);
		swyfManager = new TokenPriceManager(SWYF, USDC);
		swapManager.initialize(84140000000000000000, false, 1, 100000000000000000000);
		swyfManager.initialize(1140000000000000000, false, 1, 100000000000000000000);
	}

	function testFail_badInitialize(uint x, bool b, uint8 y, uint80 z) public {
		swyfManager.initialize(x, b, y, z);
	}

/*
	function testFail_setPriceOfTokenset(uint x) public {
		swapManager.setPrice(x);
	}
*/

	function test_onlyOwner() public {
		bytes[8] memory calls = [
			abi.encodeWithSignature("setPrice(uint256)", swapManager.price()),
			abi.encodeWithSignature("setPriceOverride()"),
			abi.encodeWithSignature("setPriceFeeSpread(uint8)", 100),
			abi.encodeWithSignature("setTokenset(bool)", false),
			abi.encodeWithSignature("setSwdThreshold(uint80)", 10000000),
			abi.encodeWithSignature("ownerTransfer(address)", 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
			abi.encodeWithSignature("withdrawToken(address)", 0xDC8d88d9E57CC7bE548F76E5e413C4838F953018),
			abi.encodeWithSignature("destroyContract()")
		];
		VM.startPrank(TREASURY, TREASURY);
		for (uint i = 0; i < calls.length; i++) {
			(bool success, ) = address(swapManager).call(calls[i]);
			if (success)
				revert("ownerOnly() called by not-Owner.");
		}
		VM.stopPrank();
	}

	function test_setPrice(uint x/*, bool b*/) public {
		/*
		if (b) {
			VM.expectRevert(getSelector("TokensetPricing()"));
			swapManager.setPrice(x);
		}
		*/
		uint _currentPrice = swyfManager.price();
		if (x == 0) {
			VM.expectRevert(getSelector("NotTokenset()"));
		} else {
			if (requiresOverride(x, _currentPrice))
				VM.expectRevert(getSelector("RequiresOverride()"));
		}
		swyfManager.setPrice(x);
	}

	function test_setPriceAndOverride(uint232 x, bool b, bool y) public {
		uint _x = x;
		if (_x != 0) {
			if (!requiresOverride(x, swyfManager.price())) {
				_x = (SpecialMath.safeMul(_x, b ? 9 : 11) / 10);
				if (b) {
					_x -= 1;
				} else {
					_x += 1;
				}
			}
			if (y) {
				swyfManager.setPriceOverride();
			} else {
				VM.expectRevert(getSelector("RequiresOverride()"));
			}
		} else {
			VM.expectRevert(getSelector("NotTokenset()"));
		}
		swyfManager.setPrice(_x);
	}

/*
	function test_setTokenset(uint248 x, bool b) public {
		if (x == 0) {
			swapManager.setTokenset(false);
			swapManager.setTokenset(true);
			VM.expectRevert(getSelector("AlreadySet()"));
			swapManager.setTokenset(true);
		} else {
			uint _oldPrice;
			if (b) {
				VM.prank(TREASURY, TREASURY);
				(_oldPrice, ) = swapManager.getPrice(TokenPriceManager.PriceType.RAW);
			} else {
				(_oldPrice, ) = swapManager.getPrice(TokenPriceManager.PriceType.RAW);
				_oldPrice = SpecialMath.safeMul(_oldPrice, 10000) / (10000 - (1 * 10));
			}
			swapManager.setTokenset(false);
			require(_oldPrice == swapManager.price());
			swapManager.setPriceOverride();
			swapManager.setPrice(x);
			if (requiresOverride(x, _oldPrice))
				VM.expectRevert(getSelector("RequiresOverride()"));
			swapManager.setTokenset(true);
		}
	}
	*/

	function test_setSwdThreshold(uint80 x) public {
		swyfManager.setSwdThreshold(x);
	}

	function test_ownerTransfer(address a, bool b) public {
		VM.assume(a != address(this));
		swyfManager.ownerTransfer(a);
		VM.startPrank(a, a);
		if (b) {
			VM.warp(block.timestamp + 37 hours);
			VM.expectRevert(getSelector("TimerExpired()"));
			swyfManager.ownerConfirm();
		} else {
			swyfManager.ownerConfirm();
			swyfManager.ownerTransfer(address(this));
			VM.stopPrank();
			VM.expectRevert(getSelector("Unauthorized()"));
			swyfManager.setPriceOverride();
			swyfManager.ownerConfirm();
		}
	}

	function test_withdrawToken() public {
		VM.store(
            address(USDC),
            keccak256(abi.encode(address(this), 0)),
            bytes32(uint(100 * 1e6))
        );
		swyfManager.withdrawToken(USDC);
		require(IERC20(USDC).balanceOf(address(this)) != 0);
	}

	function test_destroyContract() public {
		VM.expectRevert(getSelector("UnlockDestruction()"));
		swyfManager.destroyContract();
		swyfManager.ownerTransfer(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
		swyfManager.destroyContract();
	}

	function test_mathOverflow(uint x) public pure {
		x = x >> 1;
		uint y = SpecialMath.safeMul(x, 2);
		require(y == x * 2);
	}

	function testFail_mathOverflow() public pure {
		uint x = (2**256 - 1);
		x = x / 2;
		SpecialMath.safeMul(x + 1, 2);
	}

	/*
	function test_getPriceTokenset() public view {
		swapManager.getPrice(TokenPriceManager.PriceType.RAW);
	}
	*/

	function test_getPrice() public view {
		(uint priceSell,) = swyfManager.getPrice(TokenPriceManager.PriceType.SELL);
		(uint priceRaw,) = swyfManager.getPrice(TokenPriceManager.PriceType.RAW);
		(uint priceBuy,) = swyfManager.getPrice(TokenPriceManager.PriceType.BUY);
		require(priceSell < priceRaw && priceRaw < priceBuy);
	}

	function test_priceTiming() public {
		(uint priceRaw01,) = swyfManager.getPrice(TokenPriceManager.PriceType.RAW);
		(uint priceSell01,) = swyfManager.getPrice(TokenPriceManager.PriceType.SELL);
		swyfManager.setPrice(1200000000000000000);
		(uint priceRaw02,) = swyfManager.getPrice(TokenPriceManager.PriceType.RAW);
		(uint priceSell02,) = swyfManager.getPrice(TokenPriceManager.PriceType.SELL);
		require(
			priceSell02 / 10**10 == priceRaw01 / 10**10 &&
			priceSell01 < priceSell02 &&
			priceRaw02 == 1200000000000000000
		);
		VM.warp(block.timestamp + 3 days);
		(uint priceSell03,) = swyfManager.getPrice(TokenPriceManager.PriceType.SELL);
		VM.warp(block.timestamp + 4 days);
		(uint priceSell04,) = swyfManager.getPrice(TokenPriceManager.PriceType.SELL);
		require(
			priceSell02 < priceSell03 &&
			priceSell03 < priceSell04 &&
			priceSell04 == (1200000000000000000 * 999) / 1000
		);
		(uint priceBuy01,) = swyfManager.getPrice(TokenPriceManager.PriceType.BUY);
		swyfManager.setPrice(1100000000000000000);
		(uint priceRaw03,) = swyfManager.getPrice(TokenPriceManager.PriceType.RAW);
		(uint priceBuy02,) = swyfManager.getPrice(TokenPriceManager.PriceType.BUY);
		require(
			priceBuy02 / 10**10 == (priceRaw02 - 10**9) / 10**10 &&
			priceBuy01 > priceBuy02 &&
			priceRaw03 == 1100000000000000000
		);
		VM.warp(block.timestamp + 3 days);
		(uint priceBuy03,) = swyfManager.getPrice(TokenPriceManager.PriceType.BUY);
		VM.warp(block.timestamp + 4 days);
		(uint priceBuy04,) = swyfManager.getPrice(TokenPriceManager.PriceType.BUY);
		require(
			priceBuy02 > priceBuy03 &&
			priceBuy03 > priceBuy04 &&
			priceBuy04 == (1100000000000000000 * 1001) / 1000
		);
	}

	function getSelector(string memory _data) private pure returns (bytes4 _selector) {
		_selector = bytes4(keccak256(bytes(_data)));
	}

	function requiresOverride(uint _price, uint _lastPrice) private pure returns (bool) {
		if (_lastPrice == 0)
			return false;
		if ((_price > SpecialMath.safeMul(_lastPrice, 11) / 10) ||
		(_price < SpecialMath.safeMul(_lastPrice, 9) / 10))
			return true;
		return false;
	}

	function run() public {
		setUp();
		test_priceTiming();
	}
}