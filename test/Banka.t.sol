// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Banka} from "../src/Banka.sol";

contract BankaTest is Test {
    Banka public banka;
    address public alice;
    address public bob;
    function setUp() public {
        banka = new Banka();
        alice = makeAddr("alice");
        bob = makeAddr("bob");

        vm.deal(alice, 10 ether);
        vm.deal(bob, 12 ether);
    }

    function test_SahipDogruAyarlandi() public {
        assertEq(banka.sahip(), address(this));
    }
    function test_ParaYatirma() public {
        vm.prank(alice);
        banka.paraYatir{value: 1 ether}();
        assertEq(banka.bakiyeGor(alice), 1 ether);
        assertEq(banka.toplamMevduat(), 1 ether);
    }
    function test_ParaCekme() public {
        vm.startPrank(alice);
        banka.paraYatir{value: 5 ether}();
        banka.paraCek(2 ether);
        vm.stopPrank();
        assertEq(banka.bakiyeGor(alice), 3 ether);

        assertEq(banka.toplamMevduat(), 3 ether);
    }

    function test_SifirYatirmaRevert() public {
        vm.expectRevert(Banka.SifirMiktar.selector);
        banka.paraYatir{value: 0 ether}();
    }
    function test_YetersizBakiyeRevert() public {
        vm.expectRevert(
            abi.encodeWithSelector(Banka.BakiyeYetersiz.selector, 0, 1 ether)
        );
        banka.paraCek(1 ether);
    }

    function test_CokluKullanici() public {
        vm.prank(alice);
        banka.paraYatir{value: 3 ether}();
        vm.prank(bob);
        banka.paraYatir{value: 2 ether}();

        assertEq(banka.bakiyeGor(alice), 3 ether);
        assertEq(banka.bakiyeGor(bob), 2 ether);
        assertEq(banka.toplamMevduat(), 5 ether);
    }

    function testFuzz_YatirVeCek(uint256 _miktar) public {
        _miktar = bound(_miktar, 1, 10 ether);

        vm.deal(alice, _miktar);
        vm.prank(alice);
        banka.paraYatir{value: _miktar}();
        assertEq(banka.bakiyeGor(alice), _miktar);

        vm.prank(alice);
        banka.paraCek(_miktar);
        assertEq(banka.bakiyeler(alice), 0);
    }
}
