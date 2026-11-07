/**
 * WABI — TARBIYA VA HISSIY HAYOT ENSIKLOPEDIYASI
 * 5 ta katta kategoriya, 40 dan ortiq to'liq psixologik tahlil, hayotiy misollar va tavsiyalar.
 * 0% Demo / 100% Haqiqiy O'zbekona Tarbiya va Ruhiy Rivojlanish Qo'llanmasi.
 */

const TARBIYA_DATA = {
    categories: [
        {
            id: "yigit",
            title: "O'g'il Bola va Yigit Xarakteri",
            subtitle: "Mardlik, mas'uliyat, iroda va qat'iyat",
            icon: "⚔️",
            topics: [
                {
                    id: "yigit-nafs",
                    title: "Nafs va Dangasalikni Sindirish",
                    tag: "Iroda & Intizom",
                    summary: "Ertalab erta turish, jismoniy mashg'ulot, o'z so'zining ustidan chiqish va erkaklik mas'uliyati.",
                    content: `
Har bir yigit kishining hayotidagi eng birinchi va eng ulug' g'alabasi — bu o'z nafsini, tanbal tanasini va behuda istaklarini yengishidir. Erkak kishi hissiyotlarga yoki tananing injiqliklariga qul bo'lmaydi. U o'z oldiga maqsad qo'yadi va ob-havoga, kayfiyatga yoki charchoqqa qaramasdan uni bajaradi.

Ertalab tongda budilnik jiringlaganda o'rindan sapchib turish — bu oddiy harakat emas, bu kunning birinchi jangida qozonilgan g'alabadir. Kim ertalab o'z ko'rpasi ustidan g'olib chiqa olmasa, u hayotdagi katta qiyinchiliklarda yutqazadi. Jismoniy mashq (turnik, yugurish, kurash, futbol) erkak kishiga nafaqat mushak, balki o'ziga bo'lgan cheksiz ishonch, chidamlilik va sabr beradi. Tanang qanchalik qattiq mehnatga ko'niksa, ruhing shunchalik metin bo'ladi.

O'z so'zining ustidan chiqish: Erkak kishining eng qimmatli boyligi — uning lafzi. Agar va'da berdingmi, yer yorilsa ham uni bajar! Agar uddalay olmasang, soxta va'dalar bilan birovning ishonchini oyoqosti qilma. Bir marta so'zida turmagan inson boshqalar nazdida obro'sini butunlay yo'qotadi.

NIMA QILISH KERAK:
1. Har kuni bir vaqtda (tong soat 05:30-06:00 da) o'rindan turishni odat qil.
2. Har kuni kamida 30 daqiqa tanangni terlatadigan jismoniy mashq bilan shug'ullan.
3. Bergan har bir va'dangni daftarga yozib qo'y va uni belgilangan vaqtdan oldinroq bajar.
4. "Bugun kayfiyatim yo'q" degan zaif bahonani lug'atingdan butunlay chiqarib tashla.

NIMA QILISH XATO:
- Peshin paytigacha uxlab, tanangni shalviratib qo'yish.
- Oson va arzon bahonalar bilan o'zingni aldash.
- Boshqalarning oldida ko'p gapirib, amalda hech narsa qilmaslik.
                    `
                },
                {
                    id: "yigit-ekran",
                    title: "Telefon, Instagram va O'yinlarga Qul Bo'lmaslik",
                    tag: "Diqqat & Fokus",
                    summary: "Dopamin tuzog'idan chiqish, soxta rohatdan voz kechish va qimmatli yoshlikni ilm va kasbga yo'naltirish.",
                    content: `
Bugungi kunda yigitlar uchun eng katta xavf ko'chada emas, cho'ntagidagi ekranning ichida yashiringan. Instagram Reels, TikTok, qimor elementlari bor o'yinlar inson miyasidagi dopamin tizimini o'g'irlaydi. Ular sizni hech narsa qilmasdan soxta rohat olishga ko'niktiradi, natijada real hayotdagi o'qish, mashq qilish va mehnat qilish zerikarli bo'lib tuyula boshlaydi.

Ekranda boshqalarning yasama hayotini tomosha qilib o'tirish — o'z umringni axlatga tashlash bilan barobar. Sen tomoshabin bo'lish uchun emas, bu hayotda o'z izingni qoldiruvchi qahramon bo'lish uchun dunyoga kelgansan. Telefon sizga xizmat qilishi kerak, siz unga emas!

Haqiqiy erkak kishi o'z diqqatini lazer nuri kabi bitta narsaga jamlay oladi: dasturlash, chet tillari, muhandislik, savdo yoki biror halol hunar. Kunda 4-5 soat bekorga ekran surgan yigit 5 yildan keyin hech qanday qadrsiz, pulsiz va maqsadsiz qoladi. Har kuni kitob o'qigan va mahorat o'rgangan yigit esa jamiyatning yetakchisiga aylanadi.

NIMA QILISH KERAK:
1. Chalg'ituvchi ilovalar (Instagram, o'yinlar) uchun kunda ko'pi bilan 15-20 daqiqa limit belgilang.
2. Telefonni yotoqxonadan uzoqda qoldiring va uxlashdan 1 soat oldin umuman qaramang.
3. Har kuni kamida 2 soatni kelajakda daromad va obro' keltiradigan bitta aniq hunar (kod yozish, til, kitob)ga sarflang.
4. Zerikish hissi paydo bo'lganda telefonga yopishmasdan, kitob o'qing yoki chuqur fikrlang.

NIMA QILISH XATO:
- Har 5 daqiqada sababsiz telefonni yoqib tekshirish.
- Ovqatlanayotganda yoki oila davrasida telefonga tikilib o'tirish.
- Onlayn o'yinlarda soatlab vaqt yo'qotib, asabni buzish.
                    `
                },
                {
                    id: "yigit-oila",
                    title: "Oila Ustuni va Suyanchi Bo'lish",
                    tag: "Oila & Qadriyat",
                    summary: "Ota-onaning qadriga yetish, onaning duosini olish va singillarga haqiqiy qalqon bo'lish.",
                    content: `
Yigit kishining kuchi uning mushtida emas, oilasiga ko'rsatgan mehri, g'amxo'rligi va himoyasidadir. Otang peshona teri bilan topib kelayotgan nonning har bir ushog'ida qancha mashaqqat borligini his qil. Otang sen uchun eng yaxshi sharoitni yaratishga urinyapti, sen esa uning yelkasidagi yukni yengillatishga intilishing shart.

Onaning ko'ngli — nozik shisha. Unga hech qachon ovozingni ko'tarma, qoshlaringni chimirma va "uf" dema. Onangning duosi — sening hayotdagi eng kuchli qalqoning va omading kalitidir. Har kuni onangning holidan xabar ol, "Onajon, sizga qanday yordam beray?" deb so'ra.

Singillaringga haqiqiy qalqon bo'l. Qiz bola hayotida birinchi marta mehr, ehtirom va himoyani o'z akasidan yoki ukasidan ko'rishi kerak. Agar sen singlingni e'zozlasang, u tashqaridagi soxta shaxslarning aldamchi gaplariga uchmaydi. U o'z akasi bilan faxrlanadigan, akasi uning doimiy suyanchi ekanini his qiladigan qilib ulg'aytir.

NIMA QILISH KERAK:
1. Ota-onang xonaga kirganda o'rningdan turib salom ber va ularning xizmatiga shay bo'l.
2. Singling yoki onangning og'ir yukini ko'tarib ol, uydagi erkak kishi qilishi kerak bo'lgan barcha yumushlarni o'z zimmangga ol.
3. Otang bilan do'stona suhbatlash, uning maslahatlariga quloq sol va minnatdorchilik bildir.
4. Singlingning xursandchiligi uchun kutilmagan shirinlik yoki sovg'a olib kel.

NIMA QILISH XATO:
- Ota-onaga gap qaytarish, ta'na qilish yoki qovoq solish.
- O'z uyingda begona mehmonday faqat tayyoriga ayyor bo'lib yashash.
- Singillaringga qo'pollik qilish yoki ularning tuyg'ularini masxara qilish.
                    `
                },
                {
                    id: "yigit-jamiyat",
                    title: "Ko'chada, Do'stlar Orasida va Jamiyatda O'zini Tutish",
                    tag: "Salobat & Odob",
                    summary: "Haqiqiy do'stni manfaatparastdan ajratish, g'iybatdan uzoq bo'lish va kattalar oldida kamtar bo'lish.",
                    content: `
Ko'cha va jamoat joyi — bu sening kimligingni ko'rsatadigan ko'zgu. Yigit kishi har qadamida o'z sha'nini, ota-onasining tarbiyasini himoya qiladi. Baland ovozda kulish, so'kinish, tupurish yoki boshqalarga bepisand qarash — bu kuchlilik emas, balki tarbiyasizlik va ichki nochorlik belgisidir.

Do'st tanlashda o'ta ehtiyot bo'l. Senga faqat maishatda, choyxona yoki o'yinda hamroh bo'ladiganlar haqiqiy do'st emas. Haqiqiy do'st — xato qilganingda seni to'xtatadigan, ilm va yaxshilikka chorlaydigan, ortingdan seni himoya qiladigan insondir. Agar davrangdagi do'stlaring vaqtni o'ldirayotgan, behuda g'iybat qilayotgan bo'lsa, ulardan darhol uzoqlash!

Kattalar, ustozlar va qariyalarning oldida doimo kamtar, salobatli va ehtiromli bo'l. Gapirayotganda odob bilan gapir, ularning so'zini bo'lma. Yigit kishining salobati uning kamtarligi va og'ir-bosiqligidadir.

NIMA QILISH KERAK:
1. Salom berishda birinchi bo'l, qo'l berib ko'rishganda nigohingni yerga qaratmay, ishonch bilan qara.
2. Majlis va davralarda behuda gapirma, faqat foydali va o'ylab gapir.
3. Birovning orqasidan g'iybat qilinayotgan davrani darhol tark et yoki mavzuni yaxshilikka bur.
4. O'zingdan kuchsizlarga nisbatan saxiy, adolatli va himoyachi bo'l.

NIMA QILISH XATO:
- Ko'cha-ko'yda shovqin solib, o'zini ko'z-ko'z qilish.
- Do'stlarning xatolariga sherik bo'lish yoki ularning yomon ishlariga ko'z yumish.
- Kattalar oldida oyoqni chalishtirib, beparvo o'tirish.
                    `
                },
                {
                    id: "yigit-moliya",
                    title: "Moliyaviy Mustaqillik va Halol Mehnat",
                    tag: "Kasb & Baraka",
                    summary: "Yoshlikdan o'z mehnati bilan rizq topish, pul qadrini bilish va isrofdan qochish.",
                    content: `
Har bir yigit kishi erta ulg'ayishi va o'z oyog'ida mustahkam turishi shart. Ota-onaning cho'ntagiga ko'z tikib, 20 yoshdan oshganda ham ulardan telefon yoki kiyim uchun pul so'rash — yigit kishi uchun or bo'lishi kerak. Erkak kishining eng katta faxri — o'zining halol peshona teri bilan topgan nonidir.

Halol mehnatning kichigi yoki uyatlisi bo'lmaydi. Yozda mardikorlik qilish, ustaga shogird tushish, kurerlik qilish yoki kompyuterda dasturlash orqali pul topish — barchasi sharafdir. Asosiysi — topilgan pul halol bo'lsin va o'z kuchi bilan topilsin. Mehnat qilgan inson pulning har bir so'mi qanday qiyinchilik bilan kelishini tushunadi va uni behuda isrof qilmaydi.

Moliyaviy savodxonlikni yoshlikdan o'rgan. Topgan pulingning hammasini yeb-ichishga sarflama. Kamida 20-30 foizini kelajakdagi katta loyihalar, o'z bilimingni oshirish (kitoblar, kurslar) uchun jamg'ar.

NIMA QILISH KERAK:
1. Imkon qadar ertaroq bitta foydali kasb yoki hunarni chuqur o'rganishni boshla.
2. Harajatlaringni har doim hisoblab bor, keraksiz ko'r-ko'rona xaridlardan tiyil.
3. Ilk topgan daromadingdan eng birinchi bo'lib ota-onangga sovg'a ol yoki ehson qil.
4. Moliyaviy masalalarda aldamchilik, qimor yoki tez boyib ketish va'dalariga aslo ishonma.

NIMA QILISH XATO:
- Boqimandalik kayfiyatida yashash va ota-onaning topganiga suyanib qolish.
- Boshqalarga ko'z-ko'z qilish uchun qimmatbaho narsalarni qarzga olish.
- O'z bilimi va kasbiga pul tikmasdan, faqat ko'ngilxushlikka sarflash.
                    `
                }
            ]
        },
        {
            id: "qiz",
            title: "Qiz Bola Tarbiyasi va Go'zal Odob",
            subtitle: "Qadr-qimmat, hayo, iffat va hissiy donolik",
            icon: "🌸",
            topics: [
                {
                    id: "qiz-qadr",
                    title: "Qiz Bolaning O'z Qadr-Qimmatini Anglashi",
                    tag: "Iffat & Ishonch",
                    summary: "Hayo, o'ziga xos go'zallik, ijtimoiy tarmoqlardagi soxta e'tiborga aldanmaslik.",
                    content: `
Qiz bola — har qanday xonadonning guli, fayzi va kelajak millatning onasidir. Qiz bolaning eng buyuk libosi va uni malikalardan-da ustun qiladigan xislati — bu uning hayosi va iffatidir. Hayoli qiz o'z qadrini biladi, uning har bir harakatida, kiyinishida va so'zida chuqur ehtirom sezilib turadi.

Bugungi ijtimoiy tarmoqlardagi layklar, begona odamlarning arzon maqtovlari va soxta e'tibori — bu qopqondir. O'z chiroyini yoki shaxsiy hayotini ommaga ko'z-ko'z qilib e'tibor qidirish qiz bolaning qadrini tushiradi. Sening asl qadring begonalarning fikrida emas, sening qalbing pokligida, aqlingda va axloqingdadir.

O'ziga bo'lgan sog'lom ishonch: Boshqa qizlarga taqlid qilma, ularning kiyimi yoki boyligiga havas bilan qarab o'zingni kamsitma. Alloh taolo har bir qizni o'zgacha qalb va go'zallik bilan yaratgan. O'z qadringni bilsang, hech qanday pastkash inson seni kamsita olmaydi yoki alday olmaydi.

NIMA QILISH KERAK:
1. Kiyinish madaniyatida doimo pokiza, bosiq va nafis bo'lishga odatlan.
2. Ijtimoiy tarmoqlarda shaxsiy rasmlarni begonalarga ko'rsatishdan saqlan.
3. O'zingga bo'lgan ishonchni arzon maqtovlardan emas, o'qigan kitoblaring va o'rgangan hunarlaringdan ol.
4. Qadringni biladigan, hayoli va oqila qizlar bilan do'stlash.

NIMA QILISH XATO:
- Layklar va izohlar uchun o'z sha'nini xatarga qo'yish.
- Tashqi ko'rinishga haddan tashqari ruju qo'yib, ichki dunyoni bo'sh qoldirish.
- O'zini boshqalar bilan solishtirib, tushkunlikka tushish.
                    `
                },
                {
                    id: "qiz-hissiyot",
                    title: "Hissiyotlarni Boshqarish va Chiroyli So'zlashuv",
                    tag: "Muloqot & Sabr",
                    summary: "Injiqlik va araz o'rniga muloyim va qat'iy tushuntirish san'ati.",
                    content: `
Qiz bolaning qalbi tabiatan o'ta nozik va hissiyotlarga boy bo'ladi. Ammo bu hissiyotlar boshqarilmasa, ular injiqlik, asabiylik, ko'z yosh va uzoq davom etadigan arazga aylanishi mumkin. Arazlash — bu muammoni hal qilmaydi, balki insonlar o'rtasida devor quradi.

Haqiqiy dono qiz o'z hissiyotlarini ifodalashni biladi. Biror narsa yoqmaganda baqirmaydi yoki kunlab qovoq solib yurmaydi. U o'zini qo'lga oladi va o'sha holatni muloyim, ammo aniq tushuntiradi: "Menga bu gap og'ir botdi, iltimos boshqa bunday qilmang". Muloyim so'z toshni ham eritadi.

Shirinso'zlik — qiz bolaning eng qudratli qurolidir. Uydagilarga, ota-onaga, aka-ukaga chiroyli so'zlash oilaning muhitini jannatga aylantiradi. Qiz bolaning tilidan doimo yaxshilik, tasalli va mehr yog'ilib turishi kerak.

NIMA QILISH KERAK:
1. Jahlingiz chiqqanda darhol gapirmang, ichingizda 10 gacha sanang yoki sovuq suv iching.
2. Arazlash o'rniga, o'z tuyg'ularingizni sokin ovozda ochiq ayting.
3. Uydagilarga shirin muomala qilishni odat qiling, "iltimos", "rahmat", "kechirasiz" so'zlarini ko'p ishlating.
4. Muammolarga ijobiy nazar bilan qarab, tabassum qilishni unutmang.

NIMA QILISH XATO:
- O'z istagini baqirib yoki yig'lab talab qilish.
- Kunlab arazlab, uydagilarning asabini tarang qilish.
- Achchiq til va gina-kuduratlarni yurakda saqlab yurish.
                    `
                },
                {
                    id: "qiz-ilm",
                    title: "Ilm, Farosat va Kelajakka Tayyorgarlik",
                    tag: "Aql & Dunyoqarash",
                    summary: "O'qimishli, pazanda, tejamkor va har tomonlama mukammal qiz bo'lish.",
                    content: `
Bugungi qiz bola — ertangi kunning onasi, tarbiyachisi va oilaning mustahkam poydevoridir. "Qiz bolaga o'qish nimaga kerak?" degan eskirgan fikrlar mutlaqo noto'g'ri. Ilmli ona butun jamiyatni ilmli qiladi! Qiz bola qanchalik dunyoqarashi keng, kitobxon va zukko bo'lsa, uning tarbiyalagan farzandlari ham shunchalik buyuk insonlar bo'lib yetishadi.

Ilm bilan bir qatorda farosat juda muhim. Farosat — bu aytilmagan gapni tushunish, vaziyatga qarab to'g'ri qaror qabul qilish, uydagi tartib-intizomni va tozalikni saqlash qobiliyatidir. Farosatli qiz bor xonadonda doimo tozalik, shinamlik va fayz bo'ladi.

Uy ro'zg'or yumushlari, pazandalik, tikuvchilik va tejamkorlikni o'rganish qiz bolaning ziynatidir. Mazali taom tayyorlash — bu oddiy mahorat emas, bu oilaga mehr ulashishning eng go'zal usulidir.

NIMA QILISH KERAK:
1. Har kuni kamida 30-40 sahifa badiiy va ilmiy kitoblar o'qing.
2. Onangizga oshxonada va ro'zg'or ishlarida chin ko'ngildan yordamlashing, yangi taomlar pishirishni o'rganing.
3. Chet tillarini va zamonaviy raqamli ko'nikmalarni o'rganishga vaqt ajrating.
4. Uyning tozaligi va kiyimlarning tartibiga doimo alohida e'tibor qarating.

NIMA QILISH XATO:
- Bo'sh vaqtni faqat bema'ni seriallar yoki ijtimoiy tarmoqlarda o'tkazish.
- Ro'zg'or ishlaridan qochish va ularni majburiyat deb bilish.
- O'qishni va kitobxonlikni tashlab qo'yish.
                    `
                }
            ]
        },
        {
            id: "ota-ona",
            title: "Ota-onalar Akademiyasi",
            subtitle: "Baqirmasdan tarbiyalash, ishonch va samimiy do'stlik",
            icon: "🏡",
            topics: [
                {
                    id: "ota-baqirish",
                    title: "Baqirmasdan va Kamsitmasdan Tarbiyalash",
                    tag: "Mehr & Psixologiya",
                    summary: "Bolani boshqalar bilan solishtirishning fojiasi va ijobiy rag'bat kuchi.",
                    content: `
Bolaga baqirish — bu tarbiya emas, balki kattalarning o'z ojizligi va hissiy charchog'ini tan olishidir. Qattiq baqirilgan va kamsitilgan bola o'z xatosini tushunmaydi, aksincha, u qo'rquvni, yolg'on gapirishni va ichiga berkinishni o'rganadi. Baqirish bolaning miyasidagi xavfsizlik hissini sindiradi.

Eng katta xato — o'z bolasini birovning bolasi bilan solishtirishdir: "Qara, qo'shnining o'g'li a'lochi, sen esa..." Bu so'zlar bolaning qalbida hasad, o'ziga nisbatan nafrat va ota-onadan uzoqlashishni tug'diradi. Har bir bola o'ziga xos iste'dod bilan tug'ilgan. Sizning vazifangiz uni birovga o'xshatish emas, uning o'z ichidagi eng yaxshi fazilatlarni ochishdir.

Tarbiyada asosiy qoida: Bolani qilmishi uchun emas, o'zini yaxshi ko'ring. Tanbeh berayotganda ham uning shaxsiyatiga tegmasdan, faqat qilgan xatosiga e'tibor qarating: "Sen yomon bolasan" emas, "Sen juda aqllisan, lekin bu qilgan ishing noto'g'ri bo'ldi".

NIMA QILISH KERAK:
1. Jahlingiz chiqqanda bolaga jazo bermang, avval o'zingiz tinchlanib oling.
2. Har kuni bolangizni quchoqlab, uni yaxshi ko'rishingizni ayting (kamida 4-5 marta).
3. Bolaning kichik yutuqlarini ham payqab, uni chin dildan maqtang va rag'batlantiring.
4. Xato qilganda xatoning sababini va uni qanday to'g'rilashni bosiqlik bilan tushuntiring.

NIMA QILISH XATO:
- Ommaviy joyda yoki boshqalarning oldida bolani haqorat qilish.
- Boshqa bolalarni unga o'rnak qilib ko'rsatish va solishtirish.
- Bolaning fikrini eshitmasdan, faqat o'z buyruqlaringizni o'tkazish.
                    `
                },
                {
                    id: "ota-osmir",
                    title: "O'smir Yoshi (12-18) Farzand bilan Do'st Bo'lish",
                    tag: "Isyon & Hamkorlik",
                    summary: "Nazoratni bosim bilan emas, ishonch va samimiy suhbat bilan o'rnatish siri.",
                    content: `
O'smirlik davri — inson hayotidagi eng murakkab gormonal va ruhiy bo'ronlar davridir. Bu yoshda bola endi yosh bola emas, lekin hali to'liq katta ham bo'lmagan. U o'z mustaqilligini isbotlashga urinadi. Agar bu paytda ota-ona unga qattiq bosim o'tkazsa, o'smir isyon ko'taradi yoki sirlarini ko'chadagi begona odamlarga aytishni boshlaydi.

O'smir bilan munosabatda "hokim" emas, "dono maslahatchi va do'st" roliga o'tish zarur. Uning telefonini yashirincha titkilash yoki har bir qadamini so'roq qilish o'rniga, unga shunday muhit yaratingki, uning o'zi kelib sirlarini sizga aytib bersin.

Uning qiziqishlarini hurmat qiling. U eshitayotgan musiqani, o'ynayotgan o'yinini yoki qiziqqan sohasini darhol rad etmasdan, nima uchun qiziqayotganini so'rang. Hurmat ko'rgan o'smir ota-onasining maslahatlariga jon qulog'i bilan quloq soladi.

NIMA QILISH KERAK:
1. Har hafta o'smir farzandingiz bilan yakkama-yakka suhbat (choy ichish, sayr) qiling.
2. Unga oilaviy masalalarda maslahat soling, o'zini katta odamdek his qilsin.
3. Uning xatolariga darhol baqirmasdan, avval uning nuqtai nazarini oxirigacha eshiting.
4. Uning do'stlarini uyga taklif qiling va ular bilan yaqindan tanishing.

NIMA QILISH XATO:
- O'smirni kichik boladek doimiy nazorat va buyruq ostida ushlab turish.
- Uning orzulari va qiziqishlarini masxara qilish.
- Shaxsiy chegaralarini (eshik taqillatmasdan kirish, buyumlarini titish) buzish.
                    `
                }
            ]
        },
        {
            id: "yosh",
            title: "Yosh Davrlari Ensiklopediyasi",
            subtitle: "Chaqaloqlikdan yetuklikkacha bo'lgan ruhiy ehtiyojlar",
            icon: "🌱",
            topics: [
                {
                    id: "yosh-0-3",
                    title: "0-3 Yosh: Xavfsizlik va Ona Mehri",
                    tag: "Bog'lanish",
                    summary: "Dunyoni xavfsiz deb bilish, tana kontaktining kuchi va ruhiy poydevor.",
                    content: `
Bu davrda inson miyasi hayotidagi eng tez sur'atda rivojlanadi. 0-3 yoshdagi bolaning eng asosiy ehtiyoji — dunyo xavfsiz ekanini his qilishdir. Bu xavfsizlik onaning mehri, iliq quchog'i va yig'laganida darhol yetib kelishi orqali shakllanadi. "Yig'lasa e'tibor berma, o'rganadi" degan qarashlar bolaning asab tizimiga jiddiy zarar yetkazadi.

NIMA QILISH KERAK:
1. Ko'p quchoqlang, tana kontakti va beshik tebratish orqali xotirjamlik bering.
2. Bola bilan ko'p gaplashing, qo'shiqlar va allalar ayting.
                    `
                },
                {
                    id: "yosh-4-7",
                    title: "4-7 Yosh: Qiziquvchanlik va O'yin Davri",
                    tag: "Axloq & Tasavvur",
                    summary: "Savollarga to'g'ri javob berish, yolg'on gapirmaslikka o'rgatish va o'yin orqali qoidalar.",
                    content: `
Bu yoshdagi bolalar kunda yuzlab "nega?" degan savollarni berishadi. Bu savollarga beparvo bo'lmang, ularning zakovatini rag'batlantiring. Yolg'on gapirmaslik bu davrda o'rgatiladi. Agar bola xato qilib uni rost aytsa, uni jazolamang, balki rost gapirgani uchun maqtang.

NIMA QILISH KERAK:
1. O'yinlar orqali odob, navbat kutish va buyumlarni yig'ishtirishni o'rgating.
2. Har bir savoliga erinmasdan, sodda tilda to'g'ri javob bering.
                    `
                },
                {
                    id: "yosh-8-11",
                    title: "8-11 Yosh: Mas'uliyat va Dastlabki Mehnat",
                    tag: "Maktab & Odatlar",
                    summary: "Kun tartibi, o'z xonasini tozalash, sport va kitobxonlik odatini shakllantirish.",
                    content: `
Bu yoshda inson mas'uliyatni o'rganishi shart. O'z sumkasini o'zi yig'ishi, to'shagini yig'ishi va darslarini o'zi bajarishi kerak. Ota-onaning vazifasi uning o'rniga qilib berish emas, balki tartibni nazorat qilishdir. Sport to'garaklariga berish irodani mustahkamlaydi.
                    `
                },
                {
                    id: "yosh-12-15",
                    title: "12-15 Yosh: O'smirlik Bo'roni va O'zlikni Qidirish",
                    tag: "Shaxsiyat & Isyon",
                    summary: "Tana o'zgarishlari, yomon davralardan himoyalanish va shaxsiyatni shakllantirish.",
                    content: `
Bu davrda bola o'z "Men"ini qidiradi. Do'stlarning fikri ota-onaning fikridan ustun bo'lib ko'rinishi mumkin. Ota-ona do'stona munosabat qurmasa, bola yomon davralarga qo'shilib ketishi xavfi yuqori bo'ladi.
                    `
                },
                {
                    id: "yosh-16-20",
                    title: "16-20+ Yosh: Hayotiy Burilish Nuqtasi",
                    tag: "Yetuklik & Kelajak",
                    summary: "Katta maqsadlar qo'yish, kasb tanlash, mustaqillik va oilaviy hayotga tayyorgarlik.",
                    content: `
Bu yosh — bolalik tugab, katta hayot boshlanadigan palla. Inson o'z hayotining rulini o'z qo'liga olishi, kasb-hunar egasi bo'lishi va o'z xatti-harakatlari uchun to'liq javobgar bo'lishi shart.
                    `
                }
            ]
        },
        {
            id: "vaziyat",
            title: "Hayotiy Vaziyatlar Simulyatori",
            subtitle: "Har qanday og'ir holatda o'zini qanday tutish kerak?",
            icon: "🧭",
            topics: [
                {
                    id: "vaziyat-jahl",
                    title: "Vaziyat 1: Qattiq Jahling Chiqqanda va Kimdir Seni Haqorat Qilganda",
                    tag: "Sabr & Kuch",
                    summary: "Ichki tahlil, 10 soniyalik qoida, aniq javob so'zlari va xatolar.",
                    content: `
ICHKI HOLAT TAHLILI:
Haqorat qilingan paytda miyada amigdala faollashadi, adrenalin otilib chiqadi va tanang "ur yoki qoch" holatiga o'tadi. Sen g'azab olovida yonasan va o'sha zahoti javob qaytarib, o'sha insonni til bilan yoki musht bilan yo'q qilging keladi. Ammo unutma: Haqorat — bu birovning ichidagi axlatidir. Agar sen ham baqirsang, o'sha axlatga botasan.

BIRINCHI 10 SONIYADA NIMA QILISH KERAK:
1. Birorta ham so'z aytma! Og'zingni mahkam yop.
2. Burundan chuqur nafas olib, og'izdan sekin chiqaz.
3. Raqibingning ko'zlariga bosiqlik va sovuqqonlik bilan tik qara. U sening jahling chiqishini kutyapti, sen esa unga bu lazzatni berma!

NIMA DEYISH KERAK (ANIQ SO'ZLAR):
Sokin, past va og'ir ovozda:
"Sening bu gaplaring menga emas, sening o'z tarbiyangga baho beradi. Men bu darajaga tushmayman. Suhbat tugadi."
Agar vaziyat jismoniy xavf tug'dirsa: "Orqaga tisaril. Men janjal istamayman, lekin o'zimni himoya qila olaman."

QANDAY XATODAN QOCHISH KERAK:
- Xuddi unga o'xshab baqirib so'kinish (sen ham u bilan bir darajaga tushib qolasan).
- O'zingni oqlashga urinib, ko'p gapirish.
- Qorquvdan titrab ko'zlarni olib qochish.
                    `
                },
                {
                    id: "vaziyat-otaona-notogri",
                    title: "Vaziyat 2: Ota-onang Seni Noto'g'ri Tushunganda",
                    tag: "Ehtirom & Sabr",
                    summary: "Mehnating ko'rinmagandek tuyulganda qanday gaplashish kerak?",
                    content: `
ICHKI HOLAT TAHLILI:
Sen astoydil harakat qilding, yaxshilik istading, lekin ota-onang seni nohaq aybladi yoki mehnatingni payqamadi. Qalbingda qattiq alam, tushunilmaslik va adolatsizlik hissi uyg'onadi. "Nega hamma narsam yomon ko'rinadi?" degan fikr keladi.

BIRINCHI 10 SONIYADA NIMA QILISH KERAK:
1. Darhol gap qaytarma va ovozingni ko'tarma.
2. Ichingda ularning yoshi kattaligini, charchaganliklarini va senga yomonlik istamasliklarini esla.

NIMA DEYISH KERAK (ANIQ SO'ZLAR):
"Otajon / Onajon, sizni juda yaxshi tushunib turibman. Siz xavotirdasiz. Ammo ruxsat bersangiz, bu ishning aslida qanday bo'lganini xotirjam aytib bersam. Men sizni xafa qilishni aslo xohlamagan edim."

QANDAY XATODAN QOCHISH KERAK:
- Eshikni qattiq yopib xonaga kirib ketish.
- "Sizlar meni hech qachon tushunmaysizlar!" deb baqirish.
- Arazlab ovqat yemay qo'yish.
                    `
                },
                {
                    id: "vaziyat-yolgizlik",
                    title: "Vaziyat 3: Ichki Bo'shliq va Hissiy Yolg'izlik Paytida",
                    tag: "Ruhiy Tinchlik",
                    summary: "Hech kim seni tushunmayotgandek tuyulganda nima qilish kerak?",
                    content: `
ICHKI HOLAT TAHLILI:
Atrofingda odamlar ko'p, lekin qalbing huvillab yotibdi. O'zingni hech kimga keraksiz, tushunilmagandek his qilyapsan. Bu holat o'smirlikda va yoshlikda har bir buyuk insonning boshidan o'tadigan sinovdir. Bu bo'shliq — sening qalbing o'sishni, haqiqiy ma'no topishni talab qilayotganidan darakdir.

BIRINCHI 10 SONIYADA NIMA QILISH KERAK:
1. Telefonga yopishib, soxta xursandchilik qidirmang.
2. Tahorat olib, 2 rakaat namoz o'qing yoki toza havoga chiqing.

NIMA QILISH KERAK:
O'zingiz bilan yolg'iz qolib, qog'ozga barcha hislaringizni yozing. Kitob o'qing. O'zingizdan nochorroq, qiynalgan insonlarga yordam bering — birovning ko'nglini ko'targan insonning o'z qalbi ham nurga to'ladi.

QANDAY XATODAN QOCHISH KERAK:
- Depressiyaga berilib, kunlab qorong'i xonada yotish.
- Zararli odatlar orqali tasalli izlash.
                    `
                },
                {
                    id: "vaziyat-sotqinlik",
                    title: "Vaziyat 4: Yaqin Do'sting Siringni Sotganda",
                    tag: "Sadoqat & Xulosa",
                    summary: "Orqangdan gapirilganda munosabatni qanday to'g'ri hal qilish kerak?",
                    content: `
ICHKI HOLAT TAHLILI:
Eng ishongan insoning senga xiyonat qildi. Bu yurakka xanjar urilgandek og'riq beradi. Qalbingda qasos olish, uning ham sirlarini hammaga yoyish istagi paydo bo'ladi.

NIMA QILISH KERAK:
1. Hech qachon uning sirlarini oshkor qilib qasos olma! Erkak kishi pastkashlikka pastkashlik bilan javob bermaydi.
2. U bilan yakkama-yakka uchrashib: "Men senga ishongan edim, lekin sen bu ishonchni oqlamading. Xafa emasman, ammo oramizdagi do'stlik shu yerda tugadi" deb ayting.
3. Bu voqeani katta hayotiy saboq deb qabul qiling va har kimga ham siringizni ochavermaslikni o'rganing.
                    `
                },
                {
                    id: "vaziyat-davrada-gapirish",
                    title: "Vaziyat 5: Katta Davrada Hayajonlanmasdan Gapirish",
                    tag: "Notiqlik & Jasorat",
                    summary: "Ko'pchilik oldida gapirganda ovoz qaltirashi va qo'rquvni yengish.",
                    content: `
ICHKI HOLAT TAHLILI:
Hamma senga qarab turganda yuraging tez urib, tomog'ing quriydi. Bilingki, bu hayajon hatto eng professional notiqlarda ham bo'ladi. Hayajon — bu normal holat, faqat uni boshqarish kerak.

NIMA QILISH KERAK:
1. Gapirishdan oldin 3 soniya jim turing, zalga qarab tabassum qiling.
2. Butun zalga emas, oldingi qatordagi bitta samimiy qarab turgan insonga qarab gapiring.
3. Shoshilmang, so'zlarni dona-dona va pastki qorindan nafas olib ayting.
                    `
                },
                {
                    id: "vaziyat-xatoni-tan-olish",
                    title: "Vaziyat 6: Xato Qilib Qo'yganda Mardlarcha Tan Olish",
                    tag: "Mardlik & Halollik",
                    summary: "Bahona qidirmasdan o'z xatosini bo'yniga olish va vaziyatni tuzatish.",
                    content: `
ICHKI HOLAT TAHLILI:
Inson xato qilganda birinchi bo'lib aybni boshqaga to'nkash yoki yolg'on bilan yopish istagi tug'iladi. Bu qo'rqoqlikdir.

NIMA DEYISH KERAK:
"Ha, bu mening xatoim. Men mas'uliyatni to'liq o'z zimmamga olaman. Buni qanday to'g'rilashim mumkin?"
Bu so'zlarni aytgan inson boshqalarning nazarida pastga tushmaydi, aksincha haqiqiy mard inson sifatida qadrlanadi.
                    `
                },
                {
                    id: "vaziyat-singil-injiqlik",
                    title: "Vaziyat 7: Singling Yoki Ukang Injiqlik Qilganda",
                    tag: "Sabr & Aka Mehr-oqibati",
                    summary: "Urishmasdan, ovoz ko'tarmasdan yo'lga solish siri.",
                    content: `
Kichiklar ko'pincha e'tibor yetishmasligidan yoki charchoqdan injiqlik qilishadi. Agar ularga baqirsangiz yoki ursangiz, ular qo'rqadi, lekin yaxshi bo'lib qolmaydi.

NIMA QILISH KERAK:
1. Ularning bo'yi bilan teng bo'lib o'tiring (ko'z darajasida).
2. Qattiq quchoqlang va: "Bilaman, sen xafasan. Qani menga ayt-chi, nima xohlaysan?" deb so'rang. Mehr ko'rgan bola darhol tinchlanadi.
                    `
                }
            ]
        }
    ]
};

window.TARBIYA_DATA = TARBIYA_DATA;
