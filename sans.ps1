Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

Add-Type @"
using System;
using System.Runtime.InteropServices;
using System.Text;
using System.Collections.Generic;
public class Win32 {
    [DllImport("user32.dll")]
    public static extern IntPtr FindWindow(string lpClassName, string lpWindowName);
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll", CharSet=CharSet.Auto)]
    public static extern int GetClassName(IntPtr hWnd, StringBuilder lpString, int nMaxCount);
    [DllImport("user32.dll")]
    public static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint lpdwProcessId);
    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT lpRect);
    [DllImport("user32.dll")]
    public static extern bool IsWindow(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern bool IsWindowVisible(IntPtr hWnd);
    [DllImport("user32.dll")]
    public static extern void mouse_event(uint dwFlags, uint dx, uint dy, uint cButtons, uint dwExtraInfo);
    public delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
    [DllImport("user32.dll")]
    public static extern bool EnumWindows(EnumWindowsProc enumProc, IntPtr lParam);
    public const uint MOUSEEVENTF_LEFTDOWN = 0x02;
    public const uint MOUSEEVENTF_LEFTUP = 0x04;
    public static List<IntPtr> foundWindows = new List<IntPtr>();
}
public struct RECT {
    public int Left;
    public int Top;
    public int Right;
    public int Bottom;
}
"@

$global:winRect = $null
$global:winHandle = [IntPtr]::Zero

function Get-Win {
    [Win32]::foundWindows.Clear()
    
    $teamsProcs = Get-Process | Where-Object {
        $_.ProcessName -like "*ms-teams*" -or 
        $_.ProcessName -like "*Teams*" -or
        $_.MainWindowTitle -like "*Teams*" -or
        $_.MainWindowTitle -like "*Chat*"
    }
    
    $procIds = @()
    foreach ($p in $teamsProcs) {
        $procIds += $p.Id
    }
    
    $enumProc = [Win32+EnumWindowsProc]{
        param([IntPtr]$hWnd, [IntPtr]$lParam)
        
        if (-not [Win32]::IsWindowVisible($hWnd)) {
            return $true
        }
        
        $processId = 0
        [Win32]::GetWindowThreadProcessId($hWnd, [ref]$processId) | Out-Null
        
        if ($procIds -contains $processId) {
            $sb = New-Object System.Text.StringBuilder(256)
            [Win32]::GetWindowText($hWnd, $sb, $sb.Capacity) | Out-Null
            $title = $sb.ToString()
            
            $sb2 = New-Object System.Text.StringBuilder(256)
            [Win32]::GetClassName($hWnd, $sb2, $sb2.Capacity) | Out-Null
            $className = $sb2.ToString()
            
            if ($title -ne "" -or $className -like "*Chrome*" -or $className -like "*Electron*") {
                $rect = New-Object RECT
                if ([Win32]::GetWindowRect($hWnd, [ref]$rect)) {
                    $w = $rect.Right - $rect.Left
                    $h = $rect.Bottom - $rect.Top
                    if ($w -gt 400 -and $h -gt 300) {
                        [Win32]::foundWindows.Add($hWnd)
                    }
                }
            }
        }
        
        return $true
    }
    
    [Win32]::EnumWindows($enumProc, [IntPtr]::Zero) | Out-Null
    
    if ([Win32]::foundWindows.Count -gt 0) {
        $best = [Win32]::foundWindows[0]
        $maxArea = 0
        
        foreach ($hwnd in [Win32]::foundWindows) {
            $rect = New-Object RECT
            if ([Win32]::GetWindowRect($hwnd, [ref]$rect)) {
                $area = ($rect.Right - $rect.Left) * ($rect.Bottom - $rect.Top)
                if ($area -gt $maxArea) {
                    $maxArea = $area
                    $best = $hwnd
                }
            }
        }
        
        $rect = New-Object RECT
        if ([Win32]::GetWindowRect($best, [ref]$rect)) {
            $global:winHandle = $best
            $global:winRect = $rect
            return $true
        }
    }
    
    if ($teamsProcs.Count -eq 0) {
        $paths = @(
            "$env:LOCALAPPDATA\Microsoft\Teams\Update.exe",
            "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Microsoft Teams.lnk"
        )
        
        foreach ($path in $paths) {
            if (Test-Path $path) {
                if ($path -like "*Update.exe") {
                    Start-Process $path -ArgumentList "--processStart","Teams.exe" -ErrorAction SilentlyContinue
                } elseif ($path -like "*.lnk") {
                    $shell = New-Object -ComObject WScript.Shell
                    $shortcut = $shell.CreateShortcut($path)
                    Start-Process $shortcut.TargetPath -ErrorAction SilentlyContinue
                }
                break
            }
        }
        
        for ($i = 0; $i -lt 15; $i++) {
            Start-Sleep -Seconds 2
            [Win32]::foundWindows.Clear()
            $teamsProcs = Get-Process | Where-Object {
                $_.ProcessName -like "*ms-teams*" -or 
                $_.ProcessName -like "*Teams*"
            }
            $procIds = @()
            foreach ($p in $teamsProcs) {
                $procIds += $p.Id
            }
            if ($procIds.Count -gt 0) {
                [Win32]::EnumWindows($enumProc, [IntPtr]::Zero) | Out-Null
                if ([Win32]::foundWindows.Count -gt 0) {
                    $best = [Win32]::foundWindows[0]
                    $maxArea = 0
                    foreach ($hwnd in [Win32]::foundWindows) {
                        $rect = New-Object RECT
                        if ([Win32]::GetWindowRect($hwnd, [ref]$rect)) {
                            $area = ($rect.Right - $rect.Left) * ($rect.Bottom - $rect.Top)
                            if ($area -gt $maxArea) {
                                $maxArea = $area
                                $best = $hwnd
                            }
                        }
                    }
                    $rect = New-Object RECT
                    if ([Win32]::GetWindowRect($best, [ref]$rect)) {
                        $global:winHandle = $best
                        $global:winRect = $rect
                        return $true
                    }
                }
            }
        }
    }
    
    return $false
}

