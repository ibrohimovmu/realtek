# AR Shooter — Rivojlanish Jarayoni (Progress Tracking)

---

## 📌 PHASE 0: Sozlash, Ruxsatnomalar va Boshlang'ich APK (Yakunlandi)

### ✅ Amalga oshirilgan ishlar (Done):
1. **Loyiha va SDK sozlamalari:**
   - Flutter Android konfiguratsiyasi: package `com.arshooter.ar_shooter`, minSdk 23, portrait-only orientatsiya.
   - Ilova nomi: `AR Shooter`.
   - Ilova ikonkasi: Maxsus binafsharang `#6C47FF` krossxeyr piktogrammasi (`flutter_launcher_icons`).
2. **Android Ruxsatnomalari (AndroidManifest.xml):**
   - `CAMERA`, `INTERNET`, `ACCESS_WIFI_STATE`, `ACCESS_NETWORK_STATE`, `CHANGE_WIFI_MULTICAST_STATE`, `ACCESS_FINE_LOCATION`, `ACCESS_COARSE_LOCATION`, `VIBRATE`.
   - `android.hardware.camera` talabi va `android:screenOrientation="portrait"` qat'iy o'rnatildi.
3. **Xavfsizlik va Maxfiylik Ogohlantirish Ekranı (Safety & Privacy Notice):**
   - 5 ta qat'iy qoidani o'z ichiga olgan yangi `SafetyNoticeScreen` yaratildi:
     1. Sof mobil virtual o'yin; faqat rozilik bergan do'stlar bilan o'ynash.
     2. Begona va notanish odamlarga qaratmaslik.
     3. Hech qanday haqiqiy yoki o'yinchoq qurollardan foydalanmaslik.
     4. Kamera tasvirlari faqat qurilmaning o'zida qayta ishlanishi, saqlanmasligi va tarmoqqa uzatilmasligi.
     5. Geopozitsiya faqat faol o'yin xonasidagi ishtirokchilar bilan ulashilishi.
   - Holat `Store` orqali mahalliy xotirada eslab qolinadi (`safetyAccepted`).
4. **Foydalanuvchiga qulay O'zbekcha Ruxsatnoma Tizimi:**
   - `CameraPermissionScreen`: Kamera ruxsatining sababi va maxfiyligi tushuntirilgan ekran. Rad etilgan taqdirda "Sozlamalarni Ochish" (`openAppSettings`) tugmasi mavjud.
   - `PermissionsService`: GPS nishonlash va bomba rejimlari uchun alohida O'zbekcha tushuntirish beruvchi dinamik ruxsat modal oynasi.
5. **Huquqiy hujjatlar:**
   - `CREDITS.md` yaratildi va barcha CC0/Royalty-free audio hamda grafik resurslar qayd etildi.
6. **Sifat nazorati:**
   - `flutter analyze`: 0 ta xatolik, 0 ta ogohlantirish (`No issues found!`).
   - `flutter test`: Barcha 4 ta unit test muvaffaqiyatli o'tdi (`All tests passed!`).

## 📌 PHASE 1: Haqiqiy Odamni Aniqlash (Pose Detection) va Optik Scope (Yakunlandi)

### ✅ Amalga oshirilgan ishlar (Done):
1. **Google ML Kit Pose Detection integratsiyasi:**
   - `google_mlkit_pose_detection` kutubxonasi qo'shildi.
   - `DetectionService` yaratildi: Kamera oqimi (`ImageFormatGroup.nv21` Android va `yuv420` boshqalar) sekundiga ~5 kadr tezlikda (throttle ~200ms) tejamkor qayta ishlanadi.
   - Sensor va qurilma orientatsiyasiga qarab aylanish (`InputImageRotation`) va old/orqa kamera oynalanishi to'g'ri boshqariladi.
