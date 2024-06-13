# AVM Server

Ruby on Rails REST API server pre aplikáciu [Autogram v mobile](https://github.com/slovensko-digital/avm-app-flutter). Link na swagger [API dokumentáciu](https://autogram.slovensko.digital/api/v1).

[Autogram v mobile](https://sluzby.slovensko.digital/autogram-v-mobile/) je vztvorený a spravovaný freevision s.r.o., Slovensko.Digital a dobrovoľníkmi pod EUPL-1.2 licenciou. Prípadné issues riešime v [GitHub projekte](https://github.com/orgs/slovensko-digital/projects/5) alebo rovno v tomto repozitári.

## Ako si to rozbehnúť

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


## Architektúra servera

![AVM server archutektúra](https://github.com/slovensko-digital/avm-server/assets/12500066/5936a336-a2d1-41f7-9347-fc050625d08a)

Okrem tohto Rails API sa na serveri nachádza ešte Java microservice [avm-service](https://github.com/slovensko-digital/avm-service), ktorý sa aj s [Digital Signature Service knižnicou](https://github.com/esig/dss) stará o samotné podpsiovanie dokumentov a ich prípadné zobrazovanie (ak ide napríklad o XML formulár).

AVM server ukladá dokumnety na disk zašifrované kľúčom poskytnutým klientom (či už integráciou alebo priamo aplikáciu z telefónu). Server si kľúč nepamätá, klient ho musí poslať v každom requeste manipulujúcom s dokumentom. Tým pádom je ochránené súkromie používeteľa, aj keby došlo k nejakému úniku dát z disku. Dokument sa maže z disku 24 hodín po jeho vytvorení.

Klient posiela pri vytváraní dokumentu rovnu už aj dpisové parametre, podľa ktorých má byť neskôr vyrobený podpis. Tie sa ukladajú v databáze a spravidla neobsahujú citlivé informácie.

Po vytvorení dokumentu ho môže podpísať každý, kto pozná jeho GUID a šifrovací kľúč. Klient najprv zavolá `POST /datatosign`, aby dostal zo servera reťazec na podpísanie, podpíše dokument u seba a následne zavolá `POST /sign` aj s podpísanou hodnotou. AVM service na základe týchto dát a dokumentu vytvorí podpísaný dokument a vráti ho klientovi. Vtedy sa zmení aj atribút dokumentu `last_signed_at`.
Pri podpisovaní z externého systému sa musí integrícia dopytovať na zmenu podpísaného súboru, aby tak zistila, kedy bol súbor podpísaný používateľom - neexistuje iný automatizovaný spôsob, ako to zistiť.

Ak chce integrácia alebo zariadenie iniciovať podpisovanie cez PUSH notifikácie, musí sa najprv zaregistrovať na serveri aj s verejnou časťou ES256 kľúča, ktorý môžu neskôr používať na pridávanie a odoberanie spárovaných zariadení a integrácií. Notifikácie fungujú cez Firebase Cloud Messaging, takže zariadenie musí serveru poslať aj svoje `registration_id`. Notifikácie sú šifrované. Integrácie teda musí serveri zaslať symetrikcý kľúč, ktorým bude server šifrovať jeho notifikácie (šifrujeme až na serveri, aby bola integrácia jednoduchšia). Tento kľúč musí integrácia v momente párovania nejakým spôsobom podať zariadeniu (Autogram extension to ukazuje v QR kóde/URL, ktorý sníma aplikácia AVM), aby to mohlo notifikácie od danej integrácie dešifrovať.
Párovanie vykonáva vždy zariadenie. Na server do `POST /device-integrations` musí poslať `integrationPairingToken`, ktorý získa iným kanálom od integrácie (napríklad už spomínaným QR kódom). Tento token je JWT podpísané kľúčom integrácie s nastaveným claimom `aud: "device"`, aby ho nebolo možné použiť na iný účel než párovanie.


## Architektúra celého riešenia pri podpisovaní súboru z telefónu

V prípade, že používateľ vyberie súbor na podpis zo zariadenia (telefónu) alebo priamo v aplikácii, celá architektúra je o niečo jednoduchšia. Zariadenie pošle dokument s parametrami na server a zapmätá si kľúč a GUID dokumentu. Následne si vypýta vizualizáciu dokumentu, ktorú zobrazí používateľovi. Ak chce používateľ dokument podpísať, zariadenie pošle na server podpisový certifikát a server mu vráti `dataToSign` string, ktorý zariadenie a používateľ podpíšu. Výsledok tejto operácie pošle zariadenie opäť na server, ktorý to spojí s pôvodnym dokumentom a vráti zaraideniu podpísaný súbor.

![avm-arch](https://github.com/slovensko-digital/avm-server/assets/12500066/1f5a3098-288c-467b-9d09-2acc44dcf796)

### API Flow

1. Používateľ si v telefóne vyberie súbor, ktorý chce podpísať (či už cez file explorer, priamo z AVM alebo cez share button z inej aplikácie)
1. AVM pošle súbor + podpisové parametre na server endpoint POST /api/documents
1. Zasiela sa tam súbor + parametre + encryptionKey (symetrický, pre každý dokument sa generuje nový)
1. Server tento subor zašifruje, uloží a zabudne encryptionKey. V odpovedi vráti GUID dokumentu.
1. AVM zavolá GET /api/doucmnets/<guid>/visualization.
1. Zasiela sa opäť encryptionKey (!) pre tento dokument
1. Server dostane encryptionKey, lokálne dešifruje dokument, vyrobí jeho vizualizáciu (HTML/PDF) (v Java microservice v osobitnom kontajneri), a vracia ju AVM.
1. AVM zobrazí používateľovi dokument,
1. AVM zavolá POST /api/documents /<guid>/datatosign
1. Zasiela sa opäť encryptionKey (!) pre tento dokument a tiež certifikát podpisujúceho.
1. Tu sa dá poslať ešte optional parameter “addTimestamp: bool”, ktorý prípadne zmení typ podpisu na “s/bez pečiatky”.
1. Server dostane encryptionKey, lokálne dešifruje dokument, zavolá DSS knižnicu (v Java microservice v osobitnom kontajneri), vytvori údaje potrebne pre podpisovanie (datatosign) a zasiela AVM
1. AVM vyvolá podpisovanie (datatosign) a ziska podpísané dáta z eID SDK (občianskemu preukazu sa pošle datatosign, používateľ zadá kódy a karta vráti podpísaný string - tento flow rieši SDK od MV aj obrazovkami)
1. AVM zasiela podpísane dáta (signedData) na server POST /api/documents/<guid>/sign
1. Posiela sa encryptionKey + pôvodné dataToSign (aby server zistil, či sa medzitým nezmenili) + signedData
1. Server vytvori podpísaný kontajner a zasiela ho naspäť AVM
1. Dokument sa prepíše v úložisku (zašifrovaný)
1. AVM alebo prípadná integrácia vie zavolať GET na podpísaný súbor s encryptionKey a dostať ho.
1. Server súbor po 24h zmaže.


## Architektúra celého riešenia pri podpisovaní súboru zo štátnaho portálu

![avm-arch-ext](https://github.com/slovensko-digital/avm-server/assets/12500066/d2a38b12-5600-4659-8473-3e4a66b9494c)

### API Flow




