# Mowah

Mowah håller Teams och liknande program "online" och hindrar datorn från att gå i viloläge eller låsa sig, utan att störa när du sitter och arbetar. Det är en fristående Windows-app på ungefär 400 kB som inte kräver någon installation eller runtime.

![Mowahs ikoner](res/icon-preview.png)

## Så fungerar den

Mowah gör ingenting så länge du själv rör mus eller tangentbord. Först när du har varit inaktiv en stund (60 sekunder som standard) skapar den lite aktivitet, och upprepar det med slumpat mellanrum tills du är tillbaka.

| Inställning | Vad den gör |
|---|---|
| Metod | **Osynlig musknuff** flyttar pekaren en pixel och tillbaka. **Synlig musrörelse** ritar en cirkel med pekaren under en till två sekunder, och avbryts om du tar musen. **Tangenten F15** trycker på en tangent som inga vanliga tangentbord har. |
| Cirkelns storlek | Hur stor cirkel den synliga musrörelsen ritar, 20–1000 pixlar (300 som standard). Måttet gäller vid 100 % skärmskalning och skalas upp på högupplösta skärmar. Fältet är bara aktivt när metoden är "Synlig musrörelse". |
| Kör när inaktiv i | Hur länge du ska ha varit borta innan Mowah börjar (5–240 sekunder). |
| Upprepa var | Kortaste och längsta tid mellan åtgärderna (5–240 sekunder). Tiden slumpas inom intervallet. |
| Vänsterklicka också | Klickar där pekaren står efter varje åtgärd. Avstängt från start, eftersom ett klick kan träffa något du inte tänkt. |
| Förhindra viloläge | Ber Windows att inte försätta datorn i viloläge. |
| Förhindra att skärmen släcks | Ber Windows att hålla skärmen tänd. |
| Bara mån–fre mellan | Mowah vilar utanför de här tiderna, så att du blir "borta" och datorn får sova efter arbetstid. |
| Starta med Windows | Lägger till Mowah under din användares autostart. Den startar då direkt i systemfältet. |
| Starta minimerad i systemfältet | Visar inget fönster när du startar Mowah själv. |
| Stäng-knappen minimerar till systemfältet | Stäng och Esc gömmer fönstret i stället för att avsluta. |

Tiderna går inte att sätta högre än 240 sekunder, eftersom Teams markerar dig som borta efter fem minuter.

Mowah vilar också när datorn är låst. Viloläge förhindras fortfarande då, men skärmen får släckas.

## Systemfältet

Ikonen är färgad när Mowah är aktiv och grå när den är pausad eller vilar. Vänsterklick öppnar fönstret. Högerklick ger en meny med Öppna, Pausa, Pausa i 1 timme och Avsluta.

Windows 11 gömmer nya ikoner bakom pilen i systemfältet. Dra ut Mowah-ikonen därifrån om du vill se den hela tiden.

Det körs bara en Mowah åt gången. Startar du programmet igen lyfts det befintliga fönstret fram.

## Bygga

På macOS eller Linux, med `rustup` och `mingw-w64` installerade:

```bash
rustup target add x86_64-pc-windows-gnu
./build.sh
```

Resultatet hamnar i `dist/Mowah.exe`.

På Windows, med Rust installerat:

```powershell
cargo build --release
```

Resultatet hamnar i `target\release\mowah.exe`.

Tester av logiken (när Mowah ska agera, inställningar, schema) körs på vilket system som helst:

```bash
cargo test
```

Ikonerna ritas av `tools/make_icons.py` (kräver Pillow) och sparas i `res/`.

## Släppa en ny version

GitHub bygger `Mowah.exe` och lägger upp den som en Release när en versionstagg pushas. Vanliga pushar till `main` bygger ingenting.

1. Ändra versionsnumret i `Cargo.toml` (`version = "1.0.1"`) och på de fyra ställena i `res/mowah.rc` (`FILEVERSION`, `PRODUCTVERSION` och de två `VALUE`-raderna). Kör `cargo build` en gång så att `Cargo.lock` följer med.
2. Committa och pusha till `main`.
3. Tagga och pusha taggen:

```bash
git tag v1.0.1
```

```bash
git push origin v1.0.1
```

Taggen måste vara versionen i `Cargo.toml` med ett `v` framför, annars avbryts bygget. Arbetsflödet finns i `.github/workflows/release.yml`. Det kör testerna, bygger med samma `build.sh` som ovan och bifogar filen till releasen.

## Var saker sparas

- Inställningar: `%APPDATA%\Mowah\settings.ini`
- Autostart: värdet `Mowah` under `HKEY_CURRENT_USER\Software\Microsoft\Windows\CurrentVersion\Run`

Avmarkera "Starta med Windows" innan du tar bort programmet, så försvinner autostarten. Mappen `%APPDATA%\Mowah` kan du sedan radera för hand.

## Antivirus och signering

Mowah begär inga administratörsrättigheter, installerar inga tangentbords- eller mushookar, och innehåller ingen packad eller dold kod. Filen är däremot inte signerad, vilket betyder två saker:

- Laddas den ner från nätet kan Windows SmartScreen varna för "okänd utgivare". En fil du byggt själv eller kopierat över direkt får normalt inte den varningen.
- Antivirusprogram kan i sällsynta fall flagga osignerade program felaktigt. Kodsignering med ett företagscertifikat är det som löser det på riktigt.

På en arbetsdator med låst programpolicy kan osignerade program vara blockerade oavsett.

Klick och tangenttryck från Mowah når inte program som körs som administratör. Windows tillåter inte det för vanliga program.

## Kodens upplägg

- `src/core/` – logiken utan Windows-anrop: motorn som avgör när något ska göras, inställningar, schema, texter. Allt här har tester.
- `src/win/` – fönstret, systemfältsikonen, timern och anropen till Windows.
- `res/` – ikoner, manifest och fönstrets layout (`mowah.rc`).
