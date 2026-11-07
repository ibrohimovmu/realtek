package com.nova.jarvis;

import android.content.ContentValues;
import android.content.Context;
import android.database.Cursor;
import android.database.sqlite.SQLiteDatabase;
import android.database.sqlite.SQLiteOpenHelper;
import android.net.Uri;
import android.provider.ContactsContract;

import org.json.JSONArray;
import org.json.JSONObject;

/**
 * Persistent Local SQLite Memory Vault ("nova_vault.db").
 * Stores:
 *  1. Relationship Matrix (OTA_ONA, BOBO_BUVI, USTOZ, DOST, BEGONA)
 *  2. 6-Gudok Call Secretary logs & audio recording paths
 *  3. Daily Schedule & Prayer Alarm state
 *  4. Key-Value long-term user habits, PIN, Voiceprint & Ghost Twin configuration
 */
public class NovaMemoryVault extends SQLiteOpenHelper {

    private static final String DB_NAME = "nova_vault.db";
    private static final int DB_VERSION = 2;

    private static NovaMemoryVault instance;

    public static synchronized NovaMemoryVault getInstance(Context ctx) {
        if (instance == null) {
            instance = new NovaMemoryVault(ctx.getApplicationContext());
        }
        return instance;
    }

    private NovaMemoryVault(Context context) {
        super(context, DB_NAME, null, DB_VERSION);
    }

    @Override
    public void onCreate(SQLiteDatabase db) {
        db.execSQL("CREATE TABLE IF NOT EXISTS relationship_matrix (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT," +
                "name TEXT NOT NULL," +
                "phone TEXT DEFAULT ''," +
                "telegram_handle TEXT DEFAULT ''," +
                "category TEXT NOT NULL," +
                "custom_greeting TEXT DEFAULT ''," +
                "updated_at INTEGER DEFAULT 0)");

        db.execSQL("CREATE TABLE IF NOT EXISTS call_secretary_logs (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT," +
                "caller_name TEXT," +
                "phone TEXT," +
                "category TEXT," +
                "ring_count INTEGER," +
                "caller_speech TEXT," +
                "nova_reply TEXT," +
                "summary TEXT," +
                "audio_path TEXT," +
                "timestamp INTEGER)");

        db.execSQL("CREATE TABLE IF NOT EXISTS daily_plans (" +
                "id INTEGER PRIMARY KEY AUTOINCREMENT," +
                "time_hm TEXT NOT NULL," +
                "title TEXT NOT NULL," +
                "category TEXT DEFAULT 'plan'," +
                "alarm_set INTEGER DEFAULT 0," +
                "enabled INTEGER DEFAULT 1)");

        db.execSQL("CREATE TABLE IF NOT EXISTS kv_memory (" +
                "mkey TEXT PRIMARY KEY," +
                "mval TEXT," +
                "updated_at INTEGER)");

        seedDefaults(db);
    }

    private void seedDefaults(SQLiteDatabase db) {
        long now = System.currentTimeMillis();
        insertSeedContact(db, "Onam", "", "@onam", "OTA_ONA",
                "Assalomu alaykum Onajon! Hozir Muhammadnosir muhim ish bilan band edilar, men yordamchilariman. Nima deb yetkazib qo'yay, hozir bo'shashlari bilan o'zlari sizga qo'ng'iroq qiladilar.", now);
        insertSeedContact(db, "Dadam", "", "@dadam", "OTA_ONA",
                "Assalomu alaykum Dadajon! Hozir Muhammadnosir muhim ish bilan band edilar, men yordamchilariman. Nima deb yetkazib qo'yay, bo'shashlari bilan o'zlari qo'ng'iroq qiladilar.", now);
        insertSeedContact(db, "Bobom", "", "", "BOBO_BUVI",
                "Assalomu alaykum Bobojon! Sog'liqlaringiz yaxshimi? Hozir nabirangiz muhim ishda edilar, fikringizni yozib olib darhol yetkazib qo'yaman.", now);
        insertSeedContact(db, "Buvim", "", "", "BOBO_BUVI",
                "Assalomu alaykum Buvijon! Umringiz uzoq bo'lsin! Hozir nabirangiz muhim ish bilan band edilar, nima deb yetkazib qo'yay?", now);
        insertSeedContact(db, "Ustoz", "", "@ustoz", "USTOZ",
                "Assalomu alaykum Ustoz! Hozir shogirdingiz dars va loyiha ustida ishlayotgan edilar. Topshirig'ingizni aytsangiz, yozib olib darhol yetkazaman.", now);
        insertSeedContact(db, "Jamshid", "", "@jamshid", "DOST",
                "Salom bro! Hozir o'rtog'ing ozgina band edi, nima gap o'zi? Aytaver, yozib olib o'ziga yetkazaman!", now);

        insertSeedPlan(db, "05:15", "Bomdod namozi va tonggi duo", "prayer", 1);
        insertSeedPlan(db, "09:00", "Chuqur kod yozish (Deep Work & AI)", "work", 1);
        insertSeedPlan(db, "12:30", "Peshin namozi va tanaffus", "prayer", 1);
        insertSeedPlan(db, "16:15", "Asr namozi", "prayer", 1);
        insertSeedPlan(db, "18:10", "Shom namozi", "prayer", 1);
        insertSeedPlan(db, "19:45", "Xufton namozi va kunlik tahlil", "prayer", 1);
    }

