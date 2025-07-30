// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Pausable} from "@openzeppelin/contracts/utils/Pausable.sol";

/// @title Multi-signature Wallet
/// @author
/// @notice This contract allows multiple owners to collectively manage and execute transactions
/// @dev Implements a multi-signature mechanism with deposit, owner management, and transaction lifecycle
contract MultiSig is ReentrancyGuard, Pausable {
    /// @notice Emitted when a transaction is created
    /// @param txIndex The index of the transaction
    /// @param creator The owner who created the transaction
    /// @param to The destination address of the transaction
    /// @param value The amount of Wei to send
    /// @param data The calldata payload
    event TransactionCreated(uint256 indexed txIndex, address indexed creator, address to, uint256 value, bytes data);

    /// @notice Emitted when a transaction is confirmed by an owner
    /// @param txIndex The index of the transaction
    /// @param confirmer The owner who confirmed the transaction
    event TransactionConfirmed(uint256 indexed txIndex, address indexed confirmer);

    /// @notice Emitted when a transaction is executed
    /// @param txIndex The index of the transaction
    /// @param executor The owner who executed the transaction
    event TransactionExecuted(uint256 indexed txIndex, address indexed executor);

    /// @notice Emitted when a confirmation is revoked
    /// @param txIndex The index of the transaction
    /// @param revoker The owner who revoked their confirmation
    event TransactionRevoked(uint256 indexed txIndex, address indexed revoker);

    /// @notice Emitted when a new owner is added
    /// @param newOwner The address of the owner added
    event OwnerAdded(address indexed newOwner);

    /// @notice Emitted when an owner is removed
    /// @param removedOwner The address of the owner removed
    event OwnerRemoved(address indexed removedOwner);

    /// @notice Emitted when the required number of confirmations is changed
    /// @param newRequiredConfirmations The new threshold for confirmations
    event RequiredConfirmationsChanged(uint256 newRequiredConfirmations);

    /// @notice Emitted when Ether is deposited
    /// @param sender The address sending Ether
    /// @param amount The amount of Wei deposited
    /// @param balance The new contract balance
    event Deposit(address indexed sender, uint256 amount, uint256 balance);

    /// @notice Structure to store transaction details
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    /// @notice List of owner addresses
    address[] public owners;
    /// @notice Mapping to check owner status
    mapping(address => bool) public isOwner;
    /// @notice List of all transactions
    Transaction[] public transactions;
    /// @notice Mapping of confirmations: txIndex => owner => confirmed
    mapping(uint256 => mapping(address => bool)) public confirmations;
    /// @notice Number of required confirmations
    uint256 public requiredConfirmations;

    /// @notice Ensures the caller is one of the owners
    modifier onlyOwner() {
        require(isOwner[msg.sender], "NOT_OWNER");
        _;
    }

    /// @notice Checks that the transaction exists
    /// @param _txIndex The index of the transaction
    modifier transactionExists(uint256 _txIndex) {
        require(_txIndex < transactions.length, "TRANSACTION_NOT_EXIST");
        _;
    }

    /// @notice Checks the caller has not confirmed the transaction
    /// @param _txIndex The index of the transaction
    modifier notConfirmed(uint256 _txIndex) {
        require(!confirmations[_txIndex][msg.sender], "ALREADY_CONFIRMED");
        _;
    }

    /// @notice Checks the caller has confirmed the transaction
    /// @param _txIndex The index of the transaction
    modifier confirmed(uint256 _txIndex) {
        require(confirmations[_txIndex][msg.sender], "NOT_CONFIRMED");
        _;
    }

    /// @notice Checks the transaction has not been executed yet
    /// @param _txIndex The index of the transaction
    modifier notExecuted(uint256 _txIndex) {
        require(!transactions[_txIndex].executed, "TRANSACTION_ALREADY_EXECUTED");
        _;
    }

    /// @notice Checks the transaction has enough confirmations
    /// @param _txIndex The index of the transaction
    modifier enoughConfirmations(uint256 _txIndex) {
        require(transactions[_txIndex].confirmations >= requiredConfirmations, "NOT_ENOUGH_CONFIRMATIONS");
        _;
    }

    /// @notice Constructor sets initial owners and confirmation threshold
    /// @param _owners List of initial owner addresses
    /// @param _requiredConfirmations Number of confirmations required to execute
    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        require(_owners.length > 0, "Owners required");
        require(
            _requiredConfirmations > 0 && _requiredConfirmations <= _owners.length,
            "Invalid number of required confirmations"
        );

        for (uint256 i = 0; i < _owners.length; i++) {
            address owner = _owners[i];
            require(owner != address(0), "ZERO_ADDRESS");
            require(!isOwner[owner], "DUPLICATE_OWNER");
            isOwner[owner] = true;
            owners.push(owner);
        }
        requiredConfirmations = _requiredConfirmations;
    }

    /// @notice Adds a new owner
    /// @dev New owner must be non-zero and not already an owner
    /// @param _newOwner The address to add as owner
    function addOwner(address _newOwner) external onlyOwner {
        require(_newOwner != address(0), "ZERO_ADDRESS");
        require(!isOwner[_newOwner], "DUPLICATE_OWNER");

        isOwner[_newOwner] = true;
        owners.push(_newOwner);
        emit OwnerAdded(_newOwner);
    }

    /// @notice Removes an existing owner and revokes their confirmations
    /// @dev Cannot remove last owner; cleans up pending confirmations
    /// @param _owner The address of the owner to remove
    function removeOwner(address _owner) external onlyOwner {
        require(isOwner[_owner], "NOT_OWNER");
        require(owners.length > 1, "Cannot remove last owner");

        // Remove owner flag and from array
        isOwner[_owner] = false;
        for (uint256 i = 0; i < owners.length; i++) {
            if (owners[i] == _owner) {
                owners[i] = owners[owners.length - 1];
                owners.pop();
                break;
            }
        }
        // Clean up pending confirmations
        for (uint256 i = 0; i < transactions.length; i++) {
            if (!transactions[i].executed && confirmations[i][_owner]) {
                confirmations[i][_owner] = false;
                transactions[i].confirmations--;
            }
        }
        emit OwnerRemoved(_owner);
    }

    /// @notice Changes the required confirmation threshold
    /// @dev New threshold must be >0 and <= number of owners
    /// @param _newRequiredConfirmations The new confirmation count
    function changeRequiredConfirmations(uint256 _newRequiredConfirmations) external onlyOwner {
        require(
            _newRequiredConfirmations > 0 && _newRequiredConfirmations <= owners.length,
            "Invalid number of required confirmations"
        );
        requiredConfirmations = _newRequiredConfirmations;
        emit RequiredConfirmationsChanged(_newRequiredConfirmations);
    }

    /// @notice Creates a new transaction proposal
    /// @dev The creator does not auto-confirm; must call confirmTransaction
    /// @param _to Destination address for the transaction
    /// @param _value Amount of Wei to send
    /// @param _data Calldata payload
    function createTransaction(address _to, uint256 _value, bytes calldata _data) external onlyOwner whenNotPaused {
        require(_to != address(0), "ZERO_ADDRESS");

        transactions.push(Transaction({to: _to, value: _value, data: _data, executed: false, confirmations: 0}));
        uint256 txIndex = transactions.length - 1;
        emit TransactionCreated(txIndex, msg.sender, _to, _value, _data);
    }

    /// @notice Confirms a pending transaction
    /// @param _txIndex The index of the transaction to confirm
    function confirmTransaction(uint256 _txIndex)
        external
        onlyOwner
        whenNotPaused
        transactionExists(_txIndex)
        notConfirmed(_txIndex)
    {
        confirmations[_txIndex][msg.sender] = true;
        transactions[_txIndex].confirmations++;
        emit TransactionConfirmed(_txIndex, msg.sender);
    }

    /// @notice Executes a transaction that has enough confirmations
    /// @param _txIndex The index of the transaction to execute
    function executeTransaction(uint256 _txIndex)
        external
        payable
        onlyOwner
        transactionExists(_txIndex)
        enoughConfirmations(_txIndex)
        notExecuted(_txIndex)
        nonReentrant
        whenNotPaused
    {
        Transaction storage txToExecute = transactions[_txIndex];

        (bool success,) = txToExecute.to.call{value: txToExecute.value}(txToExecute.data);
        require(success, "EXECUTION_FAILED");
        txToExecute.executed = true;

        emit TransactionExecuted(_txIndex, msg.sender);
    }

    /// @notice Revokes a confirmation for a transaction
    /// @param _txIndex The index of the transaction to revoke
    function revokeConfirmation(uint256 _txIndex)
        external
        onlyOwner
        transactionExists(_txIndex)
        confirmed(_txIndex)
        whenNotPaused
    {
        confirmations[_txIndex][msg.sender] = false;
        transactions[_txIndex].confirmations--;
        emit TransactionRevoked(_txIndex, msg.sender);
    }

    /// @notice Returns the total number of transactions
    /// @return The count of transactions
    function getTransactionCount() external view returns (uint256) {
        return transactions.length;
    }

    /// @notice Retrieves details of a transaction
    /// @param _txIndex The index of the transaction
    /// @return to The destination address
    /// @return value The amount of Wei
    /// @return data The calldata
    /// @return executed Boolean execution status
    /// @return _confirmations Number of confirmations received
    function getTransaction(uint256 _txIndex)
        external
        view
        transactionExists(_txIndex)
        returns (address to, uint256 value, bytes memory data, bool executed, uint256 _confirmations)
    {
        Transaction memory transaction = transactions[_txIndex];
        return (transaction.to, transaction.value, transaction.data, transaction.executed, transaction.confirmations);
    }

    /// @notice Returns list of owner addresses
    /// @return Array of owner addresses
    function getOwners() external view returns (address[] memory) {
        return owners;
    }

    /// @notice Returns pending transaction indices
    /// @return Array of pending transaction indices
    function getPendingTransactions() external view returns (uint256[] memory) {
        uint256 count;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (!transactions[i].executed) count++;
        }
        uint256[] memory txs = new uint256[](count);
        uint256 j;
        for (uint256 i = 0; i < transactions.length; i++) {
            if (!transactions[i].executed) {
                txs[j++] = i;
            }
        }
        return txs;
    }

    /// @notice Fallback function to accept Ether
    fallback() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }

    /// @notice Receive function to accept Ether
    receive() external payable {
        emit Deposit(msg.sender, msg.value, address(this).balance);
    }
}
