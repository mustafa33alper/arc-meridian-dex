# Arc Meridian — Arc Testnet üzerinde AMM DEX

**Canlı uygulama:** https://arcmeridian.netlify.app

Arc Testnet (Circle'ın stablecoin-odaklı Layer-1 ağı) üzerinde çalışan, Uniswap V2
tarzı bir otomatik piyasa yapıcı (AMM) merkeziyetsiz borsa (DEX). Herkes cüzdanını
bağlayıp test tokenlerini takas edebilir (swap) ve likidite sağlayabilir.

## Özellikler

- Cüzdan bağlama (MetaMask / EIP-1193 uyumlu her cüzdan)
- Arc Testnet ağını otomatik ekleme/geçiş
- Token takası (swap) — sabit çarpım formülü (x·y=k), %0.3 işlem ücreti
- Likidite ekleme / çıkarma
- Test token faucet'i (kendi test tokenlerimiz için) + Circle USDC/EURC faucet
  yönlendirmesi
- Kontrat adresleri ve token listesi doğrudan koda gömülü — kimin nereden
  girerse girsin ekstra ayara gerek yok

## Deploy edilmiş kontratlar (Arc Testnet, Chain ID 5042002)

| Kontrat | Adres |
|---|---|
| ArcFactory | `0xd88551ac320493d045Bb7EC51311a0A9cD6f500e` |
| ArcRouter | `0x9352Bb36C93DC0A8638F250f77cbB5B9A32F7d04` |
| ARCA (test token) | `0x4E195F4Fc2678657414d6467EEA6432A30500231` |
| ARCB (test token) | `0x58B5f658133124aAD0B49eFF503296141c1dAd73` |
| USDC (Circle, resmi) | `0x3600000000000000000000000000000000000000` |
| EURC (Circle, resmi) | `0x89B50855Aa3bE2F677cD6303Cec089B5F319D72a` |

## Proje yapısı

```
arc-dex/
├── contracts/        Solidity kontratlarının okunabilir kopyası
├── hardhat/           Deploy için kullanılan Hardhat projesi
└── frontend/          index.html — web arayüzü (Netlify'da yayında)
```

## Kendi kontratlarını deploy etmek istersen

```
cd hardhat
npm install
cp .env.example .env
# .env dosyasına kendi private key'ini gir
npm run deploy
```

Script; Factory, Router ve iki test tokenini sırayla deploy edip adresleri
terminale yazdırır. Ardından `frontend/index.html` içindeki `CONFIG` ve
`TOKENS` sabitlerini kendi adreslerinle güncelleyip bir statik site
barındırma servisine (Netlify, Vercel, GitHub Pages) yükleyebilirsin.

## Kontrat mimarisi

- **ArcERC20.sol** — temel ERC20 (LP tokenları ve test tokenlarının atası)
- **TestToken.sol** — herkesin `faucet()` fonksiyonuyla ücretsiz mint
  edebildiği test tokeni
- **ArcFactory.sol** — token çiftleri için havuz (pair) oluşturur, takip eder
- **ArcPair.sol** — asıl AMM mantığı: `mint`, `burn`, `swap` — sabit çarpım
  (x·y=k) formülü, %0.3 işlem ücreti
- **ArcRouter.sol** — kullanıcı arayüzünün etkileşime girdiği ana kontrat:
  likidite ekleme/çıkarma ve swap işlemlerini havuzlarla koordine eder

Uniswap V2'nin genel mimarisinden ilham alınmıştır, dış kütüphaneye
(OpenZeppelin vb.) bağımlı değildir.

## Uyarı

Bu kontratlar **denetlenmemiştir (audit edilmemiştir)** ve sadece testnet /
öğrenme amaçlıdır. Mainnet'te ya da gerçek değerle kullanmayın.
