import ctypes
from ctypes import wintypes
import random
import time
import sys
import os
import subprocess
import psutil

user32 = ctypes.windll.user32
kernel32 = ctypes.windll.kernel32
gdi32 = ctypes.windll.gdi32

user32.GetDC.argtypes = [wintypes.HWND]
user32.GetDC.restype = wintypes.HDC
user32.ReleaseDC.argtypes = [wintypes.HWND, wintypes.HDC]
gdi32.GetDeviceCaps.argtypes = [wintypes.HDC, ctypes.c_int]
gdi32.GetDeviceCaps.restype = ctypes.c_int

class RECT(ctypes.Structure):
    _fields_ = [("Left", ctypes.c_long),
                ("Top", ctypes.c_long),
                ("Right", ctypes.c_long),
                ("Bottom", ctypes.c_long)]

winRect = None
winHandle = None
found_windows_list = []

def enum_proc(hwnd, lParam):
    if not user32.IsWindowVisible(hwnd):
        return True
    
    process_id = wintypes.DWORD()
    user32.GetWindowThreadProcessId(hwnd, ctypes.byref(process_id))
    
    try:
        proc = psutil.Process(process_id.value)
        proc_name = proc.name().lower()
        if 'teams' in proc_name or 'ms-teams' in proc_name:
            title = ctypes.create_unicode_buffer(256)
            user32.GetWindowTextW(hwnd, title, 256)
            
            class_name = ctypes.create_unicode_buffer(256)
            user32.GetClassNameW(hwnd, class_name, 256)
            
            if title.value or 'chrome' in class_name.value.lower() or 'electron' in class_name.value.lower():
                rect = RECT()
                if user32.GetWindowRect(hwnd, ctypes.byref(rect)):
                    w = rect.Right - rect.Left
                    h = rect.Bottom - rect.Top
                    if w > 400 and h > 300:
                        found_windows_list.append((hwnd, rect))
    except:
        pass
    
    return True

def get_win():
    global winRect, winHandle, found_windows_list
    
    found_windows_list.clear()
    
    teams_procs = []
    for proc in psutil.process_iter(['pid', 'name']):
        try:
            name = proc.info['name'].lower()
            if 'teams' in name or 'ms-teams' in name:
                teams_procs.append(proc.info['pid'])
        except:
            pass
    
    if teams_procs:
        EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
        enum_func = EnumWindowsProc(enum_proc)
        user32.EnumWindows(enum_func, 0)
        
        if found_windows_list:
            best = found_windows_list[0]
            max_area = 0
            for hwnd, rect in found_windows_list:
                area = (rect.Right - rect.Left) * (rect.Bottom - rect.Top)
                if area > max_area:
                    max_area = area
                    best = (hwnd, rect)
            
            winHandle = best[0]
            winRect = best[1]
            return True
    
    if not teams_procs:
        paths = [
            os.path.join(os.environ.get('LOCALAPPDATA', ''), 'Microsoft', 'Teams', 'Update.exe'),
            os.path.join(os.environ.get('APPDATA', ''), 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Microsoft Teams.lnk')
        ]
        
        for path in paths:
            if os.path.exists(path):
                if 'Update.exe' in path:
                    subprocess.Popen([path, '--processStart', 'Teams.exe'], 
                                   creationflags=subprocess.CREATE_NO_WINDOW)
                break
        
        for i in range(15):
            time.sleep(2)
            found_windows_list.clear()
            teams_procs = []
            for proc in psutil.process_iter(['pid', 'name']):
                try:
                    name = proc.info['name'].lower()
                    if 'teams' in name or 'ms-teams' in name:
                        teams_procs.append(proc.info['pid'])
                except:
                    pass
            
            if teams_procs:
                EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
                enum_func = EnumWindowsProc(enum_proc)
                user32.EnumWindows(enum_func, 0)
                if found_windows_list:
                    best = found_windows_list[0]
                    max_area = 0
                    for hwnd, rect in found_windows_list:
                        area = (rect.Right - rect.Left) * (rect.Bottom - rect.Top)
                        if area > max_area:
                            max_area = area
                            best = (hwnd, rect)
                    winHandle = best[0]
                    winRect = best[1]
                    return True
    
    return False

def move_sans():
    global winRect, winHandle
    
    if winRect is None:
        if not get_win():
            time.sleep(2)
            return
    
    if winHandle and not user32.IsWindow(winHandle):
        winRect = None
        if not get_win():
            time.sleep(2)
            return
    
    class POINT(ctypes.Structure):
        _fields_ = [("x", ctypes.c_long), ("y", ctypes.c_long)]
    current_pos = POINT()
    user32.GetCursorPos(ctypes.byref(current_pos))
    
    hdc = user32.GetDC(0)
    LOGPIXELSX = 88
    dpi = gdi32.GetDeviceCaps(hdc, LOGPIXELSX)
    user32.ReleaseDC(0, hdc)
    box_size = int(2 * dpi / 2.54)
    
    l = winRect.Left + 50
    t = winRect.Top + 100
    r = winRect.Right - 50
    b = winRect.Bottom - 50
    
    box_left = max(l, current_pos.x - box_size // 2)
    box_top = max(t, current_pos.y - box_size // 2)
    box_right = min(r, current_pos.x + box_size // 2)
    box_bottom = min(b, current_pos.y + box_size // 2)
    
    if box_right - box_left < box_size:
        if box_left == l:
            box_right = l + box_size
        else:
            box_left = box_right - box_size
    
    if box_bottom - box_top < box_size:
        if box_top == t:
            box_bottom = t + box_size
        else:
            box_top = box_bottom - box_size
    
    x = random.randint(int(box_left), int(box_right))
    y = random.randint(int(box_top), int(box_bottom))
    
    steps = random.randint(10, 40)
    duration = random.uniform(0.5, 2.0)
    
    for i in range(steps + 1):
        progress = i / steps
        nx = int(current_pos.x + (x - current_pos.x) * progress)
        ny = int(current_pos.y + (y - current_pos.y) * progress)
        user32.SetCursorPos(nx, ny)
        time.sleep(duration / steps)
    
    pass

def invoke_left():
    MOUSEEVENTF_LEFTDOWN = 0x02
    MOUSEEVENTF_LEFTUP = 0x04
    user32.mouse_event(MOUSEEVENTF_LEFTDOWN, 0, 0, 0, 0)
    time.sleep(0.01)
    user32.mouse_event(MOUSEEVENTF_LEFTUP, 0, 0, 0, 0)

def start_sans():
    skamt = [
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
    ]
    
    get_win()
    
    try:
        while True:
            move_sans()
            
            pre_click_delay = random.uniform(0.1, 0.5)
            time.sleep(pre_click_delay)
            
            invoke_left()
            
            random_skamt = random.choice(skamt)
            print(random_skamt)
            
            wait_time = random.uniform(0, 80)
            time.sleep(wait_time)
    except KeyboardInterrupt:
        pass
    except Exception:
        pass
    finally:
        sys.exit(0)

if __name__ == "__main__":
    start_sans()
