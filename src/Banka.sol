// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract Banka {
    mapping(address => uint256) public bakiyeler;
    address public immutable sahip;
    uint256 public toplamMevduat;

    event ParaYatirildi(address indexed kim, uint256 miktar);
    event ParaCekildi(address indexed kim, uint256 miktar);

    error BakiyeYetersiz(uint256 mevcut, uint256 istenen);
    error TransferBasarisiz();
    error SifirMiktar();
    error SadeceSahip();

    constructor() {
        sahip = msg.sender;
    }

    function paraYatir() public payable {
        if (msg.value == 0) revert SifirMiktar();
        bakiyeler[msg.sender] += msg.value;
        toplamMevduat += msg.value;
        emit ParaYatirildi(msg.sender, msg.value);
    }

    function paraCek(uint256 _miktar) public {
        uint256 mevcutBakiye = bakiyeler[msg.sender];
        if (mevcutBakiye < _miktar) {
            revert BakiyeYetersiz(mevcutBakiye, _miktar);
        }

        bakiyeler[msg.sender] -= _miktar;
        toplamMevduat -= _miktar;

        (bool basarili, ) = msg.sender.call{value: _miktar}("");
        if (!basarili) revert TransferBasarisiz();

        emit ParaCekildi(msg.sender, _miktar);
    }

    function bakiyeGor(address _hesap) public view returns (uint256) {
        return bakiyeler[_hesap];
    }
}
