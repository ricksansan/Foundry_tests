// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LotteryToken is ERC20, Ownable {
    constructor() ERC20("LotteryToken", "LTK") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract Lottery is Ownable {
    using SafeERC20 for IERC20;

    enum LotteryStatus {
        Waiting,
        Active,
        Calculating
    }
    error LotteryNotActive();
    error LotteryAlreadyActive();
    error TimeNotExpired(uint256 remaining);
    error TimeExpired();
    error NotEnoughParticipants();
    error AlreadyEntered();
    IERC20 public immutable token;
    uint256 public immutable ticketPrice;
    uint256 public constant commissionRate = 10;
    address[] public participants;
    mapping(address => bool) private hasEntered;
    LotteryStatus public status;
    uint256 public roundEndTime;
    uint256 public roundNumber;
    address public lastWinner;
    uint256 public lastPrize;

    event LotteryStarted(
        uint256 indexed round,
        uint256 ticketPrice,
        uint256 endTime
    );

    event TicketPurchased(address indexed participant, uint256 indexed round);

    event WinnerSelected(
        uint256 indexed round,
        address indexed winner,
        uint256 prize,
        uint256 commission
    );

    event LotteryEnded(uint256 indexed round);

    modifier whenActive() {
        if (status != LotteryStatus.Active) {
            revert LotteryNotActive();
        }
        _;
    }

    modifier whenTimeExpired() {
        if (block.timestamp < roundEndTime) {
            revert TimeNotExpired(roundEndTime - block.timestamp);
        }
        _;
    }

    constructor(
        address _tokenAddress,
        uint256 _ticketPrice
    ) Ownable(msg.sender) {
        require(_tokenAddress != address(0), "Invalid token address");
        require(_ticketPrice > 0, "Ticket price cannot be zero");

        token = IERC20(_tokenAddress);
        ticketPrice = _ticketPrice;
        status = LotteryStatus.Waiting;
    }

    function startLottery(uint256 _duration) public onlyOwner {
        if (status != LotteryStatus.Waiting) {
            revert LotteryAlreadyActive();
        }

        require(_duration > 0, "Duration cannot be zero");

        roundNumber++;
        roundEndTime = block.timestamp + _duration;
        status = LotteryStatus.Active;

        emit LotteryStarted(roundNumber, ticketPrice, roundEndTime);
    }

    function buyTicket() public whenActive {
        if (block.timestamp >= roundEndTime) revert TimeExpired();
        if (hasEntered[msg.sender]) revert AlreadyEntered();

        // Önce ödeme alınır; ödeme başarısızsa işlem revert olur
        token.safeTransferFrom(msg.sender, address(this), ticketPrice);

        hasEntered[msg.sender] = true;
        participants.push(msg.sender);

        emit TicketPurchased(msg.sender, roundNumber);
    }

    function drawWinner() public onlyOwner whenTimeExpired whenActive {
        if (participants.length < 2) revert NotEnoughParticipants();

        status = LotteryStatus.Calculating;

        uint256 random = uint256(
            keccak256(
                abi.encodePacked(
                    block.timestamp,
                    block.prevrandao,
                    participants.length,
                    roundNumber
                )
            )
        ) % participants.length;

        address winner = participants[random];

        uint256 pool = participants.length * ticketPrice;
        uint256 commission = (pool * commissionRate) / 100;
        uint256 prize = pool - commission;

        lastWinner = winner;
        lastPrize = prize;

        emit WinnerSelected(roundNumber, winner, prize, commission);

        _resetLottery();

        token.safeTransfer(winner, prize);
        token.safeTransfer(owner(), commission);
    }

    function _resetLottery() private {
        uint256 len = participants.length;
        for (uint256 i = 0; i < len; i++) {
            hasEntered[participants[i]] = false;
        }

        delete participants;
        status = LotteryStatus.Waiting;

        emit LotteryEnded(roundNumber);
    }

    function getParticipantCount() public view returns (uint256) {
        return participants.length;
    }

    function getPrizePool() public view returns (uint256) {
        return participants.length * ticketPrice;
    }

    function getRemainingTime() public view returns (uint256) {
        if (status != LotteryStatus.Active || block.timestamp >= roundEndTime) {
            return 0;
        }

        return roundEndTime - block.timestamp;
    }

    function hasUserEntered(address user) public view returns (bool) {
        return hasEntered[user];
    }
}
