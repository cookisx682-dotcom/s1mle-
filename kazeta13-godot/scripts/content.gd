class_name C
extends RefCounted
## Static game data: texts, notes, clues, tape feeds, credits.

const DAYNAME := ["", "Návrat", "Obrazy", "Mäsiar", "Sestra", "Tma", "Je to skutočné?", "Realita"]

const STORY := [
	"Je to 26 rokov, čo tvoja rodina zmizla.",
	"Mama, otec a sestra Lucia. Jednej októbrovej noci v roku 1998 jednoducho prestali existovať. Polícia nenašla nič.",
	"Z celej rodiny zostalo jediné dieťa. {N|Ty}.\nZ tej noci si nepamätáš nič. Iba šum televízora.",
	"Minulý týždeň prišiel balík bez odosielateľa. Kľúč od domu a lístok:\nVRÁŤ SA. KAZETY ŤA ČAKAJÚ.",
	"Dom stojí prázdny. Prúd ide, hoci ho nikto neplatí.\nA v obývačke niekto nechal zapnutý televízor.",
]

const HOWTO := [
	["Dom, ktorý ťa čaká", [
		["V októbri 1998 zmizla tvoja rodina.", "Po 26 rokoch sa vraciaš do domu, kde zostali iba kazety a niečo, čo na teba čakalo."],
		["7 dní", "Každý deň nové kazety, nové hádanky a niečo nové v dome. Keď zomrieš, deň sa začne odznova."],
		["Kazety", "Vlož kazetu do televízora v obývačke a vojdi do obrazu. Niektoré sú spomienky. Niektoré nie. Na štítku to nenájdeš."],
		["Pravda", "Hodiny, zrkadlá, fotky. Všímaj si drobnosti. Nie všetko, čo vyzerá ako realita, ňou aj je."]]],
	["Pravidlá prežitia", [
		["Baterka", "V realite nikdy nesvieť na príšery. Zabijú ťa. V pokrivenom svete je to naopak, svetlo ich odoženie. Baterka sa míňa, hľadaj batérie."],
		["Vypínače", "V niektorých izbách ešte funguje svetlo. Do rozsvietenej izby si netrúfnu. Žiarovky však občas zhasnú."],
		["Schovávanie", "Skrine a priestor pod posteľou. Kým sa skrývaš, počúva mikrofón. Buď ticho."],
		["Život a nôž", "Príšery ti uberajú život. Keď ťa niečo chytí a máš nôž, stlač E a bodni. Nôž vydrží 3 bodnutia."],
		["Únava", "Beh ťa unaví. Spoznáš to podľa ťažkého dychu a rozmazaného obrazu."]]],
	["Kto je v dome", [
		["Hosť", "Vysoký. Ústa až po hruď. Hýbe sa iba vtedy, keď sa naň nepozeráš."],
		["Matka", "Obväz cez oči, dlhé čierne vlasy. Nevidí. Počuje každý krok, beh aj dvere."],
		["Mäsiar", "Železná nádoba na hlave, sekáč v ruke. Vidí aj počuje. Uteč, schovaj sa, alebo bež do svetla."],
		["Sestra", "Porcelánová tvár, čierne slzy. Nepozeraj sa na ňu dlho."],
		["Dvojník", "Vyzerá ako ty. Kráča, keď kráčaš ty. Keď sa na seba pozriete, rozbehne sa. Odvráť zrak."],
		["Hlásateľ", "Televízor namiesto hlavy. Objaví sa tam, kde nič nie je tak, ako má byť."]]],
	["Ovládanie", [
		["W A S D · myš", "pohyb a rozhliadanie"],
		["E", "použiť, schovať sa, bodnúť"],
		["F · Shift · Esc", "baterka · beh · pauza"],
		["Tab · M", "taška a denník · mapa"]]],
]