    private void insertSeedContact(SQLiteDatabase db, String name, String phone, String tg, String cat, String greeting, long ts) {
        ContentValues cv = new ContentValues();
        cv.put("name", name);
        cv.put("phone", phone);
        cv.put("telegram_handle", tg);
        cv.put("category", cat);
        cv.put("custom_greeting", greeting);
        cv.put("updated_at", ts);
        db.insert("relationship_matrix", null, cv);
    }

    private void insertSeedPlan(SQLiteDatabase db, String timeHm, String title, String cat, int enabled) {
        ContentValues cv = new ContentValues();
        cv.put("time_hm", timeHm);
        cv.put("title", title);
        cv.put("category", cat);
        cv.put("alarm_set", 0);
        cv.put("enabled", enabled);
        db.insert("daily_plans", null, cv);
    }

    @Override
    public void onUpgrade(SQLiteDatabase db, int oldVersion, int newVersion) {
        onCreate(db);
    }

    // ========================================================================
    // KEY-VALUE MEMORY VAULT
    // ========================================================================
    public synchronized void setMemory(String key, String value) {
        if (key == null) return;
        SQLiteDatabase db = getWritableDatabase();
        ContentValues cv = new ContentValues();
        cv.put("mkey", key);
        cv.put("mval", value == null ? "" : value);
        cv.put("updated_at", System.currentTimeMillis());
        db.insertWithOnConflict("kv_memory", null, cv, SQLiteDatabase.CONFLICT_REPLACE);
    }

    public synchronized String getMemory(String key, String defaultVal) {
        if (key == null) return defaultVal;
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = null;
        try {
            c = db.rawQuery("SELECT mval FROM kv_memory WHERE mkey = ? LIMIT 1", new String[]{key});
            if (c.moveToFirst()) {
                return c.getString(0);
            }
        } catch (Throwable ignored) {
        } finally {
            if (c != null) c.close();
        }
        return defaultVal;
    }

    public synchronized String getAllMemoryJson() {
        JSONObject obj = new JSONObject();
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = null;
        try {
            c = db.rawQuery("SELECT mkey, mval FROM kv_memory", null);
            while (c.moveToNext()) {
                obj.put(c.getString(0), c.getString(1));
            }
        } catch (Throwable ignored) {
        } finally {
            if (c != null) c.close();
        }
        return obj.toString();
    }

    // ========================================================================
    // RELATIONSHIP MATRIX CRUD & CALLER RESOLUTION
    // ========================================================================
    public synchronized String getRelationshipMatrixJson() {
        JSONArray arr = new JSONArray();
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = null;
        try {
            c = db.rawQuery("SELECT id, name, phone, telegram_handle, category, custom_greeting FROM relationship_matrix ORDER BY id ASC", null);
            while (c.moveToNext()) {
                JSONObject item = new JSONObject();
                item.put("id", c.getInt(0));
                item.put("name", c.getString(1));
                item.put("phone", c.getString(2));
                item.put("telegramHandle", c.getString(3));
                item.put("category", c.getString(4));
                item.put("customGreeting", c.getString(5));
                arr.put(item);
            }
        } catch (Throwable ignored) {
        } finally {
            if (c != null) c.close();
        }
        return arr.toString();
    }

    public synchronized void upsertRelationshipContact(String name, String phone, String tgHandle, String category, String greeting) {
        if (name == null || name.trim().isEmpty()) return;
        SQLiteDatabase db = getWritableDatabase();
        String cleanName = name.trim();
        Cursor c = null;
        int existingId = -1;
        try {
            c = db.rawQuery("SELECT id FROM relationship_matrix WHERE LOWER(name) = LOWER(?) LIMIT 1", new String[]{cleanName});
            if (c.moveToFirst()) existingId = c.getInt(0);
        } catch (Throwable ignored) {
        } finally {
            if (c != null) c.close();
        }

        ContentValues cv = new ContentValues();
        cv.put("name", cleanName);
        cv.put("phone", phone == null ? "" : phone.trim());
        cv.put("telegram_handle", tgHandle == null ? "" : tgHandle.trim());
        cv.put("category", (category == null || category.isEmpty()) ? "DOST" : category.trim().toUpperCase());
        cv.put("custom_greeting", greeting == null ? "" : greeting.trim());
        cv.put("updated_at", System.currentTimeMillis());

        if (existingId > 0) {
            db.update("relationship_matrix", cv, "id = ?", new String[]{String.valueOf(existingId)});
        } else {
            db.insert("relationship_matrix", null, cv);
        }
    }

