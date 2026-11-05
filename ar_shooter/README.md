# AR Shooter (Flutter Standalone & WiFi Multiplayer)

AR Shooter — bu qimmatbaho uskunalar talab qilmaydigan, oddiy smartfon kamerasi orqali real hayotda do'stlar bilan o'ynaladigan taktik mobil AR o'yini.
Dizayn standarti: **Elingo dark/purple UI kit** (fon: `#14141F`, kartalar: `#1F1F2E`, asosiy rang: `#6C47FF`, to'q sariq: `#FF8A00`, xavf: `#FF2A4D`).

---

## 🛠️ Qilingan Ishlar Tekshiruv Ro'yxati (Checklist)

- [x] **PHASE 1: Project Setup & Build Config**
  - Android platformasi yaratildi (`com.arshooter.ar_shooter`), minSdk 23 ga sozlandi.
  - Manifestda barcha ruxsatlar kiritildi (`CAMERA`, `INTERNET`, `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `VIBRATE`).
  - Binafsharang `#6C47FF` krossxeyr ilova ikonkalari `flutter_launcher_icons` orqali yaratildi.
  - Kamera ruxsatini do'stona o'zbek tilida tushuntiruvchi va rad etilsa sozlamalarni ochuvchi `CameraPermissionScreen` qurildi.
  - Faqat vertikal (portrait-only) yo'nalish majburiy qilindi.

- [x] **PHASE 2: Lokal Wi-Fi / Hotspot Multiplayer (No Internet)**
  - **UDP Beacon (4041-port):** Host har 2 soniyada xona nomini va o'yinchilar sonini e'lon qiladi. Klientlar 1 ta bosish bilan xonani topadi va ulanadi.
  - **TCP Sockets (4040-port):** Qat'iy `\n` bilan ajratilgan JSON format, har 3s ping/heartbeat, 10s timeout, xavfsiz 4KB paket cheklovi.
  - **Host uzilishi:** Host chiqqanda klientlar xavfsiz ogohlantiriladi va avto-qayta ulanish (3 ta urinish) ishlaydi.
  - **Noyob nomlar:** Bir xil taxallus bo'lsa `#2`, `#3` qo'shiladi.
  - **Real-time o'yin imkoniyatlari:** 3-daqiqalik Team Deathmatch (TDM) sinxron taymeri, g'olibga +100 tanga va jonli Kill Feed ("Ali ➔ Vali").
  - **Unit Testlar:** Xabarlarni tahlil qilish va o'yinchilarni birlashtirish bo'yicha testlar (`test/lan_test.dart`) 100% muvaffaqiyatli o'tdi.

- [x] **PHASE 3: Haqiqiy Nishon & Markaziy Krossxeyr Otishmasi**
  - Kamera tasviri markazidagi nishon qutisi (Box).
  - Ekran markazidagi krossxeyr orqali aniq otish testi (Crosshair Center Hit Test). Agar markaz nishon ustida bo'lmasa, o'q dushmanga tegmaydi.
  - PUBG metall "X" hitmarkeri, uchib chiquvchi `CRIT -39` / `-26` zarar sonlari va haptic vibratsiya.
  - Dushman bo'lmaganda aptechkalar, bog'lamlar va sovg'a qutilari tasodifiy tushadi.

- [x] **PHASE 4: Chuqur O'yin Mexanikasi (Game Depth)**
  - **Qurollar:** P92 Pistol, UMP45 SMG (Auto), M416 Rifle (Auto), S12K Shotgun, AWM Snayper.
  - Har bir qurolning individual o't ochish tezligi (fire rate), qurol tepishi (recoil shake), o'qlash animatsiyasi va haqiqiy tovushlari (`assets/audio/`).
  - **Loot Kamyobligi (Rarity):** Common, Rare, Epic, Legendary. Sovg'a qutisidan kamyob qurollar yoki kuchli ta'minot tushadi.
  - **Zirh va Bog'lam:** Kevlar Zirh (zararni 60% yutadi), Bog'lamlar (+25 HP) va Katta Aptechka (+60 HP).
  - **Dushman turlari:** Oddiy piyoda, Tezkor skaut va Og'ir zirhli tank.
  - **Kunlik Bonus:** 7 kunlik uzluksiz qatnov bonusi (Daily Streak).
  - **Sozlamalar va Reset:** Ovoz, vibratsiya, sezuvchanlik, taxallusni o'zgartirish va ma'lumotlarni tozalash (Reset).

- [x] **PHASE 5: Elingo Dizayn Standarti**
  - Qorong'u binafsharang palitra (`#14141F`, `#1F1F2E`, `#6C47FF`, `#FF8A00`, `#FF2A4D`).
  - 16px burchakli kartalar, table/podium (1, 2, 3-o'rin shohsupasi).
  - Nunito tipografiyasi va monospace HUD hisoblagichlari.
  - Kichik ekranlarda (360x640) ham elementlar sig'ishi to'liq ta'minlandi.

- [x] **PHASE 6: Sifat va Yig'ish (Quality & Delivery)**
  - `flutter analyze`: **0 issues found** (To'liq toza, eskirgan metodlarsiz).
  - `flutter test`: **4/4 testlar muvaffaqiyatli**.

---

## 🚀 O'yinni Ishga Tushirish va O'ynash

### 1. Ishga tushirish (Local Run):
```bash
cd D:\c2q\ar_shooter
flutter pub get
flutter run
```

### 2. Wi-Fi / Hotspot orqali do'stlar bilan o'ynash:
1. **1-o'yinchi:** Telefonida Hotspot (Kirish nuqtasi) yoqadi yoki ikkala telefon ham bitta Wi-Fi tarmog'iga ulanadi.
2. **Host bo'lish:** "Reyting" bo'limida "Wi-Fi o'yin" tabiga o'tib, **"Yangi Xona Ochish (Host)"** tugmasini bosadi.
3. **Ulanish:** Do'stlaringiz o'z telefonlarida xuddi shu bo'limga kirishsa, xona avtomatik ro'yxatda chiqadi. 1 ta bosish bilan ulanishadi!
4. **Jang:** Host **"3-Daqiqalik Jangni Boshlash (TDM)"** tugmasini bosadi. Har ikkala telefonda sinxron taymer va jang boshlanadi!

---

## 📱 Ma'lum Cheklovlar (Known Limits)
- Internet orqali (turli shaharlarda turib) o'ynash uchun tashqi Relay server talab qilinadi. Bu versiya mutlaqo **0-Ping Local Wi-Fi / Hotspot** tarmog'iga ixtisoslashgan.
