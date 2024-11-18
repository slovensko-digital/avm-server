# AVM (Autogram v mobile) Server

Ruby on Rails REST API server pre aplikáciu [Autogram v mobile](https://github.com/slovensko-digital/avm-app-flutter). Link na swagger [API dokumentáciu](https://autogram.slovensko.digital/api/v1).

[Autogram v mobile](https://sluzby.slovensko.digital/autogram-v-mobile/) vytvorili freevision s.r.o., Služby Slovensko.Digital s.r.o. a dobrovoľníci pod EUPL-1.2 licenciou. Prevádzkovateľom je Služby Slovensko.Digital s.r.o.. Prípadné issues riešime v [GitHub projekte](https://github.com/orgs/slovensko-digital/projects/5) alebo rovno v tomto repozitári. Java komponent [AVM service](https://github.com/slovensko-digital/avm-service) je z veľkej časti vyrobený podľa projektu [Autogram](https://github.com/slovensko-digital/autogram), ktorého autormi sú Jakub Ďuraš, Solver IT s.r.o., Slovensko.Digital, CRYSTAL CONSULTING, s.r.o. a ďalší spoluautori.

Projekt sa skladá z viacerých častí:
- **Server**
  - [AVM server](https://github.com/slovensko-digital/avm-server) - Ruby on Rails API server poskytujúci funkcionalitu zdieľania a podpisovania dokumentov.
  - [AVM service](https://github.com/slovensko-digital/avm-service) - Java microservice využívajúci Digital Signature Service knižnicu pre elektronické podpisovanie a generovanie vizualizácie dokumentov.
- **Mobilná aplikácia**
  - [AVM app Flutter](https://github.com/slovensko-digital/avm-app-flutter) - Flutter aplikácia pre iOS a Android.
  - [AVM client Dart](https://github.com/slovensko-digital/avm-client-dart) - Dart API klient pre komunikáciu s AVM serverom.
  - [eID mSDK Flutter](https://github.com/slovensko-digital/eidmsdk-flutter) - Flutter wrapper "štátneho" [eID mSDK](https://github.com/eIDmSDK) pre komunikáciu s občianskym preukazom.
- [**Autogram extension**](https://github.com/slovensko-digital/autogram-extension) - Rozšírenie do prehliadača, ktoré umožňuje podpisovanie priamo na štátnych portáloch.


## Ako si to rozbehnúť

### Development prostredie

- Je potrebné si nainštalovať správnu verziu Ruby. To sa najlepšie robí cez [RVM](https://rvm.io/) alebo [Rbenv](https://github.com/rbenv/rbenv).
- Aplikácia vyžaduje PostgreSQL databázu.
- Skopírovať `.env.sample` do `.env` a nastaviť hodnoty.
- Spustiť [avm-service](https://github.com/slovensko-digital/avm-service).
- Následne v adresári repozitára spustiť:
```
bundle install
bundle exec rails db:setup
bundle esec rails s
```

### Produkčné nasadenie v kontajneri

- Je potrebné si vybuildiť Docker image na základe poskytnutého Dockerfile.
- Volume pre šifrované ukladanie podpisovaných súborov v `/app/storage`
- Premenné prosredia sú bližšie popísané v `.env.sample`, pričom tieto sú nevyhnutné pre produkčné nasadenie:
  - PostgreSQL a connection string v `DATABASE_URL`
  - Adresa [AVM Service](https://github.com/slovensko-digital/avm-service) inštnacie v `AVM_MICROSERVICE_HOST`
  - Nastavené ENVs `ACTIVE_RECORD_ENCRYPTION_*`
  - Nastavený ENV `SECRET_KEY_BASE`
  - Nastavený ENV `RAILS_ENV=production`


## Architektúra riešenia

### Architektúra servera

Okrem tohto Rails API sa na serveri nachádza ešte Java microservice [avm-service](https://github.com/slovensko-digital/avm-service), ktorý sa aj s [Digital Signature Service knižnicou](https://github.com/esig/dss) stará o samotné podpisovanie dokumentov a ich prípadné zobrazovanie (ak ide napríklad o XML formulár).

AVM server ukladá dokumenty na disk zašifrované kľúčom poskytnutým klientom (či už integráciou alebo priamo aplikáciu z telefónu). Server si kľúč nepamätá, klient ho musí poslať v každom requeste manipulujúcom s dokumentom. Tým pádom je chránené súkromie používateľa, aj keby došlo k úniku dát z disku. Dokument sa maže z disku 24 hodín po jeho vytvorení.

Klient posiela pri vytváraní dokumentu rovnu už aj podpisové parametre, podľa ktorých má byť neskôr vyrobený podpis. Tie sa ukladajú v databáze a spravidla neobsahujú citlivé informácie.

![AVM server archutektúra](https://github.com/slovensko-digital/avm-server/assets/12500066/5936a336-a2d1-41f7-9347-fc050625d08a)

Po vytvorení dokumentu ho môže podpísať každý, kto pozná jeho GUID a šifrovací kľúč. Klient najprv zavolá `POST /datatosign`, aby dostal zo servera reťazec na podpísanie, podpíše dokument u seba a následne zavolá `POST /sign` aj s podpísanou hodnotou. AVM service na základe týchto dát a dokumentu vytvorí podpísaný dokument a vráti ho klientovi. Vtedy sa zmení aj atribút dokumentu `last_signed_at`.
Pri podpisovaní z externého systému sa musí integrácia dopytovať na zmenu podpísaného súboru, aby tak zistila, kedy bol súbor podpísaný používateľom - neexistuje iný automatizovaný spôsob, ako to zistiť.

Ak chce integrácia alebo zariadenie iniciovať podpisovanie cez PUSH notifikácie, musí sa najprv zaregistrovať na serveri aj s verejnou časťou ES256 kľúča, ktorý môžu neskôr používať na pridávanie a odoberanie spárovaných zariadení a integrácií. Notifikácie fungujú cez Firebase Cloud Messaging, takže zariadenie musí serveru poslať aj svoje `registration_id`. Notifikácie sú šifrované. zariadenie teda musí serveru zaslať symetrický kľúč, ktorým bude server šifrovať jeho notifikácie (šifrujeme až na serveri, aby bola integrácia jednoduchšia).
Párovanie vykonáva vždy zariadenie. Na server do `POST /device-integrations` musí poslať `integrationPairingToken`, ktorý získa iným kanálom od integrácie (napríklad už spomínaným QR kódom). Tento token je JWT podpísané kľúčom integrácie s nastaveným claimom `aud: "device"`, aby ho nebolo možné použiť na iný účel než párovanie.


### Architektúra celého riešenia pri podpisovaní súboru z telefónu

V prípade, že používateľ vyberie súbor na podpis zo zariadenia (telefónu) alebo priamo v aplikácii, celá architektúra je o niečo jednoduchšia. Zariadenie pošle dokument s parametrami na server a zapamätá si kľúč a GUID dokumentu. Následne si vypýta vizualizáciu dokumentu, ktorú zobrazí používateľovi. Ak chce používateľ dokument podpísať, zariadenie pošle na server podpisový certifikát a server mu vráti `dataToSign` string, ktorý zariadenie a používateľ podpíšu. Výsledok tejto operácie pošle zariadenie opäť na server, ktorý to spojí s pôvodným dokumentom a vráti zariadeniu podpísaný súbor.

![avm-arch](https://github.com/slovensko-digital/avm-server/assets/12500066/1f5a3098-288c-467b-9d09-2acc44dcf796)

#### API Flow

1. Používateľ si v telefóne vyberie súbor, ktorý chce podpísať (či už cez file explorer, priamo z AVM alebo cez share button z inej aplikácie)
2. AVM pošle súbor + podpisové parametre na server endpoint `POST /api/v1/documents`.
   - Zasiela sa tam súbor + parametre + encryptionKey (symetrický, pre každý dokument sa generuje nový)
3. Server tento subor zašifruje, uloží a zabudne encryptionKey. V odpovedi vráti GUID dokumentu.
4. AVM zavolá `GET /api/v1/documents/<guid>/visualization`.
   - Zasiela sa opäť encryptionKey (!) pre tento dokument
5. Server dostane encryptionKey, lokálne dešifruje dokument, vyrobí jeho vizualizáciu (HTML/PDF) (v Java microservice v osobitnom kontajneri), a vracia ju AVM.
6. AVM zobrazí používateľovi dokument,
7. AVM zavolá `POST /api/v1/documents/<guid>/datatosign`
   - Zasiela sa opäť encryptionKey (!) pre tento dokument a tiež certifikát podpisujúceho.
   - Tu sa dá poslať ešte optional parameter “addTimestamp: bool”, ktorý prípadne zmení typ podpisu na “s/bez pečiatky”.
8. Server dostane encryptionKey, lokálne dešifruje dokument, zavolá DSS knižnicu (v Java microservice v osobitnom kontajneri), vytvorí údaje potrebné pre podpisovanie (datatosign) a zasiela AVM
9. AVM vyvolá podpisovanie (datatosign) a ziska podpísané dáta z eID SDK (občianskemu preukazu sa pošle datatosign, používateľ zadá kódy a karta vráti podpísaný string - tento flow rieši SDK od MV aj obrazovkami)
10. AVM zasiela podpísane dáta (signedData) na server `POST /api/v1/documents/<guid>/sign`
    - Posiela sa encryptionKey + pôvodné dataToSign (aby server zistil, či sa medzitým nezmenili) + signedData
11. Server vytvori podpísaný kontajner a zasiela ho naspäť AVM
12. Dokument sa prepíše v úložisku (zašifrovaný)
13. AVM alebo prípadná integrácia vie zavolať `GET /api/v1/documents/<guid>` na podpísaný súbor s encryptionKey a dostať ho.
14. Server súbor po 24h zmaže.


### Architektúra celého riešenia pri podpisovaní súboru zo štátneho portálu

V prípade, že má používateľ nainštalované rozšírenie `Autogram na štátnych weboch` ([Autogram extension](https://github.com/slovensko-digital/autogram-extension)), stačí, že priamo na slovensko.sk, financnasprava.sk alebo na ďalších portáloch vyberie `podpísať`. Zobrazí sa mu dialóg Autogram extension, kde má na výber podpisovanie cez Autogram lokálne v počítači alebo možnosť `podpísať mobilom`. Pri podpise mobilom Autogram extension nahrá podpisovaný dokument (formulár alebo príloha podania) na server a používateľovi zobrazí QR kód s GUID dokumentu a encryptionKey. Používateľ naskenuje QR kód telefónom a v aplikácii `Autogram v mobile` sa mu otvorí podpisovaný dokument. Ten podpíše rovnako ako v predchádzajúcom prípade. Autogram extension medzitým polluje na `GET /documents/<GUID>`. Keď je dokument podpísaný, polling je úspešný a Autogram extension si stiahne zo servera podpísaný dokument, ktorý potom vráti štátnemu portálu.

![avm-arch-ext](https://github.com/slovensko-digital/avm-server/assets/12500066/d2a38b12-5600-4659-8473-3e4a66b9494c)

#### API Flow

1. Extension pošle súbor + podpisové parametre na server endpoint `POST /api/v1/documents`.
   - Zasiela sa tam súbor + parametre + encryptionKey (symetrický, pre každý dokument sa generuje nový)
2. Server tento subor zašifruje, uloží a zabudne encryptionKey. V odpovedi vráti GUID dokumentu.
3. Extension poskytne iným kanálom (napríklad QR kódom na obrazovke) aplikácii `GUID` a `encryptionKey` dokumentu.
   - Konkrétne náš Autogram extension a aplikácia podporujú link v tvare: `https://<server-hostname>/api/v1/qr-code?guid=<guid>&key=<encryptionKey>`
4. Aplikácia získa z linku `GUID` a `encryptionKey` dokumentu a zavolá `GET /api/v1/documents/<guid>/visualization`.
5. Ďalej pokračuje rovnaký flow ako v prvom prípade.
6. ...
7. Autogram extension polluje `GET /api/v1/documents/<guid>` s `If-Modified-Since` headerom.
   - ak sa súbor zmenil od času jeho vytvorenia, znamená to, že je podpísaný
8. Autogram extension dostane z `GET /api/v1/documents/<guid>` podpísaný súbor.
9. Autogram extension poskytne podpísaný súbor štátnemu portálu, na ktorom používateľ podpisuje dokument.
10. Server súbor po 24h zmaže.



