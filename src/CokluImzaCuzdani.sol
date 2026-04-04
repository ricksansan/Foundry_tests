// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract MultiSigWallet {
    struct Transaction {
        address to;
        uint256 value;
        bytes data;
        bool executed;
        uint256 confirmations;
    }

    address[] public owners;
    mapping(address => bool) public isOwner;
    uint256 public requiredConfirmations;
    Transaction[] public transactions;
    mapping(uint256 => mapping(address => bool)) public isConfirmed;

    event Deposit(address indexed sender, uint256 amount);
    event SubmitTransaction(
        address indexed owner,
        uint256 indexed txId,
        address indexed to,
        uint256 value
    );
    event ConfirmTransaction(address indexed owner, uint256 indexed txId);
    event RevokeConfirmation(address indexed owner, uint256 indexed txId);
    event ExecuteTransaction(address indexed owner, uint256 indexed txId);

    error NotOwner();
    error InvalidOwnerCount();
    error InvalidConfirmationCount();
    error OwnerAlreadyExists(address owner);
    error ZeroAddress();
    error TxDoesNotExist();
    error TxAlreadyExecuted();
    error AlreadyConfirmed();
    error NotConfirmed();
    error InsufficientConfirmations(uint256 current, uint256 required);
    error ExecutionFailed();

    modifier onlyOwner() {
        if (!isOwner[msg.sender]) revert NotOwner();
        _;
    }

    modifier txExists(uint256 _txId) {
        if (_txId >= transactions.length) revert TxDoesNotExist();
        _;
    }

    modifier notExecuted(uint256 _txId) {
        if (transactions[_txId].executed) revert TxAlreadyExecuted();
        _;
    }

    constructor(address[] memory _owners, uint256 _requiredConfirmations) {
        if (_owners.length < 1) revert InvalidOwnerCount();
        if (
            _requiredConfirmations <= 0 ||
            _requiredConfirmations > _owners.length
        ) revert InvalidConfirmationCount();

        for (uint256 i = 0; i < _owners.length; i++) {
            if (_owners[i] == address(0)) revert ZeroAddress();
            if (isOwner[_owners[i]]) revert OwnerAlreadyExists(_owners[i]);
            owners.push(_owners[i]);
            isOwner[_owners[i]] = true;
        }
        requiredConfirmations = _requiredConfirmations;
    }

    receive() external payable {
        emit Deposit(msg.sender, msg.value);
    }

    function submitTransaction(
        address _to,
        uint256 _value,
        bytes memory _data
    ) public onlyOwner {
        Transaction memory trans = Transaction({
            to: _to,
            value: _value,
            data: _data,
            executed: false,
            confirmations: 0
        });

        transactions.push(trans);

        emit SubmitTransaction(
            msg.sender,
            transactions.length - 1,
            _to,
            _value
        );
    }

    function confirmTransaction(
        uint256 _txId
    ) public onlyOwner txExists(_txId) notExecuted(_txId) {
        if (isConfirmed[_txId][msg.sender]) revert AlreadyConfirmed();
        isConfirmed[_txId][msg.sender] = true;
        transactions[_txId].confirmations++;
        emit ConfirmTransaction(msg.sender, _txId);
    }

    function revokeConfirmation(
        uint256 _txId
    ) public onlyOwner txExists(_txId) notExecuted(_txId) {
        if (!isConfirmed[_txId][msg.sender]) revert NotConfirmed();
        isConfirmed[_txId][msg.sender] = false;
        transactions[_txId].confirmations--;
        emit RevokeConfirmation(msg.sender, _txId);
    }

    function executeTransaction(
        uint256 _txId
    ) public onlyOwner txExists(_txId) notExecuted(_txId) {
        Transaction storage transaction = transactions[_txId];
        if (transaction.confirmations < requiredConfirmations)
            revert InsufficientConfirmations(
                transaction.confirmations,
                requiredConfirmations
            );

        transaction.executed = true;

        (bool ok, ) = transaction.to.call{value: transaction.value}(
            transaction.data
        );
        if (!ok) revert ExecutionFailed();

        emit ExecuteTransaction(msg.sender, _txId);
    }

    function getOwnerCount() public view returns (uint256) {
        return owners.length;
    }

    function getTransactionCount() public view returns (uint256) {
        return transactions.length;
    }

    function getOwners() public view returns (address[] memory) {
        return owners;
    }

    function getTransaction(
        uint256 _txId
    ) public view returns (Transaction memory) {
        return transactions[_txId];
    }
}