    public synchronized void deleteRelationshipContact(int id) {
        SQLiteDatabase db = getWritableDatabase();
        db.delete("relationship_matrix", "id = ?", new String[]{String.valueOf(id)});
    }

    /**
     * Resolves an incoming phone number or contact name into:
     * {name, category, greeting} using both SQLite Relationship Matrix and Android ContactsContract.
     */
    public synchronized JSONObject resolveCallerProfile(Context context, String incomingNumberOrName) {
        JSONObject result = new JSONObject();
        String raw = incomingNumberOrName == null ? "" : incomingNumberOrName.trim();
        String resolvedName = "";
        String category = "BEGONA";
        String customGreeting = "";

        // 1. Check Android System Contacts if raw is a phone number
        if (!raw.isEmpty() && context != null) {
            resolvedName = queryAndroidContactName(context, raw);
        }
        String lookupLabel = !resolvedName.isEmpty() ? resolvedName : raw;
        String digitsOnly = raw.replaceAll("[^0-9]", "");
        String tail7 = digitsOnly.length() >= 7 ? digitsOnly.substring(digitsOnly.length() - 7) : digitsOnly;

        // 2. Match in SQLite Relationship Matrix
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = null;
        try {
            c = db.rawQuery("SELECT name, phone, category, custom_greeting FROM relationship_matrix", null);
            while (c.moveToNext()) {
                String mName = c.getString(0) == null ? "" : c.getString(0);
                String mPhone = c.getString(1) == null ? "" : c.getString(1).replaceAll("[^0-9]", "");
                String mCat = c.getString(2) == null ? "DOST" : c.getString(2);
                String mGreet = c.getString(3) == null ? "" : c.getString(3);

                boolean nameMatch = !lookupLabel.isEmpty() &&
                        (lookupLabel.toLowerCase().contains(mName.toLowerCase()) ||
                         mName.toLowerCase().contains(lookupLabel.toLowerCase()));
                boolean phoneMatch = !tail7.isEmpty() && !mPhone.isEmpty() && mPhone.endsWith(tail7);

                if (nameMatch || phoneMatch) {
                    if (resolvedName.isEmpty()) resolvedName = mName;
                    category = mCat;
                    customGreeting = mGreet;
                    break;
                }
            }
        } catch (Throwable ignored) {
        } finally {
            if (c != null) c.close();
        }

        // 3. Heuristic keyword detection if contact was in phonebook but not explicitly in table
        String lowerName = resolvedName.toLowerCase();
        if ("BEGONA".equals(category) && !resolvedName.isEmpty()) {
            if (lowerName.contains("ona") || lowerName.contains("aya") || lowerName.contains("mama")
                    || lowerName.contains("dada") || lowerName.contains("ota") || lowerName.contains("ada")) {
                category = "OTA_ONA";
            } else if (lowerName.contains("bobo") || lowerName.contains("buvi") || lowerName.contains("doda")) {
                category = "BOBO_BUVI";
            } else if (lowerName.contains("ustoz") || lowerName.contains("domla") || lowerName.contains("muallim")) {
                category = "USTOZ";
            } else {
                // Known in phonebook -> default to DOST
                category = "DOST";
            }
        }

        String ownerName = getMemory("owner_name", "Muhammadnosir");
        if (customGreeting.isEmpty()) {
            customGreeting = buildDefaultSecretaryGreeting(category, resolvedName, ownerName);
        }

        try {
            result.put("name", resolvedName.isEmpty() ? "Noma'lum raqam" : resolvedName);
            result.put("phone", raw);
            result.put("category", category);
            result.put("greeting", customGreeting);
        } catch (Throwable ignored) {}
        return result;
    }

