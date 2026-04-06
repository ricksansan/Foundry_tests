// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract StakeToken is ERC20, Ownable {
    constructor() ERC20("Stake Token", "STK") Ownable(msg.sender) {
        _mint(msg.sender, 1_000_000 * 10 ** decimals());
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

contract StakingPool is Ownable {
    using SafeERC20 for IERC20;
    IERC20 public immutable stakingToken;
    uint256 public rewardRate;

    mapping(address => uint256) public stakedBalance;
    mapping(address => uint256) public stakeTimestamp;
    mapping(address => uint256) public earnedRewards;

    uint256 public totalStaked;

    event Staked(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RewardsClaimed(address indexed user, uint256 reward);
    event RewardRateUpdated(uint256 oldRate, uint256 newRate);

    error ZeroAmount();
    error InsufficientStake(uint256 current, uint256 requested);
    error NoRewardsToClaim();

    constructor(address _token, uint256 _rewardRate) Ownable(msg.sender) {
        require(_token != address(0), "zero address!");
        stakingToken = IERC20(_token);
        rewardRate = _rewardRate;
    }

    function stake(uint256 _amount) public {
        if (_amount == 0) revert ZeroAmount();
        _updateReward(msg.sender);
        stakingToken.safeTransferFrom(msg.sender, address(this), _amount);

        stakedBalance[msg.sender] += _amount;
        stakeTimestamp[msg.sender] = block.timestamp;
        totalStaked += _amount;
        emit Staked(msg.sender, _amount);
    }

    function calculateReward(address _user) public view returns (uint256) {
        uint256 time = block.timestamp - stakeTimestamp[_user];
        uint256 newPrize = (stakedBalance[_user] * time * rewardRate) / 1e18;

        uint256 sumPrize = earnedRewards[_user] + newPrize;

        return sumPrize;
    }

    function _updateReward(address _user) internal {
        if (stakedBalance[_user] != 0) {
            earnedRewards[_user] = calculateReward(_user);
        }
    }

    function updateRewardRate(uint256 _newRate) public onlyOwner {
        emit RewardRateUpdated(rewardRate, _newRate);
        rewardRate = _newRate;
    }

    function withdraw(uint256 _amount) public {
        if (_amount == 0) revert ZeroAmount();
        if (stakedBalance[msg.sender] < _amount)
            revert InsufficientStake(stakedBalance[msg.sender], _amount);

        _updateReward(msg.sender);
        stakedBalance[msg.sender] -= _amount;
        stakeTimestamp[msg.sender] = block.timestamp;
        totalStaked -= _amount;

        stakingToken.safeTransfer(msg.sender, _amount);
        emit Withdrawn(msg.sender, _amount);
    }

    function claimRewards() public {
        uint256 prize = calculateReward(msg.sender);

        if (prize == 0) revert NoRewardsToClaim();

        earnedRewards[msg.sender] = 0;
        stakeTimestamp[msg.sender] = block.timestamp;

        stakingToken.safeTransfer(msg.sender, prize);
        emit RewardsClaimed(msg.sender, prize);
    }
}
