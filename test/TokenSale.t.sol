// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {TokenSale} from "../src/TokenSale.sol";

contract TokenSaleTest is Test {
    TokenSale public sale;
    address public alice;
    address public bob;
    uint256 constant TOKEN_PRICE = 0.01 ether;

    function setUp() public {
        sale = new TokenSale(TOKEN_PRICE);

        alice = makeAddr("alice");
        bob = makeAddr("bob");
        vm.deal(alice, 100 ether);
        vm.deal(bob, 50 ether);
    }

    function test_OwnerIsDeployer() public {
        assertEq(sale.owner(), address(this));
    }

    function test_TokenPriceSet() public {
        assertTrue(sale.tokenPrice() == TOKEN_PRICE);
    }
    function test_SaleStartsActive() public {
        assertTrue(sale.saleActive() == true);
    }

    function test_BuyTokens() public {
        vm.prank(alice);
        sale.buyTokens{value: 5 * TOKEN_PRICE}(5);
        assertTrue(sale.balances(alice) == 5);
        assertTrue(sale.ethSpent(alice) == 0.05 ether);
    }
    function test_BuyTokensMultipleUsers() public {
        vm.prank(alice);
        sale.buyTokens{value: 3 * TOKEN_PRICE}(3);
        vm.prank(bob);
        sale.buyTokens{value: 2 * TOKEN_PRICE}(2);

        assertTrue(sale.balances(alice) == 3);
        assertTrue(sale.balances(bob) == 2);
        assertTrue(sale.totalSold() == 5);
    }
    function test_BuyZeroRevert() public {
        vm.expectRevert(TokenSale.ZeroAmount.selector);
        sale.buyTokens(0);
    }

    function test_InsufficientPaymentRevert() public {
        vm.expectRevert(
            abi.encodeWithSelector(
                TokenSale.InsufficientPayment.selector,
                0.01 ether,
                0.05 ether
            )
        );
        vm.prank(alice);
        sale.buyTokens{value: TOKEN_PRICE}(5);
    }
    function test_BuyWhenSaleInactiveRevert() public {
        sale.toggleSale();
        vm.expectRevert(TokenSale.SaleNotActive.selector);
        sale.buyTokens(1);
    }

    function test_RefundMoreThanBalanceRevert() public {
        vm.startPrank(alice);
        sale.buyTokens{value: 2 * TOKEN_PRICE}(2);
        vm.expectRevert(
            abi.encodeWithSelector(TokenSale.InsufficientTokens.selector, 2, 10)
        );

        sale.refund(10);
        vm.stopPrank();
    }

    function test_OnlyOwnerCanWithdraw() public {
        vm.expectRevert(TokenSale.NotOwner.selector);
        vm.prank(alice);
        sale.withdrawEth();
    }

    function test_WithdrawNoEthRevert() public {
        vm.expectRevert(TokenSale.NoEthToWithdraw.selector);
        sale.withdrawEth();
    }

    function test_BuyEmitsEvent() public {
        vm.expectEmit(true, false, false, true);
        emit TokenSale.TokensPurchased(alice, 3, 0.03 ether);
        vm.prank(alice);

        sale.buyTokens{value: 3 * TOKEN_PRICE}(3);
    }
    function test_RefundEmitsEvent() public {
        vm.prank(alice);
        sale.buyTokens{value: 5 * TOKEN_PRICE}(5);

        vm.expectEmit(true, false, false, true);
        emit TokenSale.TokensRefunded(alice, 2, 0.02 ether);
        vm.prank(alice);
        sale.refund(2);
    }

    function test_ToggleEmitsEvent() public {
        vm.expectEmit(false, false, false, true);
        emit TokenSale.SaleToggled(false);
        sale.toggleSale();
    }

    function test_RefundReturnsEth() public {
        vm.startPrank(alice);
        sale.buyTokens{value: 5 * TOKEN_PRICE}(5);
        uint256 before = alice.balance;
        sale.refund(3);
        assertTrue(alice.balance == (before + 0.03 ether));
        assertTrue(sale.balances(alice) == 2);
    }

    function test_WithdrawSendsEthToOwner() public {
        vm.prank(alice);
        sale.buyTokens{value: 100 * TOKEN_PRICE}(100);
        uint256 before = address(this).balance;
        sale.withdrawEth();
        assertGt(address(this).balance, before);
        assertTrue(address(sale).balance == 0);
    }

    function test_ExcessEthReturned() public {
        uint256 beforeAlice = address(alice).balance;
        vm.prank(alice);
        sale.buyTokens{value: 100 * TOKEN_PRICE}(5);

        assertTrue(beforeAlice - alice.balance == 0.05 ether);
    }
    function testFuzz_BuyAndRefund(uint256 _amount) public {
        _amount = bound(_amount, 1, 1000);
        uint256 cost = _amount * TOKEN_PRICE;

        vm.deal(alice, cost);
        vm.prank(alice);
        sale.buyTokens{value: cost}(_amount);
        assertTrue(alice.balance == 0);
        vm.prank(alice);
        sale.refund(_amount);
        assertTrue(alice.balance == cost);
        assertTrue(sale.totalSold() == 0);
    }
    function testFuzz_CannotBuyWithoutEnoughEth(uint256 _amount) public {
        _amount = bound(_amount, 2, 100);
        uint256 cost = _amount * TOKEN_PRICE;
        uint256 notEnough = cost - 1;
        vm.deal(alice, notEnough);
        vm.startPrank(alice);
        vm.expectRevert();
        sale.buyTokens{value: notEnough}(_amount);
    }

    function test_FullScenario() public {
        vm.prank(alice);
        sale.buyTokens{value: 10 * TOKEN_PRICE}(10);
        vm.prank(bob);
        sale.buyTokens{value: 5 * TOKEN_PRICE}(5);

        assertTrue(sale.totalSold() == 15);
        vm.prank(alice);
        sale.refund(3);
        assertTrue(sale.balances(alice) == 7);
        assertTrue(sale.totalSold() == 12);
        sale.toggleSale();
        assertFalse(sale.saleActive());

        vm.startPrank(bob);
        vm.expectRevert(TokenSale.SaleNotActive.selector);

        sale.buyTokens(1);
        sale.refund(2);
        vm.stopPrank();
        sale.withdrawEth();
        assertTrue(address(sale).balance == 0);
    }
    receive() external payable {}
}
