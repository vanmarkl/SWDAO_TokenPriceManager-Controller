// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.12;

import "ds-test/test.sol";
import "../TokenPriceManager.sol";
import "../TokenPriceController.sol";
import {ITokenPriceManagerMinimal} from "../interfaces/ITokenPriceManagerMinimal.sol";

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

    function label(address addr, string calldata label) external;
    // Label an address in test traces

    function assume(bool) external;
    // When fuzzing, generate new inputs if conditional not met
}

contract ContractTest_Controller is DSTest {

	Hevm constant VM = Hevm(0x7109709ECfa91a80626fF3989D68f67F5b1DD12D);

	address constant SWAP = 0x25Ad32265c9354c29e145c902aE876f6B69806F2;
	address constant SWYF = 0xDC8d88d9E57CC7bE548F76E5e413C4838F953018;
	address constant USDC = 0x2791Bca1f2de4661ED88A30C99A7a9449Aa84174;
	address constant SWD = 0xaeE24d5296444c007a532696aaDa9dE5cE6caFD0;

	address constant TREASURY = 0x480554E3e14Dd6b9d8C29298a9C57BB5fA51F926;

	address constant THISADDR = 0xb4c79daB8f259C7Aee6E5b2Aa729821864227e84;

	TokenPriceManager swapManager;
	TokenPriceManager swapManager2;
	TokenPriceManager swyfManager;
	TokenPriceController tokenController;
	TokenPriceController tokenController2;

	function setUp() public {
		swapManager = new TokenPriceManager(SWAP, USDC);
		swyfManager = new TokenPriceManager(SWYF, USDC);
		swapManager2 = new TokenPriceManager(SWAP, USDC);
		//swapManager.initialize(0, true, 5, 100000000000000000000);
		swapManager.initialize(84140000000000000000, false, 5, 100000000000000000000);
		swapManager2.initialize(1140000000000000000, false, 10, 10000000000);
		swyfManager.initialize(1140000000000000000, false, 5, 100000000000000000000);
		tokenController = new TokenPriceController();
		tokenController2 = new TokenPriceController();
		tokenController2.managerAdd(address(swapManager));
	}
	function test_onlyOwner() public {
		bytes[7] memory calls = [
			abi.encodeWithSignature("managerAdd(address)", address(swapManager)),
			abi.encodeWithSignature("managerUpgrade(address)", address(swapManager)),
			abi.encodeWithSignature("managerRemove(address)", address(swapManager)),
			abi.encodeWithSignature("managerAdd(address)", address(swyfManager)),
			abi.encodeWithSignature("symbolRemove(string calldata)", "SWYF"),
			abi.encodeWithSignature("ownerTransfer(address)", 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF),
			abi.encodeWithSignature("destroyContract()")
		];
		VM.startPrank(TREASURY, TREASURY);
		for (uint i = 0; i < calls.length; i++) {
			(bool success, ) = address(tokenController).call(calls[i]);
			if (success)
				revert("ownerOnly() called by not-Owner.");
		}
		VM.stopPrank();
	}

	function test_managerAdd() public {
		tokenController.managerAdd(address(swapManager));
		tokenController.managerAdd(address(swyfManager));
		VM.expectRevert(getSelector("AlreadyExists()"));
		tokenController.managerAdd(address(swapManager));
	}

	function test_managerRemove() public {
		tokenController.managerAdd(address(swapManager));
		tokenController.managerRemove(address(swapManager));
		VM.expectRevert(getSelector("DoesntExist()"));
		tokenController.managerRemove(address(swapManager));
	}

	function testFail_badManager(address a) public {
		VM.assume(
			!(
				a == address(swapManager) ||
				a == address(swapManager2) ||
				a == address(swyfManager)
			)
		);
		tokenController.managerAdd(a);
	}

	function test_managerUpgrade() public {
		tokenController.managerAdd(address(swapManager));
		tokenController.managerUpgrade(address(swapManager2));
		(uint price, ) = ITokenPriceManagerMinimal(tokenController.getManager("SWAP")).getPrice(ITokenPriceManagerMinimal.PriceType.BUY);
		require(price == 1151400000000000000);
		VM.expectRevert(getSelector("DoesntExist()"));
		tokenController.managerUpgrade(address(swyfManager));
	}

	function test_symbolRemove(string calldata s) public {
		tokenController.managerAdd(address(swapManager));
		tokenController.managerAdd(address(swyfManager));
		tokenController.symbolRemove("SWAP");
		tokenController.symbolRemove("SWYF");
		VM.expectRevert(getSelector("DoesntExist()"));
		tokenController.symbolRemove("SWAP");
		VM.expectRevert(getSelector("DoesntExist()"));
		tokenController.symbolRemove(s);
	}

	function test_getManager() public {
		tokenController.managerAdd(address(swapManager));
		tokenController.managerAdd(address(swyfManager));
		require(tokenController.getManager("SWAP") == address(swapManager));
		require(tokenController.getManager("SWYF") == address(swyfManager));
	}

	function test_benchmarkGetManager() public view {
		tokenController2.getManager("SWAP");
	}

	function test_ownerTransfer(address a, bool b) public {
		VM.assume(a != THISADDR);
		swyfManager.ownerTransfer(a);
		VM.startPrank(a, a);
		if (b) {
			VM.warp(block.timestamp + 37 hours);
			VM.expectRevert(getSelector("TimerExpired()"));
			swyfManager.ownerConfirm();
		} else {
			swyfManager.ownerConfirm();
			swyfManager.ownerTransfer(THISADDR);
			VM.stopPrank();
			VM.expectRevert(getSelector("Unauthorized()"));
			swyfManager.setPriceOverride();
			swyfManager.ownerConfirm();
		}
	}

	function test_destroyContract() public {
		VM.expectRevert(getSelector("UnlockDestruction()"));
		swyfManager.destroyContract();
		swyfManager.ownerTransfer(0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF);
		swyfManager.destroyContract();
	}

	function getSelector(string memory _data) private pure returns (bytes4 _selector) {
		_selector = bytes4(keccak256(bytes(_data)));
	}
}
