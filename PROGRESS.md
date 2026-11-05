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

### 🔄 Jarayondagi ishlar (In Progress):
- PHASE 2 kutmoqda: Gibrid nishon hisoblash (Odam + Jamoa kiyim rangi + GPS/kompas).

### ⚠️ Ma'lum cheklovlar (Known Limits):
- Juda qorong'i muhitda kamera odam pozasini aniqlay olmasligi mumkin; bunday holatda tizim 5 soniyadan so'ng mashg'ulot rejimiga o'tadi.

---

## Keyingi bosqichlar rejalari:
- [x] PHASE 0: Setup, permissions, first APK
- [x] PHASE 1: Real person detection + scope
- [ ] PHASE 2: Combined hit resolution (person + team color + GPS/compass)
- [ ] PHASE 3: Weapons, sound, bombs, loot
- [ ] PHASE 4: Registration, profile, progression
- [ ] PHASE 5: Rock-solid local multiplayer (WiFi LAN / hotspot)
- [ ] PHASE 6: Polish pass 1
- [ ] PHASE 7: Optional online server
- [ ] PHASE 8: Quality and delivery
