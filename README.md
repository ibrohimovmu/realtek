# RealStrike AR — Mustaqil Android Taktik AR Shooter (Laser Tag)

Qimmatbaho VR ko'zoynaklarsiz, oddiy smartfonlar orqali real hayotda (ko'chada yoki binoda) do'stlar bilan o'ynaladigan AR Laser Tag / PUBG harbiy otishma o'yini.

---

## 🎖️ Dizayn Falsafasi: Niagara Launcher Minimalizmi
- **Palitra:** Qorong'u, jiddiy, matt harbiy ranglar (`#0d0f12`, `#141820`, `#1a202c`), nozik chiziqlar, taktik to'q sariq (`#ff9800`) va kiber-zangori (`#00e5ff`) indikatorlar.
- **Tipografiya:** Monospace va texnik tabular raqamlar (`tabular-nums`), raqamlar sakramaydi va toza o'qiladi.
- **Multik va Neon emojilar yo'q:** 100% professional harbiy HUD interfeysi.

---

## 🚀 Asosiy Modullar

### 1. Taktik Profil va Mahalliy Saqlash (Profile & Ranks)
- **Callsign (Nikneym):** Shaxsiy chaqiruv kodini belgilash (masalan: `GHOST-01`, `VIPER-4`).
- **Biometrik Avatar:** Kamera yoki galereyadan o'z suratini yuklash yoki taktik harbiy avatar belgilarini tanlash.
- **Unvonlar (Ranks):** `BRONZE` ➔ `SILVER` ➔ `GOLD` ➔ `PLATINUM` ➔ `DIAMOND` ➔ `ACE` ➔ `CONQUEROR`.
- **Statistika:** Matches, Victories, Kills, Deaths, K/D nisbati, Win Rate, Headshots, Requisition Coins (tangalar). Barcha ma'lumotlar telefon xotirasida (`localStorage`) xavfsiz saqlanadi.

### 2. Qurollar xonasi va Do'kon (Armory & Shop)
- **M416 TACTICAL:** 5.56mm NATO, 25 HP zarba, 30 ta o'q, 550 RPM, o'rtacha qaytish (boshlang'ich qurol).
- **AKM 7.62 SOVIET:** 7.62x39mm, 35 HP zarba, 30 ta o'q, kuchli qaytish va og'ir zarba kuchi (600 coins).
- **AWM .300 MAGNUM:** .300 Win Mag snayper, 85 HP bir zarbali destruktiv quvvat, bolt-action mexanizm (1500 coins).
- **Web Audio Sintezatori:** 100% offline — hech qanday tashqi `.mp3` fayl yuklamasdan haqiqiy kukun portlashi, gilza tushishi, zatvor tortilishi va metall hitmarker tovushlarini matematik to'lqinlar orqali generatsiya qiladi.

### 3. Xonalar Tizimi va 0-Ping P2P (Lobby)
- **Xona ochish (Host):** 4 xonali PIN kod beriladi (masalan: `4821`). Ulangan barcha o'yinchilarning pingi, darajasi va tayyorligi ko'rinadi.
- **Xonaga ulanish (Join):** 4 xonali PIN kodni kiritib ulanish.
- **0-Ping Mesh:** Bitta Wi-Fi yoki mobil Hotspot orqali WebRTC DataChannel (2-5ms kechikish).
- **Solo Practice (AR Drone AI):** Bitta o'zingiz sinovdan o'tkazishingiz uchun jangovar taktik dron rejimi mavjud. Dron xonada uchadi, manevr qiladi va sizga qarata o't ochadi.

### 4. AR Kamera va Kompyuter Ko'rishi (CV Target Lock)
- Orqa kamera to'liq 60 FPS tezlikda ishga tushadi.
- Markazda ultra-ingichka taktik krossxeyr.
- **Kompyuter ko'rishi (Computer Vision):** Kadr markazidagi inson gavdasi yoki nishon silueti aniqlanganda nishon avtomatik ravishda qizil rangga o'tadi (`[TARGET LOCKED]`), masofa hisoblanadi va ovozli lokatsiya signali beriladi.
- **Qurol tepishi (Recoil) & Muzzle Flash:** Har bir o'q uzilganda ekran va krossxeyr yuqoriga sakrab qaytadi, o't chaqnaydi va telefon vibratori silkinadi.

### 5. Zarba va HP Mexanikasi (Damage Network)
- O'q tekkan raqib telefoni darhol kuchli tebranadi (`android.permission.VIBRATE`), ekranda qizil qon vinyetkasi uradi va HP kamayadi.
- Otuvchi ekranida PUBG qizil "X" hitmarkeri va uchib chiquvchi `-25 HP` / `CRITICAL -85 HP` soni paydo bo'ladi.
- HP < 30 bo'lganda: Sub-bass yurak urishi (heartbeat) tovushi yangraydi.
- HP 0 bo'lganda: Mag'lubda `ELIMINATED`, g'olibda `WINNER WINNER CHICKEN DINNER` sarlavhasi chiqadi va EXP/Tangalar beriladi.

---

## 📱 Loyihani Ishga Tushirish va Sinash

### 1. Mahalliy Wi-Fi orqali darhol sinash (Kompyuter yoki Telefon orqali):
```bash
# Serverni ishga tushiring:
node server.js
```
Konsolda sizning lokal Wi-Fi IP manzilingiz chiqadi (masalan: `http://192.168.1.100:3000`).
Do'stlaringiz bilan bitta Wi-Fi tarmog'iga yoki telefon Hotspotiga ulanib, brauzer orqali ochib o'ynang!

### 2. Standalone Android APK yig'ish (Android Studio yoki Gradle):
Loyiha to'liq `android/` papkasida Android Studio loyihasi sifatida tayyorlangan:
1. `node scripts/sync-assets.js` — barcha o'yin fayllarini APK ichiga joylaydi.
2. Android Studio'da `android/` papkasini oching: **Open an existing project ➔ D:\c2q\android**.
3. **Build ➔ Build Bundle(s) / APK(s) ➔ Build APK(s)** tugmasini bosing yoki terminalda:
   ```bash
   cd android
   ./gradlew assembleDebug
   ```
4. Tayyor `app-debug.apk` fayli telefoningizga o'rnatiladi. U mutlaqo mustaqil, hech qanday brauzer panelisiz, to'liq ekranli (immersive fullscreen) ishlaydi!
