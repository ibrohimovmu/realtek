# AR Shooter — FastAPI Online Server

Ushbu server AR Shooter o'yini uchun ixtiyoriy (optional) global xab vazifasini bajaradi:
- O'yinchilar statistikasi va global reytingni saqlash (`SQLite`).
- Do'stlar bilan uzoq masofada (WAN/Internet) o'ynash uchun faol xonalarni e'lon qilish (`Room Registry`).
- Ilova 100% oflayn ishlashga moslashgan: agar server ulanmasa yoki o'chiq bo'lsa, o'yin xatosiz lokal Wi-Fi/Hotspot rejimida davom etadi.

---

## 🚀 Ishga tushirish (Run Locally)

1. Bog'liqliklarni o'rnating:
```bash
pip install -r requirements.txt
```

2. Serverni ishga tushiring:
```bash
python -m uvicorn main:app --host 0.0.0.0 --port 7860 --reload
```

3. Server tekshiruvi:
- API salomatligi: `http://localhost:7860/health`
- Interaktiv Swagger hujjatlari: `http://localhost:7860/docs`

---

## 📡 API Endpoints

- `GET /health`: Server holati va versiyasi.
- `POST /api/stats/sync`: O'yinchi tajribasi (XP), qatllari va hududini sinxronlash va global o'rnini (rank) olish.
- `GET /api/leaderboard`: Global peshqadamlar jadvali (XP bo'yicha saralangan).
- `POST /api/rooms/announce`: O'yin xonasini global ro'yxatga kiritish yoki yangilash.
- `GET /api/rooms`: Yaqin 60 soniya ichida faol bo'lgan xonalar ro'yxati.