2. **Nishon qutisi va Masofani hisoblash (Bounding Box & Distance Ratio):**
   - Odam pozasi nuqtalari (bosh, yelkalar, tizzalar, oyoqlar) asosida normalizatsiyalangan dinamik ramka hisoblanadi.
   - Inson bo'yining kadr balandligiga nisbati orqali real masofa metrda hisoblanadi (`distanceMeters`, masalan: `3.4m`).
   - Ekranda qizil "HOSTILE DETECTED (3.4m)" taktik qutisi ko'rsatiladi.
3. **Krossxeyr Markazi orqali Otish Testi (Hit Test):**
   - `FIRE` tugmasi bosilganda faqat ekran markazidagi nishon dushman qutisi ichida bo'lsa zarba o'tadi (`_targetRect.contains(center)`).
   - Nishonga tekkanda hitmarker X, qon sachrashi effekti, tebranish (haptic feedback) va ovoz beriladi.
   - O'ldirilganda `Store.addKill()` chaqiriladi va LAN orqali kill feed xabari tarqatiladi.
   - Odam topilmaganda 5 soniyadan so'ng avtomatik tarzda mashg'ulot spawner rejimiga tushadi. Medkit va qutilar saqlab qolingan.
4. **Optik Scope Zoom (1X / 2X / 4X):**
   - Pastki panelda yangi `SCOPE` boshqaruv tugmasi.
   - 1x, 2x, 4x kattalashtirishni `setZoomLevel` orqali almashtiradi.
   - Snayper miltig'i tanlanganda sukut bo'yicha 2x Scope yoqiladi.
   - Scope yoqilganda qoraytirilgan doiraviy vignette, mil-dot nishon belgilari va barqarorlashtirilgan (kamaytirilgan) tepish (recoil) ishlaydi.
5. **Debug Overlay (FPS & Latency):**
   - Profil sozlamalarida "FPS & Aniqlash Ko'rsatkichi (Debug)" tugmasi orqali yoqiladi.
   - Ekranning yuqori qismida `ML: 5.2 FPS | 45ms` yoki sekinlashganda `Aniqlash sekin` deb ogohlantiradi.
6. **Sifat nazorati va Testlar:**
   - `flutter analyze`: 0 xato, 0 ogohlantirish (`No issues found!`).
   - `flutter test`: Barcha 7 ta unit test (`lan_test`, `pose_test`, `widget_test`) 100% muvaffaqiyatli o'tdi.

## 📌 PHASE 2: Gibrid Nishon Hisoblash (Odam + Jamoa Rangi + GPS/Kompas) (Yakunlandi)

### ✅ Amalga oshirilgan ishlar (Done):
1. **Jamoalar va Ranglar tizimi (`lib/data/teams.dart`):**
   - 4 ta jamoa rangi belgilandi: `red` (Qizil), `blue` (Ko'k), `green` (Yashil), `yellow` (Sariq).
   - HSV rang spektri (hue) va to'yinganlik (saturation) filtri: Oq, qora, kulrang kiyimlar (`saturation < 0.22` yoki `value < 0.15`) `unknown` deb belgilanadi.
   - Do'stona zarba (Friendly Fire) tekshiruvi: O'z jamoasiga qarata otilganda zarba o'tmaydi.
2. **Kamera YUV buferidan Tana (Torso) rangini to'g'ridan-to'g'ri namunalash:**
   - Yelkalar va sonlar nuqtalari orasidagi to'rtburchak tana sohasidan YUV buferi orqali tejamkor piksellar olinadi (ortiqcha to'liq RGB konvertatsiya xotirasi ajratilmasdan).
   - Mediana hue hisoblanib, dushman jamoa rangi aniqlanadi.