const NOTES := {
	"n1": ["Denník · 2. október 1998", ["Lucka zase hovorí o pánovi bez tváre. Vraj stojí v rohu izby, keď pozerá kazety.", "Kúpila som jej nové kazety, nech sa upokojí. Ráno som našla všetky v obývačke, popísané číslami. Nikto z nás ich nepopísal.", "— mama"]],
	"n2": ["Nemocnica sv. Michala · lekárska správa", ["Pacient: dieťa, 8 rokov. Úraz elektrickým prúdom pri televíznom prijímači, 14. 10. 1998.", "Stav: kóma. Reakcie na zvuk zachované. Matka žiada púšťať pacientovi domáce videá.", "Prognóza: neistá."]],
	"n3": ["Lístok pod sekáčikom", ["Dnes som ho videl v pivnici. Sekal mäso, ktoré nikto z nás nekúpil.", "Povedal, že je to na večeru. Pre hosťa. Na hlave mal železnú nádobu a ja som nevidel, či pod ňou vôbec niečo je.", "Zamkol som pivnicu. Kľúč som schoval tam, kde čas stojí.", "— otec"]],
	"n4": ["Denník · bez dátumu", ["Lucka by dnes mala deväť rokov.", "Ktorá Lucka? Na fotkách je čoraz menej jej tváre. Na poslednej ju už niekto vyškrabal.", "Keď sa pozerám do zrkadla príliš dlho, za mnou sa smeje."]],
	"n5": ["Lístok tvojím písmom", ["Ak toto čítaš, si stále v kazete.", "Kazety sa nahrávajú samé. Každá noc je nová stopa. Každý deň, ktorý prežiješ, je ďalšia minúta na páske.", "Pravda je na kazete 13. Nepúšťaj ju, kým sa nechceš zobudiť."]],
	"n6": ["Polícia · záznam z obhliadky, 1998", ["Dom prázdny. Rodina nezvestná. V obývačke zapnutý televízor, vo videu kazeta č. 13 s nápisom REALITA.", "Kazetu sa nepodarilo prehrať. Na páske je iba šum a na konci krátky záznam: dieťa, ktoré spí pred televízorom."]],
}

const CLUES := {
	"p1": "Obraz I v obývačke: čierne vtáky na krvavom nebi.",
	"p2": "Obraz II v kuchyni: jablká na tanieri.",
	"p3": "Obraz III na chodbe: torta so sviečkami.",
	"p4": "Obraz IV v detskej izbe: kresba vysokej postavy.",
	"keypad": "Pracovňa: zámok na štyri číslice. „Spočítaj, čo vidíš. I · II · III · IV“",
	"t4": "Kazeta 4: veľké hodiny sa zastavili na 3:15.",
	"drawing": "Detská kresba: poistky. Hore, dole, hore, hore, dole.",
	"photos": "Spálňa: fotky Lucie na komode. Treba ich zoradiť od najmladšej.",
	"mirror": "V zrkadle niekedy nie som. Vtedy to nie je realita.",
	"clock": "Keď hodiny idú dozadu, niečo nie je skutočné.",
	"light": "Rozsvietená izba je bezpečná. Do svetla si netrúfnu.",
	"flux": "Obraz občas preblikne. Potom neviem, kde som. A či smiem svietiť.",
	"sister": "Na dievča s porcelánovou tvárou sa nesmiem dlho pozerať.",
	"zero": "Všetky poznámky spomínajú pásku bez čísla. Kazeta nula. Medzi hračkami?",
	"broken": "Kazeta 13 praskla. Opravím ju náhradnou cievkou a lepiacou páskou na stole v pracovni.",
}

const WHISPERS := ["…{N}…", "…{N}… si tu dvakrát…", "…{N|ty}… počujem ťa…", "…{N}, poď dole…", "…pozri sa za seba…", "…nie si tu sám…",
	"…vráť sa do kazety…", "…on ťa vidí…", "…prečo ma tu necháš?…", "…zlatko, poď dole do pivnice…", "…už je blízko…", "…zhasni to svetlo…",
	"…počujem ťa dýchať…", "…toto nie je tvoj dom…"]

## tape id -> feed: world, camera pos, look-at, lines
const FEEDS := {
	"0": {"world": "t0", "pos": [8.2, 2.1, 6.8], "look": [4.5, 0.6, 1.5], "lines": [["", "14. október 1998, 19:40.", 2.6], ["", "Dieťa sedí príliš blízko pri televízore. Ruky má mokré.", 3.4], ["MAMA", "Zlatko, odstúp od toho!", 2.6]]},
	"1": {"world": "t1", "pos": [15.6, 2.0, 5.6], "look": [12.5, 0.8, 3.6], "lines": [["MAMA", "Sadni si, jedlo vychladne.", 2.6], ["OTEC", "Kto zase nechal otvorenú pivnicu?", 2.8], ["LUCIA", "To nebol on. To bol ten pán.", 3.0]]},
	"2": {"world": "t2", "pos": [15.6, 2.0, 1.0], "look": [12.5, 0.8, 3.8], "lines": [["", "♪ Všetko najlepšie k narodeninám… ♪", 3.0], ["MAMA", "Sfúkni sviečky, {N}.", 2.4], ["", "Na tvojej stoličke niekto sedí.", 3.0]]},
	"3": {"world": "a3", "pos": [9.6, 2.1, 7.5], "look": [20, 1.2, 7.5], "lines": [["???", "Dobrý večer. Vysielame pre vás z vašej obývačky.", 3.4], ["???", "Prosím, nesvietiť. Teda… tam u vás áno.", 3.4]]},
	"4": {"world": "t4", "pos": [8.0, 2.1, 7.4], "look": [5.5, 0.9, 2.0], "lines": [["", "Veľké hodiny odbíjajú. A potom stíchnu.", 3.0], ["MAMA", "Zase stoja. Odkedy prišiel.", 2.8]]},
	"5": {"world": "t5", "pos": [14.3, 2.1, 9.6], "look": [10.2, 0.6, 12.6], "lines": [["", "Detská izba. Noc.", 2.4], ["", "Dieťa sedí na posteli a pozerá do rohu.", 3.0]]},
	"6": {"world": "a6", "pos": [9.6, 2.1, 7.5], "look": [20, 1.2, 7.5], "lines": [["???", "Hľadáme stratené hračky. Odmena: ticho.", 3.2], ["LUCIA", "Hihihi.", 2.0]]},
	"7": {"world": "t7", "pos": [9.6, 2.1, 7.5], "look": [23, 1.2, 7.5], "lines": [["", "21. október 1998, tri hodiny ráno.", 3.0], ["", "Na konci chodby niekto stojí.", 3.0]]},
	"X": {"world": "fake", "live": true, "lines": [["", "Na obrazovke je obývačka. Práve teraz.", 3.0], ["", "To si ty.", 2.6]]},
	"13": {"world": "hosp", "pos": [74.4, 2.2, 5.4], "look": [72.4, 0.7, 2.4], "lines": [["", "Nemocničná izba. Pípanie prístrojov.", 3.0], ["MAMA", "Pozri, {N}. Pustila som ti tvoje kazety.", 3.2], ["MAMA", "Doktor hovorí, že ma možno počuješ.", 3.2]]},
}

