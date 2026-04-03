// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract TokenSale {
    address public immutable owner;
    uint256 public tokenPrice;
    uint256 public totalSold;
    bool public saleActive;

    mapping(address => uint256) public balances;
    mapping(address => uint256) public ethSpent;

    event TokensPurchased(address indexed buyer, uint256 amount, uint256 cost);
    event TokensRefunded(address indexed buyer, uint256 amount, uint256 refund);
    event SaleToggled(bool active);
    event EthWithdrawn(address indexed owner, uint256 amount);

    error NotOwner();
    error SaleNotActive();
    error InsufficientPayment(uint256 sent, uint256 required);
    error ZeroAmount();
    error InsufficientTokens(uint256 held, uint256 requested);
    error TransferFailed();
    error NoEthToWithdraw();

    modifier onlyOwner() {
        if (msg.sender != owner) revert NotOwner();
        _;
    }

    constructor(uint256 _tokenPrice) {
        owner = msg.sender;
        tokenPrice = _tokenPrice;
        saleActive = true;
    }

    function buyTokens(uint256 _amount) public payable {
        if (!saleActive) revert SaleNotActive();
        if (_amount == 0) revert ZeroAmount();
        uint256 cost = _amount * tokenPrice;
        if (msg.value < cost) revert InsufficientPayment(msg.value, cost);

        balances[msg.sender] += _amount;
        ethSpent[msg.sender] += cost;
        totalSold += _amount;

        uint256 excess = msg.value - cost;
        if (excess > 0) {
            (bool ok, ) = msg.sender.call{value: excess}("");
            if (!ok) revert TransferFailed();
        }
        emit TokensPurchased(msg.sender, _amount, cost);
    }

    function refund(uint256 _amount) public {
        if (_amount == 0) revert ZeroAmount();
        if (balances[msg.sender] < _amount)
            revert InsufficientTokens(balances[msg.sender], _amount);

        uint256 refundAmount = _amount * tokenPrice;
        balances[msg.sender] -= _amount;
        ethSpent[msg.sender] -= refundAmount;
        totalSold -= _amount;

        (bool ok, ) = msg.sender.call{value: refundAmount}("");
        if (!ok) revert TransferFailed();
        emit TokensRefunded(msg.sender, _amount, refundAmount);
    }

    function withdrawEth() public onlyOwner {
        uint256 amount = address(this).balance;
        if (amount == 0) revert NoEthToWithdraw();
        (bool ok, ) = owner.call{value: amount}("");
        if (!ok) revert TransferFailed();
        emit EthWithdrawn(owner, amount);
    }

    function toggleSale() public onlyOwner {
        saleActive = !saleActive;
        emit SaleToggled(saleActive);
    }
}
