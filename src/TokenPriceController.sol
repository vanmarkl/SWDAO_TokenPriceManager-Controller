// SPDX-License-Identifier: Apache License 2.0
pragma solidity ^0.8.12;

import {IERC20Metadata} from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import {ITokenPriceManagerMinimal} from "./ITokenPriceManagerMinimal.sol";

/// @title Address database for TokenPriceManagers
/// @author Peter T. Flynn
/// @notice Allows for access to TokenPriceManagers by their primary token's symbol, with
/// easy upgradeability in mind.
contract TokenPriceController {
    /// @notice Current owner
    address public owner;
    /// @notice New owner for ownership transfer
    /// @dev May contain the max address for unlocking contract destruction
    address public ownerNew;
    /// @notice Timestamp for ownership transfer timeout
    uint256 public ownerTransferTimeout;
    /// @notice Stores contract addresses, accessible by the primary token's symbol
    mapping(string => address) private symbolToAddress;

	/// @notice Emitted when a new manager is added to the controller
	/// @param sender The transactor
	/// @param manager The address of the manager
	/// @param symbol The manager's primary token's symbol
	event ManagerAdd(address indexed sender, address indexed manager, string indexed symbol);
	/// @notice Emitted when a manager is upgraded within the controller
	/// @param sender The transactor
	/// @param manager The address of the manager
	/// @param symbol The manager's primary token's symbol
	event ManagerUpgrade(address indexed sender, address indexed manager, string indexed symbol);
	/// @notice Emitted when a manager is removed from the controller
	/// @param sender The transactor
	/// @param manager The address of the manager
	/// @param symbol The manager's primary token's symbol
	event ManagerRemove(address indexed sender, address indexed manager, string indexed symbol);
    /// @notice Emitted when an ownership transfer has been initiated
    /// @param sender The transactor
    /// @param newOwner The address designated as the potential new owner
    event OwnerTransfer(address indexed sender, address newOwner);
    /// @notice Emitted when an ownership transfer is confirmed
    /// @param sender The transactor, and new owner
    /// @param oldOwner The old owner
    event OwnerConfirm(address indexed sender, address oldOwner);
    /// @notice Emitted when the contract is destroyed
    /// @param sender The transactor
    event SelfDestruct(address sender);

    /// @notice Returned when the sender is not authorized to call a specific function
    error Unauthorized();
    /// @notice Returned when the block's timestamp is passed the expiration timestamp for
    /// the requested action
    error TimerExpired();
    /// @notice Returned when the requested contract destruction requires an unlock
    error UnlockDestruction();
	/// @notice Returns when an address provided does not correspond to a
	/// functioning TokenPriceManager
    error BadManager();
	/// @notice Returns when a TokenPriceManager with the same primary token symbol already exists
	/// within the controller
    error AlreadyExists();
	/// @notice Returns when the requested TokenPriceManager does not exist within the controller,
	/// or if the primary token's symbol has changed.
    error DoesntExist();

	// Prevents unauthorized calls
    modifier onlyOwner() {
        if (msg.sender != owner) revert Unauthorized();
        _;
    }

	// Sets the contract creator to the initial owner
    constructor() {
        owner = msg.sender;
    }

	/// @notice Adds a manager to the controller
    function managerAdd(address manager) external onlyOwner {
        (string memory symbol, bool notExists) = getSymbol(manager);
        if (!notExists) revert AlreadyExists();
        symbolToAddress[symbol] = manager;
		emit ManagerAdd(msg.sender, manager, symbol);
    }

	/// @notice Upgrades a manager within the controller
    function managerUpgrade(address manager) external onlyOwner {
        (string memory symbol, bool notExists) = getSymbol(manager);
        if (notExists) revert DoesntExist();
        symbolToAddress[symbol] = manager;
		emit ManagerUpgrade(msg.sender, manager, symbol);
    }

	/// @notice Removes a manager from the controller
    function managerRemove(address manager) external onlyOwner {
        (string memory symbol, bool notExists) = getSymbol(manager);
        if (notExists) revert DoesntExist();
        delete symbolToAddress[symbol];
		emit ManagerRemove(msg.sender, manager, symbol);
    }

	/// @notice Removes a manager from the controller, given the primary token's symbol
	/// @param symbol The primary token's symbol, formatted identically to its contract variable
    function symbolRemove(string calldata symbol) external onlyOwner {
        if (symbolToAddress[symbol] == address(0)) revert DoesntExist();
		emit ManagerRemove(msg.sender, symbolToAddress[symbol], symbol);
        delete symbolToAddress[symbol];
    }

    /// @notice Initiates an ownership transfer, but the new owner must call ownerConfirm()
    /// within 36 hours to finalize (Can only be called by the owner)
    /// @param _ownerNew The new owner's address
    function ownerTransfer(address _ownerNew) external onlyOwner {
        ownerNew = _ownerNew;
        ownerTransferTimeout = block.timestamp + 36 hours;
        emit OwnerTransfer(msg.sender, _ownerNew);
    }

    /// @notice Finalizes an ownership transfer (Can only be called by the new owner)
    function ownerConfirm() external {
        if (msg.sender != ownerNew) revert Unauthorized();
        if (block.timestamp > ownerTransferTimeout) revert TimerExpired();
        address _ownerOld = owner;
        owner = ownerNew;
        ownerNew = address(0);
        ownerTransferTimeout = 0;
        emit OwnerConfirm(msg.sender, _ownerOld);
    }

    /// @notice Destroys the contract when it's no longer needed (Can only be called by the owner)
    /// @dev Only allows selfdestruct() after the variable [ownerNew] has been set to its
    /// max value, in order to help mitigate human error
    function destroyContract() external onlyOwner {
        address payable _owner = payable(owner);
        if (ownerNew != 0xFFfFfFffFFfffFFfFFfFFFFFffFFFffffFfFFFfF)
            revert UnlockDestruction();
        emit SelfDestruct(_owner);
        selfdestruct(_owner);
    }

    /// @notice Gets the address of a TokenPriceManager, given the primary token's symbol
	/// @param symbol The primary token's symbol, formatted identically to its contract variable
    function getManager(string calldata symbol)
        external
        view
        returns (address)
    {
        return symbolToAddress[symbol];
    }

	/// @dev "notExists" rather than "exists" to save gas
    function getSymbol(address manager)
        private
        view
        returns (string memory symbol, bool notExists)
    {
        symbol = IERC20Metadata(
            ITokenPriceManagerMinimal(manager).getTokenPrimary()
        ).symbol();
        if (bytes(symbol).length == 0) revert BadManager();
        notExists = symbolToAddress[symbol] == address(0);
    }
}
