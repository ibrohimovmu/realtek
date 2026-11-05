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

### 🔄 Jarayondagi ishlar (In Progress):
- PHASE 1 kutmoqda: Haqiqiy odamni ML Kit orqali aniqlash (Pose Detection) va optik zoom (Scope 1x/2x/4x).

### ⚠️ Ma'lum cheklovlar (Known Limits):
- GPS faqat ochiq havoda yuqori aniqlikka ega; xona ichida fallback mexanizmi ishlatiladi (Phase 2 da kengaytiriladi).

---

## Keyingi bosqichlar rejalari:
- [ ] PHASE 1: Real person detection + scope
- [ ] PHASE 2: Combined hit resolution (person + team color + GPS/compass)
- [ ] PHASE 3: Weapons, sound, bombs, loot
- [ ] PHASE 4: Registration, profile, progression
- [ ] PHASE 5: Rock-solid local multiplayer (WiFi LAN / hotspot)
- [ ] PHASE 6: Polish pass 1
- [ ] PHASE 7: Optional online server
- [ ] PHASE 8: Quality and delivery
