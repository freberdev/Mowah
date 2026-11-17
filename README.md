# Mowah

Mowah håller Teams och liknande program "online" och hindrar datorn från att gå i viloläge eller låsa sig, utan att störa när du sitter och arbetar. Den finns för Windows och för Mac.

![Mowahs ikoner](windows/res/icon-preview.png)

| | Windows | Mac |
|---|---|---|
| Fil | `Mowah.exe`, ungefär 400 kB | `Mowah.app`, i `Mowah.dmg` |
| Kräver | Windows 10 eller 11 | macOS 14 eller nyare, Apple-processor eller Intel |
| Ligger i | systemfältet | menyraden |
| Språk | svenska | svenska och engelska, efter Macens språk |
| Kod | `windows/`, Rust | `macos/`, Swift |

Ingen av dem har något installationsprogram.

## Så fungerar den

Mowah gör ingenting så länge du själv rör mus eller tangentbord. Först när du har varit inaktiv en stund (60 sekunder som standard) skapar den lite aktivitet, och upprepar det med slumpat mellanrum tills du är tillbaka.

| Inställning | Vad den gör |
|---|---|
| Metod | Hur aktiviteten skapas, se nedan. |
| Cirkelns storlek | Hur stor cirkel den synliga musrörelsen ritar, 20–1000 pixlar (300 som standard). Måttet skalas med skärmens upplösning. Fältet är bara aktivt för den synliga musrörelsen. |
| Kör när inaktiv i | Hur länge du ska ha varit borta innan Mowah börjar (5–240 sekunder). |
| Upprepa var | Kortaste och längsta tid mellan åtgärderna (5–240 sekunder). Tiden slumpas inom intervallet. |
| Vänsterklicka också | Klickar där pekaren står efter varje åtgärd. Avstängt från start, eftersom ett klick kan träffa något du inte tänkt. |
| Förhindra viloläge | Ber systemet att inte försätta datorn i viloläge. |
| Förhindra att skärmen släcks | Ber systemet att hålla skärmen tänd. |
| Bara mån–fre mellan | Mowah vilar utanför de här tiderna, så att du blir "borta" och datorn får sova efter arbetstid. |
| Starta med Windows / Starta vid inloggning | Startar Mowah när du loggar in. |

Metoderna:

| Metod | Windows | Mac |
|---|---|---|
| Osynlig | Pekaren flyttas en pixel och tillbaka. | En mushändelse på pekarens plats. Inget rör sig. |
| Synlig musrörelse | Pekaren ritar en cirkel under en till två sekunder, och avbryts om du tar musen. | Samma. |
| Tangent | F15, som inga vanliga tangentbord har. | En tangentbordshändelse som inte skriver något. En riktig tangent skulle hamna i programmet som ligger överst. |

Tiderna går inte att sätta högre än 240 sekunder, eftersom Teams markerar dig som borta efter fem minuter.

Mowah vilar också när datorn är låst. Viloläge förhindras fortfarande då, men skärmen får släckas.

Windows-versionen har två inställningar till: "Starta minimerad i systemfältet" och "Stäng-knappen minimerar till systemfältet". Mac-versionen har inget huvudfönster och behöver dem inte.

## Windows

Ikonen i systemfältet är färgad när Mowah är aktiv och grå när den är pausad eller vilar. Vänsterklick öppnar fönstret. Högerklick ger en meny med Öppna, Pausa, Pausa i 1 timme och Avsluta.

Windows 11 gömmer nya ikoner bakom pilen i systemfältet. Dra ut Mowah-ikonen därifrån om du vill se den hela tiden.

Det körs bara en Mowah åt gången. Startar du programmet igen lyfts det befintliga fönstret fram.

- Inställningar: `%APPDATA%\Mowah\settings.ini`
- Autostart: värdet `Mowah` under `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`

Avmarkera "Starta med Windows" innan du tar bort programmet, så försvinner autostarten. Mappen `%APPDATA%\Mowah` kan du sedan radera för hand.

Klick och tangenttryck från Mowah når inte program som körs som administratör. Windows tillåter inte det för vanliga program.

## Mac

Öppna `Mowah.dmg` och dra `Mowah.app` till mappen Program innan du startar den. En app som körs direkt ur skivavbilden eller ur Hämtade filer startas av macOS från en tillfällig plats, och då kan varken behörigheten eller starten vid inloggning hitta tillbaka till den.

Mowah syns som en pekare i menyraden, utan ikon i Dock. Pekaren är tydlig när Mowah är aktiv, svagare när den är pausad eller vilar, och har en prick när den behöver din hjälp. Menyn visar statusen och har Pausa, Pausa i 1 timme, Inställningar och Avsluta.

**Behörigheten Hjälpmedel krävs.** macOS låter inget program skapa mus- eller tangentaktivitet utan den. Första gången öppnas inställningsfönstret med en knapp som visar systemets fråga. Slå sedan på Mowah under Integritet och säkerhet › Hjälpmedel i Systeminställningar. Utan behörigheten kan Mowah hålla Macen vaken, men inte hålla dig "online".