    public static String buildDefaultSecretaryGreeting(String category, String callerName, String ownerName) {
        String safeOwner = (ownerName == null || ownerName.isEmpty()) ? "Muhammadnosir" : ownerName;
        switch (category) {
            case "OTA_ONA":
            case "BOBO_BUVI":
                return "Assalomu alaykum! Hozir " + safeOwner + " muhim ish bilan band edilar, men yordamchilariman. Nima deb yetkazib qo'yay, hozir bo'shashlari bilan o'zlari sizga qo'ng'iroq qiladilar.";
            case "USTOZ":
                return "Assalomu alaykum Ustoz! Hozir " + safeOwner + " dars va loyiha bilan band edilar. Topshirig'ingizni aytsangiz, yozib olib darhol yetkazib qo'yaman.";
            case "DOST":
                return "Salom bro! Hozir o'rtog'ing ozgina band edi, nima gap o'zi? Aytaver, yozib olib o'ziga yetkazaman.";
            default:
                return "Assalomu alaykum, kimni so'rayapsiz va qanday masala bo'yicha qo'ng'iroq qildingiz?";
        }
    }

    private String queryAndroidContactName(Context context, String phoneNumber) {
        Cursor cursor = null;
        try {
            Uri uri = Uri.withAppendedPath(ContactsContract.PhoneLookup.CONTENT_FILTER_URI, Uri.encode(phoneNumber));
            cursor = context.getContentResolver().query(
                    uri,
                    new String[]{ContactsContract.PhoneLookup.DISPLAY_NAME},
                    null, null, null
            );
            if (cursor != null && cursor.moveToFirst()) {
                return cursor.getString(0);
            }
        } catch (Throwable ignored) {
        } finally {
            if (cursor != null) cursor.close();
        }
        return "";
    }

    // ========================================================================
    // 6-GUDOK CALL SECRETARY LOGS
    // ========================================================================
    public synchronized void insertCallLog(String callerName, String phone, String category, int ringCount,
                                           String callerSpeech, String novaReply, String summary, String audioPath) {
        SQLiteDatabase db = getWritableDatabase();
        ContentValues cv = new ContentValues();
        cv.put("caller_name", callerName == null ? "Noma'lum" : callerName);
        cv.put("phone", phone == null ? "" : phone);
        cv.put("category", category == null ? "BEGONA" : category);
        cv.put("ring_count", ringCount);
        cv.put("caller_speech", callerSpeech == null ? "" : callerSpeech);
        cv.put("nova_reply", novaReply == null ? "" : novaReply);
        cv.put("summary", summary == null ? "" : summary);
        cv.put("audio_path", audioPath == null ? "" : audioPath);
        cv.put("timestamp", System.currentTimeMillis());
        db.insert("call_secretary_logs", null, cv);
    }

    public synchronized String getCallLogsJson() {
        JSONArray arr = new JSONArray();
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = null;
        try {
            c = db.rawQuery("SELECT id, caller_name, phone, category, ring_count, caller_speech, nova_reply, summary, audio_path, timestamp FROM call_secretary_logs ORDER BY timestamp DESC LIMIT 50", null);
            while (c.moveToNext()) {
                JSONObject item = new JSONObject();
                item.put("id", c.getInt(0));
                item.put("callerName", c.getString(1));
                item.put("phone", c.getString(2));
                item.put("category", c.getString(3));
                item.put("ringCount", c.getInt(4));
                item.put("callerSpeech", c.getString(5));
                item.put("novaReply", c.getString(6));
                item.put("summary", c.getString(7));
                item.put("audioPath", c.getString(8));
                item.put("timestamp", c.getLong(9));
                arr.put(item);
            }
        } catch (Throwable ignored) {
        } finally {
            if (c != null) c.close();
        }
        return arr.toString();
    }

    // ========================================================================
    // DAILY PLANS & PRAYER SCHEDULE
    // ========================================================================
    public synchronized String getDailyPlansJson() {
        JSONArray arr = new JSONArray();
        SQLiteDatabase db = getReadableDatabase();
        Cursor c = null;
        try {
            c = db.rawQuery("SELECT id, time_hm, title, category, alarm_set, enabled FROM daily_plans ORDER BY time_hm ASC", null);
            while (c.moveToNext()) {
                JSONObject item = new JSONObject();
                item.put("id", c.getInt(0));
                item.put("time", c.getString(1));
                item.put("title", c.getString(2));
                item.put("category", c.getString(3));
                item.put("alarmSet", c.getInt(4) == 1);
                item.put("enabled", c.getInt(5) == 1);
                arr.put(item);
            }
        } catch (Throwable ignored) {
        } finally {
            if (c != null) c.close();
        }
        return arr.toString();
    }

    public synchronized void upsertDailyPlan(String timeHm, String title, String category, boolean alarmSet) {
        if (timeHm == null || title == null) return;
        SQLiteDatabase db = getWritableDatabase();
        ContentValues cv = new ContentValues();
        cv.put("time_hm", timeHm.trim());
        cv.put("title", title.trim());
        cv.put("category", category == null ? "plan" : category);
        cv.put("alarm_set", alarmSet ? 1 : 0);
        cv.put("enabled", 1);
        db.insert("daily_plans", null, cv);
    }
}
