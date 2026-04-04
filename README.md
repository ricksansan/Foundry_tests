# Foundry Test Çalışmaları

Solidity öğrenirken yazdığım kontratların Foundry testleri. 4 kontrat, 62 test — hepsi geçiyor.

## Kontratlar

| Kontrat | Test | Sonuç |
|---------|------|-------|
| `Banka.sol` | `Banka.t.sol` | 7/7 ✅ |
| `TokenSale.sol` | `TokenSale.t.sol` | 20/20 ✅ |
| `MerkeziyetsizPiyango.sol` | `MerkeziyetsizPiyango.t.sol` | 18/18 ✅ |
| `CokluImzaCuzdani.sol` | `CokluImzaCuzdani.t.sol` | 17/17 ✅ |

## Ne test edildi?

**Banka** — ETH yatırma/çekme, yetersiz bakiye, sıfır miktar, çoklu kullanıcı, fuzz test

**TokenSale** — Token satın alma, iade, satış kapatma/açma, event kontrolleri, fazla ETH iadesi, fuzz test

**MerkeziyetsizPiyango** — ERC-20 ile bilet alma, zaman bazlı çekiliş (vm.warp), ödül dağıtımı, tam round senaryosu

**MultiSigWallet** — Çoklu sahip yönetimi, işlem önerme/onaylama/geri alma/çalıştırma, yetki kontrolleri

## Kullanılan Foundry özellikleri

- `vm.prank` / `vm.startPrank` — farklı kullanıcı simülasyonu
- `vm.deal` — test ETH'si verme
- `vm.warp` — zamanı ileri sarma
- `vm.expectRevert` — hata beklentisi (selector ve parametreli)
- `vm.expectEmit` — event testi
- `bound` + `testFuzz_` — fuzz testing
- `assertEq`, `assertGt`, `assertTrue`, `assertFalse`

## Çalıştır

```bash
forge test -vv
```

Belirli bir kontrat için:

```bash
forge test --match-contract ContractName -vv
```

## Kurulum

```bash
git clone git@github.com:ricksansan/Foundry_tests.git
cd Foundry_tests
forge install
forge test
```