function Move-Sans {
    if ($global:winRect -eq $null) {
        if (-not (Get-Win)) {
            Start-Sleep -Seconds 2
            return
        }
    }
    
    if (-not ([Win32]::IsWindow($global:winHandle))) {
        $global:winRect = $null
        if (-not (Get-Win)) {
            Start-Sleep -Seconds 2
            return
        }
    }
    
    $p = [System.Windows.Forms.Cursor]::Position
    
    $graphics = [System.Drawing.Graphics]::FromHwnd([IntPtr]::Zero)
    $dpi = $graphics.DpiX
    $graphics.Dispose()
    $boxSize = [int](2 * $dpi / 2.54)
    
    $l = $global:winRect.Left + 50
    $t = $global:winRect.Top + 100
    $r = $global:winRect.Right - 50
    $b = $global:winRect.Bottom - 50
    
    $boxLeft = [Math]::Max($l, $p.X - $boxSize/2)
    $boxTop = [Math]::Max($t, $p.Y - $boxSize/2)
    $boxRight = [Math]::Min($r, $p.X + $boxSize/2)
    $boxBottom = [Math]::Min($b, $p.Y + $boxSize/2)
    
    if ($boxRight - $boxLeft -lt $boxSize) {
        if ($boxLeft -eq $l) {
            $boxRight = $l + $boxSize
        } else {
            $boxLeft = $boxRight - $boxSize
        }
    }
    if ($boxBottom - $boxTop -lt $boxSize) {
        if ($boxTop -eq $t) {
            $boxBottom = $t + $boxSize
        } else {
            $boxTop = $boxBottom - $boxSize
        }
    }
    
    $x = Get-Random -Minimum $boxLeft -Maximum $boxRight
    $y = Get-Random -Minimum $boxTop -Maximum $boxBottom
    
    $s = Get-Random -Minimum 10 -Maximum 40
    $d = Get-Random -Minimum 0.5 -Maximum 2.0
    
    for ($i = 0; $i -le $s; $i++) {
        $r = $i / $s
        $nx = [int]($p.X + ($x - $p.X) * $r)
        $ny = [int]($p.Y + ($y - $p.Y) * $r)
        [System.Windows.Forms.Cursor]::Position = New-Object System.Drawing.Point($nx, $ny)
        Start-Sleep -Milliseconds ([int]($d * 1000 / $s))
    }
    
}

function Invoke-Left {
    [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    Start-Sleep -Milliseconds 10
    [Win32]::mouse_event([Win32]::MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)
}

function Start-Sans {
    $skamt = @(
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
        "Varför simmar ankorna i hamnen på raka led? – Det är ankring förbjuden!"
    )
    
    Get-Win | Out-Null
    
    try {
        while ($true) {
            Move-Sans
            
            $preClickDelay = Get-Random -Minimum 0.1 -Maximum 0.5
            Start-Sleep -Seconds $preClickDelay
            
            Invoke-Left
            
            $randomSkamt = $skamt | Get-Random
            Write-Host $randomSkamt
            
            $waitTime = Get-Random -Minimum 0 -Maximum 80
            Start-Sleep -Seconds $waitTime
        }
    }
    catch {
        if ($_.Exception.GetType().Name -eq "OperationCanceledException") {
        }
        else {
        }
        exit 0
    }
}

Start-Sans