const CREDITS := ["KAZETA 13", "", "V hlavných úlohách", "Hosť", "Matka", "Mäsiar", "Sestra", "Hlásateľ", "Dvojník", "", "Rodina", "Mama · Otec · Lucia", "",
	"A {N|ty}, pred televízorom.", "", "Nahraté v októbri 1998.", "Prehrané dnes.", "", "Vyrobené z tónov, šumu a strachu.", "", "Poďakovanie",
	"Ďakujem každému, kto si túto kazetu pustil.", "Ďakujem za odvahu. A za to, že svetlo zostalo svietiť.", "", "Vytvoril: cookisx682", "", "◀◀ Kazeta sa previja…"]

const EGG := {"host": "Hosť", "hosť": "Hosť", "lucia": "Lucia", "lucka": "Lucia", "mama": "Mama", "matka": "Matka", "otec": "Otec", "masiar": "Mäsiar",
	"mäsiar": "Mäsiar", "sestra": "Sestra", "dvojnik": "Dvojník", "dvojník": "Dvojník", "hlasatel": "Hlásateľ", "hlásateľ": "Hlásateľ"}

const DIFF := [{"n": "Ľahká", "dmg": 0.6, "drain": 0.6, "flux": 0.6, "spd": 0.9}, {"n": "Normálna", "dmg": 1.0, "drain": 1.0, "flux": 1.0, "spd": 1.0},
	{"n": "Nočná mora", "dmg": 1.4, "drain": 1.35, "flux": 1.4, "spd": 1.1}]

## reality flux per day
const FLUX := [null, null, {"decoy": 30.0}, {"every": 85.0, "dur": [2.0, 3.5], "vis": 1.0, "decoy": 28.0}, {"every": 70.0, "dur": [3.0, 6.0], "vis": 0.8, "decoy": 24.0},
	{"every": 60.0, "dur": [5.0, 10.0], "vis": 0.6, "decoy": 20.0}, {"every": 55.0, "dur": [4.0, 9.0], "vis": 0.5, "decoy": 16.0}, {"every": 45.0, "dur": [6.0, 14.0], "vis": 0.35, "decoy": 12.0}]

const CHG_N := [0, 0, 1, 2, 2, 2, 3, 3]

const ROOMS := [["living", "Obývačka", 0, 0, 9, 8], ["foyer", "Vstupná hala", 0, 8, 9, 15], ["kitchen", "Kuchyňa", 9, 0, 16, 6], ["study", "Pracovňa", 16, 0, 24, 6],
	["hall", "Chodba", 9, 6, 24, 9], ["kid", "Detská izba", 9, 9, 15, 15], ["bath", "Kúpeľňa", 15, 9, 19, 13], ["stor", "Komora", 15, 13, 19, 15], ["bed", "Spálňa", 19, 9, 24, 15],
	["bstore", "Sklad", 40, 0, 44, 12], ["boiler", "Kotolňa", 44, 0, 54, 5], ["lair", "???", 44, 5, 54, 12]]

const VOICES := {"MAMA": [0.92, 1.15], "OTEC": [0.88, 0.75], "LUCIA": [1.05, 1.6], "DIEŤA": [1.0, 1.5], "HLÁSATEĽ": [1.25, 0.9], "???": [0.72, 0.55], "RODINA": [0.85, 1.1]}
