// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test, console} from "forge-std/Test.sol";
import {MultiSigWallet} from "../src/CokluImzaCuzdani.sol";

contract MultiSigWalletTest is Test {
    MultiSigWallet public multiSigTest;
    address public alice;
    address public bob;
    address public charlie;
    address[] owners;

    uint256 constant REQUIRED_CONFIRMATIONS = 2;

    function setUp() public {
        alice = makeAddr("alice");
        bob = makeAddr("bob");
        charlie = makeAddr("charlie");
        owners.push(alice);
        owners.push(bob);
        owners.push(charlie);
        multiSigTest = new MultiSigWallet(owners, REQUIRED_CONFIRMATIONS);
        vm.deal(address(multiSigTest), 1 ether);
    }

    function test_Constructor() public {
        assertEq(multiSigTest.getOwnerCount(), 3);
        assertEq(multiSigTest.requiredConfirmations(), REQUIRED_CONFIRMATIONS);
        assertTrue(multiSigTest.isOwner(alice));
        assertTrue(multiSigTest.isOwner(bob));
        assertTrue(multiSigTest.isOwner(charlie));
    }
    function test_RevertZeroOwners() public {
        address[] memory empty = new address[](0);
        vm.expectRevert();
        new MultiSigWallet(empty, 1);
    }
    function test_RevertZeroConfirmations() public {
        address[] memory empty2 = new address[](3);

        empty2[0] = alice;
        empty2[1] = charlie;
        empty2[2] = bob;

        vm.expectRevert();

        new MultiSigWallet(empty2, 0);
    }
    function test_RevertZeroAddress() public {
        address[] memory empty3 = new address[](3);
        empty3[0] = address(0);
        empty3[1] = alice;
        empty3[2] = bob;
        vm.expectRevert();
        new MultiSigWallet(empty3, 2);
    }
    function test_RevertDuplicateOwner() public {
        address[] memory empty4 = new address[](3);

        empty4[0] = alice;
        empty4[1] = alice;
        empty4[2] = bob;

        vm.expectRevert();
        new MultiSigWallet(empty4, 2);
    }

    function test_SubmitTransaction() public {
        vm.deal(address(multiSigTest), 10 ether);
        uint256 txCount = multiSigTest.getTransactionCount();
        vm.prank(alice);
        multiSigTest.submitTransaction(bob, 1 ether, "");
        assertGt(multiSigTest.getTransactionCount(), txCount);
    }
    function test_NotOwnerSubmitTransaction() public {
        address a = makeAddr("a");

        vm.prank(a);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        multiSigTest.submitTransaction(bob, 1 ether, "");
    }
    function test_OwnerConfirmation() public {
        vm.prank(alice);
        multiSigTest.submitTransaction(bob, 1 ether, "");

        uint256 txId = multiSigTest.getTransactionCount() - 1;

        (, , , , uint256 beforeConfirmations) = multiSigTest.transactions(txId);

        vm.prank(bob);
        multiSigTest.confirmTransaction(txId);

        (, , , , uint256 afterConfirmations) = multiSigTest.transactions(txId);

        assertGt(afterConfirmations, beforeConfirmations);
    }
    function test_RevertDuplicateConfirmation() public {
        vm.prank(alice);
        multiSigTest.submitTransaction(bob, 1 ether, "");
        uint256 txId = multiSigTest.getTransactionCount() - 1;
        vm.startPrank(bob);
        multiSigTest.confirmTransaction(txId);

        vm.expectRevert(MultiSigWallet.AlreadyConfirmed.selector);
        multiSigTest.confirmTransaction(txId);
    }
    function test_RevertNotOwnerConfirmation() public {
        vm.prank(alice);
        multiSigTest.submitTransaction(bob, 1 ether, "");
        address deus = makeAddr("deus");
        uint256 txId = multiSigTest.getTransactionCount() - 1;
        vm.prank(deus);
        vm.expectRevert(MultiSigWallet.NotOwner.selector);
        multiSigTest.confirmTransaction(txId);
    }
    function test_RevokeConfirmation() public {
        vm.prank(alice);
        multiSigTest.submitTransaction(bob, 1 ether, "");

        uint256 txId = multiSigTest.getTransactionCount() - 1;
        vm.prank(bob);
        multiSigTest.confirmTransaction(txId);
        (, , , , uint256 beforeConfirmations) = multiSigTest.transactions(txId);

        vm.prank(bob);
        multiSigTest.revokeConfirmation(txId);
        (, , , , uint256 afterConfirmations) = multiSigTest.transactions(txId);
        assertGt(beforeConfirmations, afterConfirmations);
    }
    function test_RevertRevokeWithoutConfirmation() public {
        vm.prank(alice);
        multiSigTest.submitTransaction(bob, 1 ether, "");
        uint256 txId = multiSigTest.getTransactionCount() - 1;

        vm.prank(bob);
        vm.expectRevert(MultiSigWallet.NotConfirmed.selector);
        multiSigTest.revokeConfirmation(txId);
    }

    function test_ExecuteWithSufficientConfirmations() public {
        vm.prank(alice);

        multiSigTest.submitTransaction(bob, 1 ether, "");
        uint256 txId = multiSigTest.getTransactionCount() - 1;
        vm.prank(bob);
        multiSigTest.confirmTransaction(txId);
        vm.startPrank(charlie);
        multiSigTest.confirmTransaction(txId);

        multiSigTest.executeTransaction(txId);
    }
    function test_RevertInsufficientConfirmations() public {
        vm.prank(alice);

        multiSigTest.submitTransaction(bob, 1 ether, "");
        uint256 txId = multiSigTest.getTransactionCount() - 1;

        vm.startPrank(charlie);
        multiSigTest.confirmTransaction(txId);
        vm.expectRevert(
            abi.encodeWithSelector(
                MultiSigWallet.InsufficientConfirmations.selector,
                1,
                2
            )
        );
        multiSigTest.executeTransaction(txId);
    }

    function test_ReExecuteTransaction() public {
        vm.prank(alice);

        multiSigTest.submitTransaction(bob, 1 ether, "");
        uint256 txId = multiSigTest.getTransactionCount() - 1;
        vm.prank(bob);
        multiSigTest.confirmTransaction(txId);
        vm.startPrank(charlie);
        multiSigTest.confirmTransaction(txId);

        multiSigTest.executeTransaction(txId);
        vm.expectRevert(MultiSigWallet.TxAlreadyExecuted.selector);
        multiSigTest.executeTransaction(txId);
    }

    function test_FullScenario() public {
        vm.prank(alice);

        multiSigTest.submitTransaction(bob, 1 ether, "");
        uint256 txId = multiSigTest.getTransactionCount() - 1;
        vm.prank(bob);
        multiSigTest.confirmTransaction(txId);
        vm.startPrank(charlie);
        multiSigTest.confirmTransaction(txId);

        uint256 beforeBob = bob.balance;

        multiSigTest.executeTransaction(txId);
        uint256 afterBob = bob.balance;
        assertGt(afterBob, beforeBob);
    }
    function test_FullScenarioRevokeAndFail() public {
        vm.prank(alice);

        multiSigTest.submitTransaction(bob, 1 ether, "");
        uint256 txId = multiSigTest.getTransactionCount() - 1;
        vm.prank(bob);
        multiSigTest.confirmTransaction(txId);

        vm.startPrank(bob);
        multiSigTest.revokeConfirmation(txId);

        vm.expectRevert(
            abi.encodeWithSelector(
                MultiSigWallet.InsufficientConfirmations.selector,
                0,
                2
            )
        );
        multiSigTest.executeTransaction(txId);
    }
}
