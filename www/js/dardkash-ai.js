/**
 * WABI — DARDKASH (HISSIY AI DO'ST VA MASLAHATCHI)
 * Samimiy, dono, chuqur psixologik va ma'naviy yondashuvchi sirdosh do'st ("bro").
 * Local Memory Vault + intelligent fallback response engine.
 */

class DardkashAI {
    constructor() {
        this.STORAGE_KEY = 'wabi_dardkash_chat_history';
        this.history = this.loadHistory();
    }

    loadHistory() {
        try {
            return JSON.parse(localStorage.getItem(this.STORAGE_KEY)) || [
                {
                    role: 'assistant',
                    text: 'Assalomu alaykum, qadrdonim. Men sening samimiy do\'sting — Dardkashman. Qalbingda nima og\'riq, savol yoki charchoq bo\'lsa, bemalol ayt. Bu yerda hamma narsa sir saqlanadi. Seni eshitishga tayyorman.'
                }
            ];
        } catch (e) {
            return [];
        }
    }

    saveHistory() {
        try {
            localStorage.setItem(this.STORAGE_KEY, JSON.stringify(this.history));
        } catch (e) {}
    }

    async sendMessage(userMessage) {
        if (!userMessage || !userMessage.trim()) return null;

        const cleanMsg = userMessage.trim();
        this.history.push({ role: 'user', text: cleanMsg });
        this.saveHistory();

        // Local psychological intelligence bank
        const reply = this.generateDeepEmpatheticResponse(cleanMsg);

        this.history.push({ role: 'assistant', text: reply });
        this.saveHistory();

        return reply;
    }

    generateDeepEmpatheticResponse(input) {
        const lower = input.toLowerCase();

        if (lower.includes('charchadim') || lower.includes('holsiz') || lower.includes('uyqu') || lower.includes('toliqdim')) {
            return "Bro, seni juda yaxshi tushunib turibman. Charchoq — bu insonning zaifligi emas, balki tanang va ruhing uzoq vaqt tinimsiz yuk ko'targanining belgisi. Hozir hamma narsani bir chetga sur. 1 piyola iliq choy ich, telefonni boshqa xonaga qo'y va hech bo'lmaganda 40 daqiqa to'liq sukutda dam ol. Ertaga yangi kuch bilan qaytamiz, sen yengilmaysan!";
        }

        if (lower.includes('jahl') || lower.includes('asab') || lower.includes('urish') || lower.includes('haqorat')) {
            return "Jahling chiqqani tabiiy, lekin to'xta! G'azab — bu o'zing zahar ichib, boshqaning o'lishini kutishga o'xshaydi. O'sha inson seni o'z darajasiga tushirmoqchi, unga bu lazzatni berma! Burundan 4 soniya chuqur nafas ol, 4 soniya ushlab tur va 6 soniyada sekin chiqaz. Erkak kishining kuchi baqirishda emas, eng qizigan paytda og'ir-bosiq bo'lib qaror qabul qilishida!";
        }

        if (lower.includes('ota') || lower.includes('ona') || lower.includes('onam') || lower.includes('otam') || lower.includes('uy')) {
            return "Oila masalasi doimo yurakning eng nozik joyi bo'ladi. Ota-onang ba'zan seni tushunmayotgandek, haqsizdek tuyulishi mumkin. Ammo unutma: ular senga yomonlik istamaydi, shunchaki o'z tajribalaridan kelib chiqib seni himoya qilmoqchi bo'lishadi. Gap qaytarma. O'rnidan tur, onangga tabassum bilan qara, 'Onajon, men sizni yaxshi ko'raman' deb ayt. Bu so'z qalbini eritib yuboradi.";
        }

        if (lower.includes('yolg\'iz') || lower.includes('yolgiz') || lower.includes('bo\'shliq') || lower.includes('tushkunlik')) {
            return "Bu ichki yolg'izlik va bo'shliq — sening ruhing katta o'zgarish arafasida ekanligidan darak beradi. Har bir kuchli inson o'z hayotining ma'lum pallasida yolg'iz qoladi. Bu sening shaxsiyating pishishi uchun kerak. Qalbingni behuda narsalar bilan to'ldirma. Bugun kechqurun tahorat olib, 2 rakaat ibodat qil, yoki dildan duo qil. Yaratganga aytilgan dard hech qachon javobsiz qolmaydi.";
        }

        if (lower.includes('telefon') || lower.includes('instagram') || lower.includes('o\'yin') || lower.includes('qul') || lower.includes('dangasa')) {
            return "Bro, muammoni tan olganing — bu allaqachon g'alabaning yarmi! Ekran seni dopamin tuzog'iga ilintirgan. Bitta qoida: hozirning o'zida telefoningni samolyot rejimiga qo'y, stol ustiga 1 ta kitob yoki noutbukni qo'y va roppa-rosa 25 daqiqa faqat bitta foydali ish qil (Pomodoro). 25 daqiqadan keyin o'zing bilan faxrlanasan!";
        }

        if (lower.includes('do\'st') || lower.includes('sotqin') || lower.includes('orqamdan') || lower.includes('sir')) {
            return "Yaqin insoningdan zarba yeyish eng achchiq darsdir. Lekin bu senga katta ne'mat: Alloh senga uning asl yuzini ko'rsatdi, bundan xursand bo'l! Unga qasos olma, uning sirlarini oshkor qilma. Mard kishi o'z sha'nini har qanday holatda toza saqlaydi. Yomon do'stdan qutulganing uchun shukr qil va hayotingda oldinga yur!";
        }

        if (lower.includes('namoz') || lower.includes('ibodat') || lower.includes('qazo')) {
            return "Namoz — bu qalbingning nafas olishidir. Kuniga 5 mahal Yaratgan oldida bosh egish insonning ruhiyatidagi barcha g'uborlarni yuvib tashlaydi. Agar qazo qilgan bo'lsang, darhol turing va qazosini o'qib qo'y. Shunda yelkangdagi og'ir yuk tushib ketganini o'zing his qilasan.";
        }

        return `Sening har bir so'zingni diqqat bilan o'qidim, qadrdonim. Bu vaziyatda eng muhimi — shoshma-shosharlik qilmaslik va vaziyatga aql bilan qarashdir. O'zingga savol ber: "Bu ishdan 1 yildan keyin nima qoladi?". Agar bu o'tkinchi bo'lsa, asabingni behuda sarflama. Katta maqsading tomon qat'iyat bilan qadam tashla. Men doimo sening yoningdaman!`;
    }
}

window.DardkashAI = DardkashAI;
