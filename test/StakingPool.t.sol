// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {StakeToken, StakingPool} from "../src/StakingPool.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract StakingPoolTest is Test {
    StakeToken public st;
    StakingPool public sp;

    address public alice;
    address public bob;

    uint256 public constant REWARD_RATE = 1e18;

    function setUp() public {
        st = new StakeToken();
        sp = new StakingPool(address(st), 1e18);

        alice = makeAddr("alice");
        bob = makeAddr("bob");

        st.mint(alice, 1000 * 1e18);
        st.mint(bob, 1000 * 1e18);
        st.mint(address(sp), 1000000000e18);
    }

    function _stakeAs(address user, uint256 amount) internal {
        vm.startPrank(user);
        st.approve(address(sp), amount);
        sp.stake(amount);
        vm.stopPrank();
    }

    function test_Constructor() public view {
        assertEq(sp.rewardRate(), REWARD_RATE);
        assertEq(address(sp.stakingToken()), address(st));
    }

    function test_ConstructorOwner() public view {
        assertEq(sp.owner(), address(this));
    }

    function test_UserStake() public {
        uint256 beforeTotalStaked = sp.totalStaked();
        uint256 beforeAliceStake = sp.stakedBalance(alice);
        _stakeAs(alice, 100e18);
        assertGt(sp.stakedBalance(alice), beforeAliceStake);
        assertGt(sp.totalStaked(), beforeTotalStaked);
    }

    function test_ZeroStake() public {
        vm.startPrank(alice);
        st.approve(address(sp), 0);
        vm.expectRevert(StakingPool.ZeroAmount.selector);
        sp.stake(0);
        vm.stopPrank();
    }

    function test_DoubleStakeAccumulatesAndPreservesReward() public {
        uint256 amount = 100e18;
        _stakeAs(alice, amount);

        vm.warp(block.timestamp + 1 days);
        uint256 rewardBeforeSecondStake = sp.calculateReward(alice);
        assertGt(rewardBeforeSecondStake, 0);

        _stakeAs(alice, amount);

        assertEq(sp.stakedBalance(alice), amount * 2);
        assertEq(sp.totalStaked(), amount * 2);
        assertGt(sp.earnedRewards(alice), 0);
    }

    function test_PartialWithdraw() public {
        _stakeAs(alice, 100e18);
        uint256 beforeAliceStake = sp.stakedBalance(alice);
        uint256 beforeTotalStaked = sp.totalStaked();
        uint256 beforeTokenBalance = st.balanceOf(alice);

        vm.prank(alice);
        sp.withdraw(50e18);

        assertGt(beforeAliceStake, sp.stakedBalance(alice));
        assertGt(beforeTotalStaked, sp.totalStaked());
        assertEq(st.balanceOf(alice), beforeTokenBalance + 50e18);
    }

    function test_WithdrawExceedsBalance() public {
        _stakeAs(alice, 100e18);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                StakingPool.InsufficientStake.selector,
                100e18,
                500e18
            )
        );
        sp.withdraw(500e18);
    }

    function test_ZeroWithdraw() public {
        _stakeAs(alice, 100e18);
        vm.prank(alice);

        vm.expectRevert(StakingPool.ZeroAmount.selector);
        sp.withdraw(0);
    }

    function test_RewardAccruesOverTime() public {
        _stakeAs(alice, 100e18);
        uint256 beforeAlicePrize = sp.calculateReward(alice);

        vm.warp(block.timestamp + 1 days);

        assertGt(sp.calculateReward(alice), beforeAlicePrize);
    }

    function test_ClaimRewardsTransfersAndResets() public {
        _stakeAs(alice, 100e18);
        uint256 beforeClaimBalanceAlice = st.balanceOf(alice);
        vm.warp(block.timestamp + 1 days);
        vm.prank(alice);
        sp.claimRewards();

        assertEq(sp.earnedRewards(alice), 0);
        assertGt(st.balanceOf(alice), beforeClaimBalanceAlice);
    }

    function test_ClaimWithNoRewardsReverts() public {
        vm.prank(alice);
        vm.expectRevert(StakingPool.NoRewardsToClaim.selector);
        sp.claimRewards();
    }

    function test_UpdateRewardRate() public {
        uint256 beforeRate = sp.rewardRate();
        sp.updateRewardRate(2e18);

        assertFalse(beforeRate == sp.rewardRate());
        assertEq(sp.rewardRate(), 2e18);
    }

    function test_NonOwnerCannotUpdateRate() public {
        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        sp.updateRewardRate(2e18);
    }

    function test_FullScenarioStakeClaimWithdraw() public {
        _stakeAs(alice, 100e18);

        vm.warp(block.timestamp + 1 days);

        vm.startPrank(alice);
        sp.claimRewards();
        sp.withdraw(sp.stakedBalance(alice));
        vm.stopPrank();

        assertEq(sp.stakedBalance(alice), 0);
        assertEq(sp.totalStaked(), 0);
        assertEq(sp.calculateReward(alice), 0);
    }

    function test_DifferentDurationsYieldDifferentRewards() public {
        _stakeAs(alice, 100e18);
        _stakeAs(bob, 100e18);

        vm.warp(block.timestamp + 1 days);

        uint256 aliceRewardDay1 = sp.calculateReward(alice);
        uint256 bobRewardDay1 = sp.calculateReward(bob);

        assertEq(aliceRewardDay1, bobRewardDay1);

        vm.prank(bob);
        sp.claimRewards();

        vm.warp(block.timestamp + 1 days);

        uint256 aliceRewardDay2 = sp.calculateReward(alice);
        uint256 bobRewardDay2 = sp.calculateReward(bob);

        assertGt(aliceRewardDay2, bobRewardDay2);
    }
}
