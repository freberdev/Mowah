//! The jokes shown in the window, carried over from the original script.

use super::rng::Rng;

pub const JOKES: &[&str] = &[
    "Hur många personer bor det i Tyskland? – Gööör-many",
    "Vad tycker du om Angola? – Det an-gola inte dig!",
    "Vilket djur är världens största? – Eeeen-orm!",
    "Har koncentrationssvårigheterna ökat i Göteborg? – A D H D!",
    "Kan man äta hur mycket som helst här på fiskrestaurangen? – Ja, det är ål inclusive.",
    "Hur många bor det i Stockholm? – En dryg miljon",
    "Var är min fönsterskrapa? – Ingen aning! Den är puts väck!",
    "Vilket land har det billigaste köttet? – Ko-rea!",
    "En brittisk sjökapten har ramlat över bord och ropar på hjälp. Kal till Ada: – Du, han talar ju engelska flytande!",
    "Vem är den lille pojken med hudsalva i ansiktet? Kal: – Det är min korte-son.",
    "En göteborgare frågade Jesus, vad gör du i påsk? – Vet inte, jag har inget spikat.",
    "Är det kul att jobba som frisör? – No, it sax!",
    "Gillar du att se Elitserien i hockey? – Ja, men bara periodvis.",
    "Olja och akvarell gick bra, men när det kom till kritan var han inte så duktig.",
    "Gick det bra med rymdresan? – Nej, den blev uppskjuten.",
    "Att boka dubbelrum i Italien är inte lätt om man heter Uno Persson.",
    "Mötte en arbetslös skådespelare igår. – Vad gör han då? – Spelar ingen roll",
    "Hur tröstar man sin veganska vän? – Soja, soja, ingefära.",
    "Vilken stad bör man besöka om man har många båtar? – Köp-en-hamn",
    "Vad heter Alcazars alkoholiserade coverband? – Alcizar",
    "Varför har man inte sjöjungfrur i Norrland? – Det blir för kallt på fjällen.",
    "I Göteborg försöker man förbättra tandhälsan genom att lyssna på äldre kvinnors råd. – Tantråd.",
    "Vilken Disneyfigur är bäst på att spela tennis? – Sir Väs",
    "Vad hade Zlatan hetat om han var från Göteborg? – Zlatan Ibrahimordvits.",
    "Vad kallas IFK Göteborgs målvakt? – Änglavakt",
    "Vad blir det om man lagar bilen på en söndag? – Söndagsbilaga.",
    "Vad heter Rysslands snabbaste korvstoppare? – Korv-ba´-tjoff.",
    "Vad får man om man kapar benen av en gås? – S, eftersom den inte längre kan gå.",
    "Varför serverar man sniglar på fina restauranger? – Deras gäster tycker inte om snabbmat!",
    "Busschaufförerna har önskemål om toaletter på ändstationerna. – Räcker det inte med hållplatser?",
    "Smörsångare som sällan åker utomlands? – Inrikes Iglesias.",
    "Vilken gata hör man sämst på i Göteborg? – Vasa-gatan? – Nej, Övre Hursa.",
    "Vad äter en spådam en varm sommardag? – Sia Glass.",
    "Varför gick mjölken ut? – Den blev sur.",
    "Jag är nära släkt med en fågelskrämma. – Den är min halmbror.",
    "Vilket är det vanligaste dubbelnamnet i Kenya? – Kenny-Jan.",
    "Hade pengar att placera, startade då en rodeo för att få? – Mycket avkastning.",
    "Vad kallas en optiker man inte kan lita på? – Ögontjänare.",
    "Vad är det för vatten i vattenpass? – Rakvatten.",
    "Min australiske vän kan verkligen allting om vandringsskor. – Han är en riktig kängguru.",
    "De som hjälper folk under pågående vulkanutbrott kan inte ha det lätt. – Nä, det måste vara ett jevla lavarbete!",
    "Vad heter öringynglets mamma och pappa? – Forelldrar.",
    "När är det bäst att äta tacos? – På nachonaldagen.",
    "Varför åkte den högljudde hunden till veterinären? – De misstänkte skallskador.",
    "Vad gör göteborgaren om han fryser? – Går ett varv runt så blir det 360 grader.",
    "Var köper man den billigaste handprotesen? – På second hand.",
    "Vad är det där för blandras som du går omkring med? – Jo, jag hade en ångerfull schäfer som försökte göra en pudel.",
    "Vad säger göteborgaren till ett Star wars fan? – JeeDaaaj.",
    "Vilken är världens mest musikaliska fågel? – Truten, för det är en måsart.",
    "Var lärde sig hajen att simma? – På haj-school.",
    "Den ena hästen sa till den andra: – Jag hörde att du blev kastrerad i går. – Ja, fyfan valack jag blev.",
    "Hur ser man att en bil är från Polen? – På lacken.",
    "Hur ser man att en bil är från Turkiet? – På vindruteturkarna.",
    "Hur ser man att en bil kommer från Spanien? – Växellådan är Manuel.",
    "I vilken stad tar bilköerna aldrig slut? – Konstantinopel.",
    "Han var liten och satt. Sedan reste han sig upp och gick.",
    "Bokmässan är ju helt fantastisk! – Ja, otroligt mångsidig.",
    "När Viktväktarna gör reklam försöker de nå ut till den breda massan.",
    "Vilken barnlek är mest populär i Indien? – Curry-gömma.",
    "Vad blir man när man dricker i smyg? – Hemlighetsfull",
    "Vad är det viktigaste att tänka på när man köper fotbollsskor? – Att dom passar bra",
    "Hur vill grabbarna i ISIS ha sin öl? – Kall-i-fat!",
    "Varför kan en abborre och en mört inte få barn? – För det blir abbört.",
    "Båtmässan borde slås ihop med MC-mässan och byta namn till? – Skepp O'hoj.",
    "Vad heter Finlands sämsta bärplockare? – Maski Hallonen.",
    "Har du hört om kyrkvaktmästaren med koncentrationssvårigheter? – Han hade grav ADHD.",
    "Hur många fakturor har jag blivit av med nu? – Har tappat räkningen igen.",
    "Hörde ni om den skuldsatta dinosaurien? – Levde på krita tydligen.",
    "Vad kallas det när katten missar lådan? – Kissemiss!",
    "Vad får man om man solar med BH? – Vitlökar.",
    "Vad gjorde den pimpelfiskande tjecken när isen frös igen hela tiden? – Han var käck och slo´ vak igen.",
    "Varför gick det så dåligt för Danmark i EM-kvalet? – Kastrup.",
    "Vilken är Påvens favoritglass? – Romrussin.",
    "Vilken typ av kaffe gillar hamnarbetare? – Bryggkaffe.",
    "Vad kallas hästskon i Göteborg? – Gångjärn.",
    "Vad kallas äldreboenden för män i Spanien? – Señior-boende.",
    "Varför läcker det från taket i hårsalongen? – De har drop in.",
    "Varför är det bäst att lifta 12.59? – Då kommer bilarna ett i ett.",
    "Vad säger frisören när du kommer på återbesök? – Är du hair igen?",
    "Jag skulle inte säga att jag är bäst i världen på kurragömma, men det är svårt att hitta någon som är bättre.",
    "Vilken typ av kaffe gillar lantbrukare? – Kokaffe.",
    "Vad kallas de som jobbar extra inom Folktandvården? – Vikaries.",
    "Dom som äter fikon för magens skull kommer ju? – Skita på sig när de upptäcker Microlax.",
    "Vilket träd växer det pengar på? – Plån-boken.",
    "Har du sett filmen om lastbilen? – Nej, men jag har sett trailern.",
    "Varför är det så många rullstolsbundna på golfbanan? – De försöker minska sitt handicap.",
    "Varför köpa dyra guldfiskar när silverfiskar är helt gratis och otroligt lättskötta?",
    "Varför simmar ankorna i hamnen på raka led? – Det är ankring förbjuden!",
];

pub fn pick(rng: &mut Rng) -> &'static str {
    JOKES[rng.range_inclusive(0, JOKES.len() as u64 - 1) as usize]
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn pick_returns_a_joke_from_the_list() {
        let mut rng = Rng::new(3);
        for _ in 0..200 {
            assert!(JOKES.contains(&pick(&mut rng)));
        }
    }

    #[test]
    fn pick_varies_between_calls() {
        let mut rng = Rng::new(3);
        let first = pick(&mut rng);
        assert!((0..50).any(|_| pick(&mut rng) != first));
    }

    #[test]
    fn no_joke_is_empty() {
        assert!(JOKES.iter().all(|j| !j.trim().is_empty()));
    }
}