3. **GPS va Kompas orqali Nishonlash (`SensorsService`):**
   - `geolocator` va `sensors_plus` integratsiyasi: Xona ichidagi har bir o'yinchi har 500 ms (2 Hz)da koordinatalari (`lat`, `lon`, `heading`, `accuracy`)ni uzatadi.
   - Buyuk doira (great-circle) bearing formulasi va Haversine masofa hisoblagichi.
   - Kamera 65° FOV va krossxeyr gorizontal og'ishi hisobga olingan holda, burchak xatosi `< 15°` va masofasi `2-100m` oralig'idagi eng yaqin raqib aniqlanadi.
   - Burchak aylanmasi (359° dan 1° gacha bo'lgan 2° masofa) to'g'ri ishlanadi.
4. **Fallback Ketma-ketligi (Zaxira zanjiri):**
   - Agar GPS aniqligi yomonlashsa (`> 15m`), yoki kompas nishon topa olmasa, yoki kiyim rangi `unknown` bo'lsa: zarba dushman jamoasiga yozilib, jamoaning tasodifiy a'zosi tanlanadi.
5. **Xost Tomonidan Tasdiqlash (Host Authoritative Validation):**
   - Otuvchi tirikligi, nishon tirikligi, qurol o't ochish tezligi (cooldown), qurolning maksimal masofasi, va vaqt og'ishi (`skew < 2000 ms`) xost tomonidan qat'iy tekshiriladi.
   - Tasdiqlangan zarba TCP orqali barchaga `damage` va `kill` xabari qilib tarqatiladi.
6. **Zarba qabul qilgan telefon reaksiyasi va HUD ko'rsatkichi:**
   - Jabrlanuvchi telefonda kuchli vibratsiya, qizil qonli fonga miltillash va HP tushishi.
   - HUD ekranida zarba nima asosida hisoblanganligi belgilanadi: `[🎯 Odam]`, `[🛡️ Jamoa]` yoki `[🛰️ GPS]`.
7. **Sifat nazorati va Testlar:**
   - `flutter analyze`: 0 xato, 0 ogohlantirish (`No issues found!`).
   - `flutter test`: Barcha 12 ta unit test (`hit_resolver_test`, `lan_test`, `pose_test`, `widget_test`) to'liq o'tdi.

## 📌 PHASE 3: Qurollar, Tovushlar, Bombalar va O'ljalar (Yakunlandi)

### ✅ Amalga oshirilgan ishlar (Done):
1. **Qurollar va Jangovar Parametrlar (`lib/data/weapons.dart`):**
   - Har bir qurol uchun alohida parametrlar: zarar (`dmg`), sig'im (`mag`), o't ochish rejimi (`auto`/`semi`/`burst`), maksimal masofa (`range`), krossxeyr sochilish burchagi (`spread`), tepish kuchi (`recoil`), o'qlash vaqti (`reloadMs`) va kamyoblik (`rarity`).
   - P92 Pistol (35m), UMP45 SMG (50m), M416 Rifle (85m), S12K Shotgun (25m), AWM Sniper (200m).
2. **Giroskopik Tebranish va Qo'ldagi Qurol Qatlami (`Weapon In Hand Overlay`):**
   - Giroskop va akselerometr harakati orqali qurol ekranning pastki o'ng burchagida silliq harakatlanadi (`_swayX`, `_swayY`).
   - Qurol nomi, uning o't ochish rejimi (`AUTO`/`SEMI`), masofasi va kamyoblik rangi dinamik aks etadi.
3. **Yangi Procedural CC0 Ovozlar:**
   - `grenade.wav`: Granata portlashi va to'lqin zarbasi ovozi.
   - `bomb_beep.wav`: Taktik bomba o'rnatish/zararsizlantirish va portlash oldi signali.
   - `pickup.wav`: O'ljalarni (aptechka, bog'lam, sovg'a qutisi) olgandagi jiringlagan signal.
4. **Granata Mexanikasi (Grenade System):**
   - Pastki boshqaruv panelida granatalar soni (`💣2`) va otish tugmasi.
   - Otilganda 3 soniyalik soat taymeri ishga tushadi (`3s... 2s... 1s...`).
   - Portlaganda `audio/grenade.wav` chalib, ekran silkinadi va 15 metr radiusdagi barcha dushmanlarga 85 birlik maydon zarari (area blast damage) yetkazadi. Do'stona zarbadan himoyalangan.
5. **Bomba Rejimi (Host-Controlled Bomb Mode):**
   - Xost o'yin davomida yuqori paneldagi `BOMBA` tugmasi orqali o'zining turgan GPS nuqtasiga bomba joylashtiradi (`bomb_plant`).
   - Holat LAN orqali barchaga sinxronlanadi (`BombStatus`: `arming`, `armed`, `defusing`, `defused`, `exploded`).
   - Bombaga 5 metrdan yaqin bo'lgan o'yinchilarga ekranda interaktiv amal tugmasi chiqadi:
     - Hujumchilar: 10 soniya davomida turib bombani qurollantiradi (`ARM`).
     - Himoyachilar: 10 soniya davomida turib bombani zararsizlantiradi (`DEFUSE`).
   - Bomba qurollanganda 45 soniyalik portlash taymeri boshlanadi va har 2 soniyada taktik signal beradi (`bomb_beep.wav`).
6. **O'ljalar va Kamyoblik (Loot System):**
   - Aptechka (+60 HP), Bog'lam (+25 HP), Zirh (60% zararni yutadi), Sovg'a qutilari kamyoblik bo'yicha tortilgan (common 50%, rare 30%, epic 15%, legendary 5%).
7. **Sifat nazorati va Testlar:**
   - `flutter analyze`: 0 xato, 0 ogohlantirish (`No issues found!`).
   - `flutter test`: Barcha 15 ta unit test 100% muvaffaqiyatli o'tdi.

## 📌 PHASE 4: Ro'yxatdan O'tish, Profil, Yutuqlar va Zaxira (Yakunlandi)

### ✅ Amalga oshirilgan ishlar (Done):
1. **Ko'p Bosqichli Onboarding Tizimi (`lib/screens/onboarding.dart`):**
   - 5 bosqichli silliq PageView sehrgari (wizard):
     - Bosqich 0: Jangovar taxallus (Callsign) — majburiy.
     - Bosqich 1: Operator shakli (Alpha, Specter, Valkyrie, Ghost, Titan, Cyber).
     - Bosqich 2: Hudud tanlash (O'zbekistonning barcha 13 ta viloyati va respublikasi).
     - Bosqich 3: Jamoa taktik rangi (Ko'k, Qizil, Yashil, Sariq).
     - Bosqich 4: Jangovar o'yin uslubi va sevimli qurol tanlovi.
   - Bosqichlar progress nuqtalari bilan aks etadi; taxallusdan tashqari barcha bosqichlarni "O'tkazib yuborish" imkoni mavjud.
2. **Yangi Harbiy Nishonlar va Yutuqlar Katalogi (`lib/data/achievements.dart`):**
   - 10 ta maxsus yutuq modeli: `first_blood`, `marksman`, `reaper`, `silver_rank`, `gold_rank`, `diamond_rank`, `armorer`, `dedicated`, `bomb_expert`, `medic`.
   - Har bir yutuq o'z nomi, tavsifi, ikonasi va o'ziga xos rangiga ega.
3. **Mukammal Profil Ekranı (`lib/screens/profile_screen.dart`):**
   - Operator shakli, taxallusi, hududi va o'yin uslubi aks etgan profil kartasi.
   - Keyingi unvongacha bo'lgan tajriba (XP) progress indikatori (`LinearProgressIndicator`).
   - 7 kunlik qatnov kalendari ("5 days straight" uslubida) va kunlik bonusni yig'ish mexanikasi.
   - Ochilgan va qulflangan nishonlar ro'yxati (ochilganlari rangli, qulflanganlari xiralashtirilgan).
   - Unvon oshganda (Rank-Up) chaqiladigan yorqin tabriklovchi modal oyna (`rankUpNotifier`).
4. **Maxsus Sozlamalar Ekranı (`lib/screens/settings_screen.dart`):**
   - Ovoz, vibratsiya, GPS va kompas almashish, taktik debug overlay o'chirib-yoqish.
   - Nishon sezgirligi slayderi (0.5x dan 2.0x gacha).
   - Taxallusni tahrirlash dialogi.
   - Server URL manzilini sozlash (onlayn rejim uchun).
   - O'zbekcha / Inglizcha til ko'rsatkichi.
   - Qizil xavfli zona: butun taraqqiyotni nollash (tasdiqlash bilan).
5. **Mahalliy Xotira Zaxirasi (JSON Export & Import):**
   - `Store.exportToJson()`: Barcha qurollar, statistika, darajalar va sozlamalarni chiroyli formatlangan JSON matniga o'giradi va buferga nusxalaydi.
   - `Store.importFromJson()`: Foydalanuvchi kiritgan JSON matnidan barcha yutuqlar va xotirani qayta tiklaydi; noto'g'ri formatlarni xatosiz ushlab qoladi.
6. **Sifat nazorati va Testlar:**
   - Yangi `test/progression_test.dart` yozildi (JSON export/import, rank-up triggers, streak cooldown, achievement catalog).
   - `flutter test`: Barcha 22 ta unit test 100% muvaffaqiyatli o'tdi.
   - `flutter analyze`: 0 xato, 0 ogohlantirish (`No issues found!`).

## 📌 PHASE 5: Mustahkam Lokal (WiFi & Hotspot) Multiplayer (Yakunlandi)

### ✅ Amalga oshirilgan ishlar (Done):
1. **UDP Xona Avto-Qidiruvi (Auto-Discovery Beacons):**
   - Xost har 2 soniyada UDP 4041 port orqali xona ma'lumotlarini (`RoomBeacon`: xona nomi, host IP, o'yinchilar soni, rejim `Team Deathmatch`, xarita `Taktik Arena`) efirga uzatadi.
   - Android Hotspot (nuqta ulashish) holatida global `255.255.255.255` bilan bir qatorda hotspot tarmog'ining ichki broadcast manziliga (masalan `192.168.43.255`) ham paket uzatiladi.
   - Klientlar 1 bosishda yaqin atrofdagi xonalarni ko'radi va ulanadi; qo'lda IP kiritish imkoniyati zaxirada saqlangan.
2. **Mustahkam TCP Protokoli va Avtomatik Tozalash:**
   - 4040 portida qatorma-qator (newline-delimited) JSON almashinuvi, har bir paket 4 KB hajm bilan cheklangan.
   - Har 3 soniyada `ping`/`pong` signallari, 10 soniyadan ortiq jim qolgan o'yinchilarni avtomatik o'chirish.
   - Soket va o'yinchi bog'lanishi (`_socketToPlayer`): o'yinchi tarmoqdan uzilishi bilan uning ismi xonadan va peshqadamlar jadvalidan darhol o'chiriladi va barcha ishtirokchilarga sinxronlanadi.
3. **Takroriy Taxalluslar Oldini Olish (Duplicate Nickname Prevention):**
   - Agar xonada "Ali" bo'lsa va yana bitta "Ali" qo'shilsa, unga avtomatik "Ali#2" beriladi va uning o'z ilovasiga `name_assigned` orqali yangi taxallus yuboriladi.
4. **Host Uzilishi Boshqaruvi (Host Departure Handling):**
   - Xost chiqqanda `host_leave` paketi tarqatiladi.
   - Klientlarda `hostDisconnectedNotifier` faollashib, ekranda qizil taktik ogohlantirish ko'rsatiladi va xatosiz lokal rejimga qaytariladi.
5. **Jonli O'yin Hodisalari va Team Deathmatch (TDM):**
   - Xost boshqargan 3-daqiqalik sinxron raund taymeri (`TDM: 180s`).
   - Raund tugaganda g'olib va mag'lub jamoalar hisoblanadi (Ko'k vs Qizil); g'olib o'yinchilarga **+100 Tanga va +50 XP** yutuq beriladi va neon modal oyna ochiladi.
   - Jonli hisoblar jadvali (Scoreboard): HUD-dagi TDM tugmasi yoki reyting tugmasi orqali jamoalar ochkolari, o'yinchilar jonli HP va qatllar sonini ko'rish mumkin.
   - Sci-Fi Kill Feed Toasts: PUBG uslubidagi `[🎯 Ali] ➔ [Vali]` krossxeyrli taktik bildirishnomalar.
6. **Sifat nazorati va Testlar:**
   - `test/lan_test.dart` kengaytirildi (`RoomBeacon` JSON serializatsiya/deserializatsiyasi, `MatchRound` qolgan vaqt va yakunlanish hisobi, takroriy nomlar).
   - `flutter test`: Barcha 24 ta unit test 100% muvaffaqiyatli o'tdi.
   - `flutter analyze`: 0 xato, 0 ogohlantirish (`No issues found!`).

## 📌 PHASE 6: Dizayn Sayqallash, Vazifalar va Qurollar Taqqoslovi (Yakunlandi)

### ✅ Amalga oshirilgan ishlar (Done):
1. **Dizayn Tizimi va Elingo Dark/Purple UI:**
   - Fon `#14141F`, kartochkalar `#1F1F2E`, asosiy rang `#6C47FF`, aksent to'q sariq `#FF8A00`, qizil xavf `#FF2A4D`, yashil muvaffaqiyat `#2EE59D`, sian krossxeyr `#22D3EE`.
   - 16 px yumaloq burchakli kartalar, pill shaklidagi boshqaruv tugmalari, 8/12/16/24 oralig'i (spacing scale).
2. **Peshqadamlar Jadvali va Top-3 Podium ([`leaderboard_screen.dart`](file:///D:/c2q/ar_shooter/lib/screens/leaderboard_screen.dart)):**
   - Top-3 shohsupasi: 1-o'rin Oltin toji va kubogi, 2-o'rin Kumush, 3-o'rin Bronza podiumlari.
   - Vaqt filtri chiplari: *"Haftalik"*, *"Oylik"*, *"Barcha vaqt"*.
3. **Interaktiv Jangovar Vazifalar Tizimi ([`missions_screen.dart`](file:///D:/c2q/ar_shooter/lib/screens/missions_screen.dart)):**
   - Kunlik va haftalik vazifalar (qatl qilish, tajriba to'plash, zirh va aslahalar ishlatish).
   - Jonli foizli progress paneli (`LinearProgressIndicator`).
   - "Mukofotni Olish" tugmasi: bajarilgan vazifalar uchun darhol tangalar va XP beradi; qayta olishdan himoyalangan (`claimedMissions`).
4. **Qurollar Arsenalining Visual Taqqoslovchi Panellari ([`shop_screen.dart`](file:///D:/c2q/ar_shooter/lib/screens/shop_screen.dart)):**
   - Har bir qurol uchun grafik parametrlar: Zarar (DMG), Otish Masofasi (Range), O'q Sig'imi (Mag), Barqarorlik (Stability/Recoil).
   - Kamyoblik nishonlari (Common, Rare, Epic, Legendary).
   - Qurolni xarid qilish va 1-bosishda "Tanlash" (Equip) boshqaruvi.
5. **Sifat nazorati va Testlar:**
   - `test/progression_test.dart` ga `claimMission` testlari qo'shildi.
   - `flutter test`: Barcha 25 ta unit test 100% muvaffaqiyatli o'tdi.
   - `flutter analyze`: 0 xato, 0 ogohlantirish (`No issues found!`).

## 📌 PHASE 7: Ixtiyoriy Onlayn Server va Global Reyting (Yakunlandi)

### ✅ Amalga oshirilgan ishlar (Done):
1. **FastAPI Onlayn Server (`ar_shooter/server/`):**
   - Python FastAPI mikro-serveri: `main.py`, `models.py`, `database.py`, `requirements.txt`.
   - SQLite ma'lumotlar bazasi (`players` va `rooms` jadvallari).
   - REST API endpointlar:
     - `GET /health`: Server sog'lig'i tekshiruvi.
     - `POST /api/stats/sync`: O'yinchi natijalarini (XP, qatllar, o'limlar, nishonlar) serverga sinxronlash va global o'rnini (#rank) qaytarish.
     - `GET /api/leaderboard`: Global reyting jadvalini eng yuqori XP bo'yicha saralab berish.
     - `POST /api/rooms/announce`: O'yin xonalarini onlayn e'lon qilish.
     - `GET /api/rooms`: Faol xonalar ro'yxatini olish (5 daqiqadan oshgan eski xonalar avtomatik tozalanadi).
   - Python testlari (`test_server.py`) 100% muvaffaqiyatli o'tdi.
2. **Flutter Onlayn Aloqa Klienti ([`server_client.dart`](file:///D:/c2q/ar_shooter/lib/services/server_client.dart)):**
   - Tashqi ortiqcha paketlarsiz sof `dart:io` `HttpClient` orqali qurildi.
   - 3 soniyalik timeout va xatoliklarni xavfsiz ushlab qolish (server o'chiq bo'lsa ham dastur qotmaydi yoki xato tashlamaydi).
   - `checkHealth()`, `syncStats()`, `fetchLeaderboard()`, `announceRoom()`, `fetchRooms()`.
3. **Sozlamalar Ekranida Server Aloqasi Testi ([`settings_screen.dart`](file:///D:/c2q/ar_shooter/lib/screens/settings_screen.dart)):**
   - Server URL manzilini kiritish imkoniyati.
   - "Aloqani Tekshirish" tugmasi orqali jonli ping testi (Online: yashil, Offline: to'q sariq).
4. **Global Onlayn Reyting Ekrani ([`leaderboard_screen.dart`](file:///D:/c2q/ar_shooter/lib/screens/leaderboard_screen.dart)):**
   - 3 ta toifali chip navigatsiyasi: "Lokal Reyting", "Global Onlayn", "Wi-Fi / Hotspot LAN".
   - "Global Onlayn" tanlanganda serverdan jonli reyting jadvalini yuklash va Top-3 shohsupada aks ettirish.
   - "Sinxronlash (Mening Natijamni Yuborish)" tugmasi orqali lokal natijalarni onlayn bazaga jo'natish.
5. **Sifat nazorati va Testlar:**
   - Yangi `test/server_client_test.dart` yozildi (oflayn holatda 0-crash tekshiruvlari).
   - `flutter test`: Barcha 30 ta unit test 100% muvaffaqiyatli o'tdi (`All tests passed!`).
   - `flutter analyze`: 0 ta xatolik, 0 ta ogohlantirish (`No issues found!`).

### 🔄 Jarayondagi ishlar (In Progress):
- PHASE 8 kutmoqda: Yakuniy sifat tekshiruvi, release build va yetkazib berish (Quality and delivery).

---

## Keyingi bosqichlar rejalari:
- [x] PHASE 0: Setup, permissions, first APK
- [x] PHASE 1: Real person detection + scope
- [x] PHASE 2: Combined hit resolution (person + team color + GPS/compass)
- [x] PHASE 3: Weapons, sound, bombs, loot
- [x] PHASE 4: Registration, profile, progression
- [x] PHASE 5: Rock-solid local multiplayer (WiFi LAN / hotspot)
- [x] PHASE 6: Polish pass 1
- [x] PHASE 7: Optional online server
- [ ] PHASE 8: Quality and delivery