- Inställningar: appens egna inställningar hos macOS, `com.freberdev.mowah`
- Start vid inloggning: syns under Allmänt › Inloggningsobjekt i Systeminställningar

## Bygga

Windows-appen, på macOS eller Linux med `rustup` och `mingw-w64` installerade:

```bash
rustup target add x86_64-pc-windows-gnu
windows/build.sh
```

Resultatet hamnar i `dist/Mowah.exe`. På Windows går det också att köra `cargo build --release` i mappen `windows`.

Mac-appen, på en Mac med Xcode och XcodeGen:

```bash
macos/build.sh
```

Resultatet hamnar i `dist/Mowah.dmg`. Xcode-projektet skapas från `macos/project.yml` och ligger inte i git.

Tester av logiken, det vill säga när Mowah ska agera, inställningarna och schemat:

```bash
cd windows && cargo test
```

```bash
cd macos/MowahCore && swift test
```

Att alla Mac-appens texter finns på båda språken kontrolleras med:

```bash
python3 tools/check_strings.py
```

Ikonerna ritas av `tools/make_icons.py` (kräver Pillow), för båda apparna.

## Släppa en ny version

Ändra först versionsnumret i `windows/Cargo.toml` (`version = "1.1.1"`) och kör `cargo build` där en gång så att `Cargo.lock` följer med. Båda apparna hämtar versionen därifrån. Committa och pusha till `main`.

**Med signerad Mac-app.** Bygg båda filerna på en Mac som har Developer ID-certifikatet och uppgifterna för notarisering i nyckelringen, och ladda upp dem:

```bash
windows/build.sh
```

```bash
MOWAH_SIGN_IDENTITY="Developer ID Application: Namn (TEAMID)" macos/release.sh
```

```bash
gh release create v1.1.1 dist/Mowah.exe dist/Mowah.dmg --title "Mowah v1.1.1" --generate-notes
```

`macos/release.sh` signerar appen och skivavbilden, skickar dem till Apple för godkännande och fäster godkännandet vid båda. `gh release create` skapar taggen och releasen i ett steg.

**Utan signering.** Pusha bara en tagg, så bygger GitHub båda apparna och lägger upp dem. Mac-appen är då bara signerad för att kunna köras lokalt.

```bash
git tag v1.1.1
```

```bash
git push origin v1.1.1
```

Taggen måste vara versionen i `windows/Cargo.toml` med ett `v` framför, annars avbryts bygget. Arbetsflödet finns i `.github/workflows/release.yml`. Finns det redan en release för taggen, som efter `gh release create`, bygger det ingenting.

## Signering

Mac-appen kan signeras med ett Developer ID. Windows-appen är inte signerad med något utgivarcertifikat.

**Windows.** Mowah begär inga administratörsrättigheter, installerar inga tangentbords- eller mushookar, och innehåller ingen packad eller dold kod. Laddas filen ner från nätet kan Windows SmartScreen ändå varna för "okänd utgivare". En fil du byggt själv eller kopierat över direkt får normalt inte den varningen. På en arbetsdator med låst programpolicy kan osignerade program vara blockerade oavsett.

**Mac.** En app som är byggd med `macos/release.sh` är signerad med ett Developer ID och godkänd av Apple, och öppnas utan varning. En app som GitHub har byggt från en tagg, eller som är byggd med `macos/build.sh` utan certifikat, är bara signerad för att kunna köras lokalt. Det betyder:

- En nedladdad app stoppas första gången. Godkänn den under Integritet och säkerhet i Systeminställningar.
- Behörigheten Hjälpmedel hör till den exakta filen. Efter en ny version kan den behöva tas bort ur listan och ges på nytt.

`macos/build.sh` signerar med den identitet som står i miljövariabeln `MOWAH_SIGN_IDENTITY`.

Den som bygger själv kan slippa den andra punkten genom att skriva namnet på sitt eget utvecklarcertifikat på första raden i filen `macos/signing-identity.local`, som inte ligger i git. macOS känner då igen appen på certifikatet i stället för på den exakta filen, och behörigheten ligger kvar mellan byggen. En sådan app är till för den egna Macen och ska inte delas ut.

## Kodens upplägg

- `windows/src/core/` och `macos/MowahCore/` – logiken utan systemanrop: motorn som avgör när något ska göras, inställningar och schema. Det är samma logik i två språk, och allt här har tester.
- `windows/src/win/` – fönstret, systemfältsikonen, timern och anropen till Windows.
- `windows/res/` – ikoner, manifest och fönstrets layout (`mowah.rc`).
- `macos/Mowah/` – menyraden, inställningsfönstret och anropen till macOS. Texterna ligger i `Resources/Localizable.xcstrings`.
- `tools/` – skripten för ikoner, texter och versionskontroll.

## Licens

Mowah har MIT-licens. Hela texten står i [LICENSE](LICENSE).
