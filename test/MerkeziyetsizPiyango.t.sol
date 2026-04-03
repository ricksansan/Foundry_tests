// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import {Lottery, LotteryToken} from "../src/MerkeziyetsizPiyango.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MerkeziyetsizPiyangoTest is Test {
    LotteryToken public ltkToken;
    Lottery public lottery;
    address public alice;
    address public bob;
    address public charlie;
    uint256 constant TICKET_PRICE = 100 * 1e18;
    uint256 constant DURATION = 1 hours;

    function setUp() public {
        ltkToken = new LotteryToken();
        lottery = new Lottery(address(ltkToken), TICKET_PRICE);
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        ltkToken.mint(alice, 1000 * 1e18);
        ltkToken.mint(bob, 1000 * 1e18);
        ltkToken.mint(charlie, 1000 * 1e18);
    }

    function _buyTicketAs(address user) internal {
        vm.startPrank(user);
        ltkToken.approve(address(lottery), TICKET_PRICE);
        lottery.buyTicket();
        vm.stopPrank();
    }

    function test_TokenDeployed() public {
        assertEq(ltkToken.name(), "LotteryToken");
        assertEq(ltkToken.symbol(), "LTK");
    }

    function test_LotteryConstructor() public {
        assertEq(lottery.ticketPrice(), TICKET_PRICE);
        assertEq(uint256(lottery.status()), 0);
        assertEq(lottery.owner(), address(this));
    }

    function test_UsersHaveTokens() public {
        assertEq(ltkToken.balanceOf(alice), 1000 * 1e18);
    }

    function test_StartLottery() public {
        lottery.startLottery(DURATION);
        assertEq(uint256(lottery.status()), 1);
        assertEq(lottery.roundNumber(), 1);
    }

    function test_StartLotteryEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Lottery.LotteryStarted(
            1,
            TICKET_PRICE,
            block.timestamp + DURATION
        );
        lottery.startLottery(DURATION);
    }

    function test_CannotStartWhileActive() public {
        lottery.startLottery(DURATION);

        vm.expectRevert(Lottery.LotteryAlreadyActive.selector);
        lottery.startLottery(DURATION);
    }

    function test_BuyTicket() public {
        lottery.startLottery(DURATION);
        _buyTicketAs(alice);
        assertEq(lottery.getParticipantCount(), 1);
        assertTrue(lottery.hasUserEntered(alice) == true);
        assertEq(ltkToken.balanceOf(alice), 900 * 1e18);
    }

    function test_CannotBuyTwice() public {
        lottery.startLottery(DURATION);
        _buyTicketAs(alice);
        vm.startPrank(alice);
        ltkToken.approve(address(lottery), 100 * 1e18);
        vm.expectRevert(Lottery.AlreadyEntered.selector);
        lottery.buyTicket();
        vm.stopPrank();
    }

    function test_CannotBuyWhenNotActive() public {
        vm.expectRevert(Lottery.LotteryNotActive.selector);
        lottery.buyTicket();
    }

    function test_CannotBuyAfterTimeExpired() public {
        lottery.startLottery(DURATION);
        vm.warp(block.timestamp + DURATION + 1);
        vm.expectRevert(Lottery.TimeExpired.selector);

        lottery.buyTicket();
    }

    function test_DrawWinner() public {
        lottery.startLottery(DURATION);
        _buyTicketAs(alice);
        _buyTicketAs(bob);
        vm.warp(block.timestamp + DURATION + 1);
        lottery.drawWinner();
        assertFalse(lottery.lastWinner() == address(0));
        assertEq(uint256(lottery.status()), 0);
        assertEq(lottery.getParticipantCount(), 0);
    }

    function test_DrawWinnerPrizeDistribution() public {
        lottery.startLottery(DURATION);
        _buyTicketAs(alice);
        _buyTicketAs(bob);
        _buyTicketAs(charlie);
        uint256 ownerBefore = ltkToken.balanceOf(address(this));
        vm.warp(block.timestamp + DURATION + 1);
        lottery.drawWinner();
        assertEq(lottery.lastPrize(), 270 * 1e18);
        assertGt(ltkToken.balanceOf(address(this)), ownerBefore);
    }

    function test_CannotDrawBeforeTimeExpires() public {
        lottery.startLottery(DURATION);

        _buyTicketAs(alice);
        _buyTicketAs(bob);
        vm.expectRevert(
            abi.encodeWithSelector(
                Lottery.TimeNotExpired.selector,
                lottery.roundEndTime() - block.timestamp
            )
        );
        lottery.drawWinner();
    }

    function test_CannotDrawWithLessThan2() public {
        lottery.startLottery(DURATION);
        _buyTicketAs(alice);
        vm.warp(block.timestamp + DURATION + 1);
        vm.expectRevert(Lottery.NotEnoughParticipants.selector);
        lottery.drawWinner();
    }

    function test_OnlyOwnerCanDraw() public {
        lottery.startLottery(DURATION);

        _buyTicketAs(alice);
        _buyTicketAs(bob);
        vm.warp(block.timestamp + DURATION + 1);

        vm.prank(alice);
        vm.expectRevert(
            abi.encodeWithSelector(
                Ownable.OwnableUnauthorizedAccount.selector,
                alice
            )
        );
        lottery.drawWinner();
    }

    function test_GetRemainingTime() public {
        lottery.startLottery(DURATION);
        assertGt(lottery.getRemainingTime(), 0);

        vm.warp(block.timestamp + DURATION);
        assertEq(lottery.getRemainingTime(), 0);
    }

    function test_GetPrizePool() public {
        lottery.startLottery(DURATION);

        _buyTicketAs(alice);
        _buyTicketAs(bob);

        assertEq(lottery.getPrizePool(), 2 * TICKET_PRICE);
    }

    function test_FullLotteryRound() public {
        lottery.startLottery(DURATION);
        _buyTicketAs(alice);
        _buyTicketAs(bob);
        _buyTicketAs(charlie);
        vm.warp(block.timestamp + DURATION + 1);
        lottery.drawWinner();

        assertFalse(lottery.lastWinner() == address(0));
        assertEq(uint256(lottery.status()), 0);
        assertEq(lottery.roundNumber(), 1);
        lottery.startLottery(DURATION);
        assertEq(lottery.roundNumber(), 2);
        assertEq(lottery.hasUserEntered(alice), false);
    }
}
