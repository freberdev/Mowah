//! The Windows shell around the core logic: the main window, the tray icon and the
//! once-a-second timer that asks the engine what to do.

mod ids;
mod input;
mod system;

use std::cell::{Cell, RefCell};
use std::mem::{size_of, zeroed};
use std::ptr::{null, null_mut};
use std::time::{SystemTime, UNIX_EPOCH};

use windows_sys::core::{w, PCWSTR};
use windows_sys::Win32::Foundation::{GetLastError, ERROR_ALREADY_EXISTS, HINSTANCE, HWND, LPARAM, POINT, WPARAM};
use windows_sys::Win32::Graphics::Gdi::{
    GetSysColorBrush, SetBkMode, SetTextColor, COLOR_BTNFACE, HBRUSH, HDC, TRANSPARENT,
};
use windows_sys::Win32::System::LibraryLoader::GetModuleHandleW;
use windows_sys::Win32::System::Power::{ES_CONTINUOUS, EXECUTION_STATE};
use windows_sys::Win32::System::RemoteDesktop::{
    WTSRegisterSessionNotification, WTSUnRegisterSessionNotification, NOTIFY_FOR_THIS_SESSION,
};
use windows_sys::Win32::System::Threading::CreateMutexW;
use windows_sys::Win32::UI::Controls::{
    CheckDlgButton, InitCommonControlsEx, IsDlgButtonChecked, BST_CHECKED, BST_UNCHECKED, ICC_STANDARD_CLASSES,
    INITCOMMONCONTROLSEX,
};
use windows_sys::Win32::UI::Input::KeyboardAndMouse::EnableWindow;
use windows_sys::Win32::UI::Shell::{
    Shell_NotifyIconW, NIF_ICON, NIF_MESSAGE, NIF_TIP, NIM_ADD, NIM_DELETE, NIM_MODIFY, NOTIFYICONDATAW,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    AppendMenuW, CreateDialogParamW, CreatePopupMenu, DefDlgProcW, DestroyMenu, DestroyWindow, DispatchMessageW,
    GetCursorPos, GetDlgCtrlID, GetDlgItem, GetDlgItemInt, GetDlgItemTextW, GetMessageW, GetSystemMetrics, IsDialogMessageW,
    IsIconic, KillTimer, LoadCursorW, LoadImageW, MessageBoxW, PostMessageW, PostQuitMessage, RegisterClassExW,
    RegisterWindowMessageW, SendDlgItemMessageW, SetDlgItemInt, SetDlgItemTextW, SetForegroundWindow,
    SetMenuDefaultItem, SetTimer, ShowWindow, TrackPopupMenu, TranslateMessage, BN_CLICKED, CBN_SELCHANGE,
    CB_ADDSTRING, CB_GETCURSEL, CB_RESETCONTENT, CB_SETCURSEL, DLGWINDOWEXTRA, EN_KILLFOCUS, HICON, IDCANCEL, IDC_ARROW, IDOK,
    IMAGE_ICON, LR_DEFAULTCOLOR, MB_ICONERROR, MF_SEPARATOR, MF_STRING, MSG, SC_MINIMIZE, SM_CXICON,
    SM_CXSMICON, SM_CYICON, SM_CYSMICON, SW_HIDE, SW_RESTORE, SW_SHOW, TPM_BOTTOMALIGN, TPM_NONOTIFY, TPM_RETURNCMD,
    TPM_RIGHTBUTTON, WM_APP, WM_CLOSE, WM_COMMAND, WM_CONTEXTMENU, WM_CTLCOLORSTATIC, WM_DESTROY, WM_INITDIALOG,
    WM_LBUTTONDBLCLK, WM_LBUTTONUP, WM_NULL, WM_RBUTTONUP, WM_SYSCOMMAND, WM_TIMER, WM_WTSSESSION_CHANGE,
    WNDCLASSEXW, WTS_SESSION_LOCK, WTS_SESSION_UNLOCK,
};

use crate::core::engine::{keep_awake, Engine, Outcome, Status, TickInput};
use crate::core::settings::{format_hhmm, parse_hhmm, LanguageChoice, Method, Settings};
use crate::core::text::{self, Language, Texts};

use ids::*;
use system::wide;

/// Window class of the main window. A second Mowah finds the first one by this name.
const CLASS_NAME: PCWSTR = w!("MowahMainWindow");
const MUTEX_NAME: PCWSTR = w!("Local\\Mowah.SingleInstance");

/// Sent by the tray icon when it is clicked.
const WM_APP_TRAY: u32 = WM_APP + 1;
/// Sent by a second Mowah to make this one show its window.
const WM_APP_SHOW: u32 = WM_APP + 2;

const TIMER_ID: usize = 1;
const TRAY_ID: u32 = 1;
const TICK_MS: u32 = 1_000;
const HOUR_MS: u64 = 3_600_000;
const MINUTES_PER_DAY: u16 = 24 * 60;

/// Status text colours, as 0x00BBGGRR.
const COLOR_ON_DUTY: u32 = 0x003C_8016;
const COLOR_RESTING: u32 = 0x006E_6E6E;

/// The methods and the languages in the order they appear in their drop-down lists.
const METHODS: [Method; 3] = [Method::Nudge, Method::VisibleMove, Method::KeyF15];
const LANGUAGES: [LanguageChoice; 3] = [LanguageChoice::System, LanguageChoice::Swedish, LanguageChoice::English];

/// The text of every fixed label. The layout itself is in res/mowah.rc.
fn labels(t: &Texts) -> [(i32, &'static str); 21] {
    [
        (IDC_GRP_ACTIVITY, t.activity),
        (IDC_LBL_METHOD, t.method),
        (IDC_LBL_CIRCLE, t.circle_size),
        (IDC_LBL_CIRCLE_UNIT, t.pixels),
        (IDC_LBL_IDLE, t.idle_for),
        (IDC_LBL_IDLE_UNIT, t.seconds),
        (IDC_LBL_INTERVAL, t.repeat_every),
        (IDC_LBL_DASH, "–"),
        (IDC_LBL_INT_UNIT, t.seconds),
        (IDC_CLICK, t.left_click),
        (IDC_GRP_AWAKE, t.keep_awake),
        (IDC_PREVENT_SLEEP, t.prevent_sleep),
        (IDC_KEEP_DISPLAY, t.keep_display_on),
        (IDC_GRP_SCHEDULE, t.schedule),
        (IDC_SCHEDULE, t.schedule_between),
        (IDC_LBL_AND, t.and),
        (IDC_GRP_PROGRAM, t.program),
        (IDC_AUTOSTART, t.autostart),
        (IDC_START_MINIMIZED, t.start_minimized),
        (IDC_CLOSE_TO_TRAY, t.close_to_tray),
        (IDC_LBL_LANGUAGE, t.language),
    ]
}

/// Everything the window procedure needs between messages. Each field has its own
/// cell so that a message arriving in the middle of another one can never find the
/// state locked. The engine is only ever borrowed around a single `tick` call.
struct App {
    settings: Cell<Settings>,
    /// The language everything is shown in, worked out from the setting.
    language: Cell<Language>,
    engine: RefCell<Engine>,
    locked: Cell<bool>,
    status: Cell<Status>,
    /// Minute of day of the latest action and of the end of a timed pause.
    last_action: Cell<Option<u16>>,
    pause_end: Cell<Option<u16>>,
    keep_awake: Cell<EXECUTION_STATE>,
    /// False until Explorer has accepted the tray icon.
    tray_added: Cell<bool>,
    tray_tip: Cell<&'static str>,
    icon_on_duty: Cell<HICON>,
    icon_resting: Cell<HICON>,
    /// Message Explorer broadcasts when the taskbar has been (re)created.
    taskbar_created: Cell<u32>,
}

thread_local! {
    static APP: App = {
        let seed = SystemTime::now().duration_since(UNIX_EPOCH).map_or(1, |d| d.as_nanos() as u64);
        App {
            settings: Cell::new(Settings::default()),
            // Until the settings have been read, a message can only follow Windows.
            language: Cell::new(text::resolve(LanguageChoice::System, system::system_is_swedish())),
            engine: RefCell::new(Engine::new(seed)),
            locked: Cell::new(false),
            status: Cell::new(Status::UserActive),
            last_action: Cell::new(None),
            pause_end: Cell::new(None),
            keep_awake: Cell::new(ES_CONTINUOUS),
            tray_added: Cell::new(false),
            tray_tip: Cell::new(""),
            icon_on_duty: Cell::new(null_mut()),
            icon_resting: Cell::new(null_mut()),
            taskbar_created: Cell::new(0),
        }
    };
}

pub fn run() {
    unsafe {
        // The handle is kept until the process ends, which is what marks Mowah as running.
        CreateMutexW(null(), 0, MUTEX_NAME);
        if GetLastError() == ERROR_ALREADY_EXISTS {
            system::activate_running_instance(CLASS_NAME, WM_APP_SHOW);
            return;
        }

        let instance = GetModuleHandleW(null());
        let controls = INITCOMMONCONTROLSEX {
            dwSize: size_of::<INITCOMMONCONTROLSEX>() as u32,
            dwICC: ICC_STANDARD_CLASSES,
        };
        InitCommonControlsEx(&controls);

        // A dialog with its own class name, so it can be found by `FindWindowW`.
        let class = WNDCLASSEXW {
            cbSize: size_of::<WNDCLASSEXW>() as u32,
            style: 0,
            lpfnWndProc: Some(DefDlgProcW),
            cbClsExtra: 0,
            cbWndExtra: DLGWINDOWEXTRA as i32,
            hInstance: instance,
            hIcon: load_icon(instance, IDI_APP, SM_CXICON, SM_CYICON),
            hCursor: LoadCursorW(null_mut(), IDC_ARROW),
            hbrBackground: (COLOR_BTNFACE + 1) as usize as HBRUSH,
            lpszMenuName: null(),
            lpszClassName: CLASS_NAME,
            hIconSm: load_icon(instance, IDI_APP, SM_CXSMICON, SM_CYSMICON),
        };
        if RegisterClassExW(&class) == 0 {
            return report_startup_failure();
        }

        let saved = system::load_settings();
        let first_run = saved.is_none();
        let settings = saved.unwrap_or_default();
        if first_run {
            system::save_settings(&settings);
        }
        APP.with(|app| {
            app.settings.set(settings);
            app.language.set(text::resolve(settings.language, system::system_is_swedish()));
        });

        let window = CreateDialogParamW(instance, resource(IDD_MAIN), null_mut(), Some(dialog_proc), 0);
        if window.is_null() {
            return report_startup_failure();
        }

        let started_at_logon = std::env::args().any(|arg| arg == system::MINIMIZED_ARG);
        if first_run || !(started_at_logon || settings.start_minimized) {
            show_window(window);
        }

        let mut message: MSG = zeroed();
        while GetMessageW(&mut message, null_mut(), 0, 0) > 0 {
            if IsDialogMessageW(window, &message) == 0 {
                TranslateMessage(&message);
                DispatchMessageW(&message);
            }
        }
    }
}

unsafe fn report_startup_failure() {
    let message = wide(current_texts().startup_failure);
    MessageBoxW(null_mut(), message.as_ptr(), w!("Mowah"), MB_ICONERROR);
}

fn current_language() -> Language {
    APP.with(|app| app.language.get())
}

fn current_texts() -> &'static Texts {
    text::texts(current_language())
}

/// Resource IDs are passed to Windows disguised as string pointers.
fn resource(id: u16) -> PCWSTR {
    id as usize as PCWSTR
}

unsafe fn load_icon(instance: HINSTANCE, id: u16, width_metric: i32, height_metric: i32) -> HICON {
    LoadImageW(
        instance,
        resource(id),
        IMAGE_ICON,
        GetSystemMetrics(width_metric),
        GetSystemMetrics(height_metric),
        // Not LR_SHARED: the same icon is loaded in two sizes, and a shared handle
        // could hand back the first size for both.
        LR_DEFAULTCOLOR,
    )
}

unsafe extern "system" fn dialog_proc(window: HWND, message: u32, wparam: WPARAM, lparam: LPARAM) -> isize {
    match message {
        WM_INITDIALOG => on_init(window),
        WM_TIMER if wparam == TIMER_ID => tick(window),
        WM_COMMAND => {
            let id = (wparam & 0xFFFF) as i32;
            let notification = ((wparam >> 16) & 0xFFFF) as u32;
            return on_command(window, id, notification) as isize;
        }
        WM_SYSCOMMAND if wparam & 0xFFF0 == SC_MINIMIZE as usize => hide_window(window),
        WM_CLOSE => close_window(window),
        WM_DESTROY => on_destroy(window),
        WM_APP_TRAY => match lparam as u32 {
            WM_LBUTTONUP | WM_LBUTTONDBLCLK => show_window(window),
            WM_RBUTTONUP | WM_CONTEXTMENU => show_tray_menu(window),
            _ => {}
        },
        WM_APP_SHOW => show_window(window),
        WM_WTSSESSION_CHANGE => match wparam as u32 {
            WTS_SESSION_LOCK => APP.with(|app| app.locked.set(true)),
            WTS_SESSION_UNLOCK => APP.with(|app| app.locked.set(false)),
            _ => {}
        },
        WM_CTLCOLORSTATIC if matches!(GetDlgCtrlID(lparam as HWND), IDC_STATUS | IDC_FOOTER) => {
            // The status is green while Mowah is on duty; the footer is always grey.
            let is_status = GetDlgCtrlID(lparam as HWND) == IDC_STATUS;
            let on_duty = is_status && APP.with(|app| app.status.get().is_armed());
            let device = wparam as HDC;
            SetTextColor(device, if on_duty { COLOR_ON_DUTY } else { COLOR_RESTING });
            SetBkMode(device, TRANSPARENT as i32);
            // For this message a dialog procedure returns the background brush itself.
            return GetSysColorBrush(COLOR_BTNFACE) as isize;
        }
        // Explorer restarted, or was not ready when Mowah started at logon.
        _ if message != 0 && message == APP.with(|app| app.taskbar_created.get()) => {
            APP.with(|app| app.tray_added.set(false));
            show_tray_icon(window);
        }
        _ => return 0,
    }
    1
}

unsafe fn on_init(window: HWND) {
    let instance = GetModuleHandleW(null());
    APP.with(|app| {
        app.icon_on_duty.set(load_icon(instance, IDI_APP, SM_CXSMICON, SM_CYSMICON));
        app.icon_resting.set(load_icon(instance, IDI_PAUSED, SM_CXSMICON, SM_CYSMICON));
        app.taskbar_created.set(RegisterWindowMessageW(w!("TaskbarCreated")));
    });

    show_language(window);
    show_settings(window, &APP.with(|app| app.settings.get()));
    let footer = text::footer(env!("CARGO_PKG_VERSION"), env!("MOWAH_BUILD_YEAR"), env!("MOWAH_COMPANY"));
    set_text(window, IDC_FOOTER, &footer);

    system::refresh_autostart_path();
    set_checked(window, IDC_AUTOSTART, system::autostart_enabled());

    show_tray_icon(window);
    WTSRegisterSessionNotification(window, NOTIFY_FOR_THIS_SESSION);
    SetTimer(window, TIMER_ID, TICK_MS, None);
    tick(window);
}

unsafe fn on_destroy(window: HWND) {
    apply_settings(window);
    KillTimer(window, TIMER_ID);
    WTSUnRegisterSessionNotification(window);
    Shell_NotifyIconW(NIM_DELETE, &tray_data(window));
    system::set_keep_awake(ES_CONTINUOUS);
    PostQuitMessage(0);
}

/// Handles clicks and edits in the window. Returns true when the command was handled.
unsafe fn on_command(window: HWND, id: i32, notification: u32) -> bool {
    match (id, notification) {
        (IDC_PAUSE, BN_CLICKED) => toggle_pause(window),
        // Esc closes like the X button; Enter confirms what was typed in a text box.
        (IDCANCEL, _) => close_window(window),
        (IDOK, _) => apply_settings(window),
        (IDC_AUTOSTART, BN_CLICKED) => {
            if !system::set_autostart(is_checked(window, IDC_AUTOSTART)) {
                // Windows refused, so show what is actually the case.
                set_checked(window, IDC_AUTOSTART, system::autostart_enabled());
            }
        }
        (IDC_METHOD | IDC_LANGUAGE, CBN_SELCHANGE)
        | (
            IDC_CLICK | IDC_PREVENT_SLEEP | IDC_KEEP_DISPLAY | IDC_SCHEDULE | IDC_START_MINIMIZED
            | IDC_CLOSE_TO_TRAY,
            BN_CLICKED,
        )
        | (
            IDC_CIRCLE | IDC_IDLE | IDC_INTERVAL_MIN | IDC_INTERVAL_MAX | IDC_SCHEDULE_FROM | IDC_SCHEDULE_TO,
            EN_KILLFOCUS,
        ) => apply_settings(window),
        _ => return false,
    }
    true
}

// ---------------------------------------------------------------------------
// The once-a-second tick

unsafe fn tick(window: HWND) {
    let (settings, outcome) = APP.with(|app| {
        let settings = app.settings.get();
        let (now_ms, system_idle_ms) = input::clock_and_idle_ms();
        let input = TickInput {
            now_ms,
            system_idle_ms,
            local: system::local_time(),
            locked: app.locked.get(),
        };
        let outcome = app.engine.borrow_mut().tick(&settings, &input);
        (settings, outcome)
    });

    if outcome.act {
        // No borrow is held while the action runs; a visible movement takes a second.
        let completed = input::perform(&settings);
        APP.with(|app| {
            let mut engine = app.engine.borrow_mut();
            if completed {
                engine.action_finished(system::now_ms());
                app.last_action.set(Some(system::local_time().minute_of_day));
            } else {
                engine.user_interrupted(system::now_ms());
            }
        });
    }
    show_status(window, &settings, outcome);
}

unsafe fn show_status(window: HWND, settings: &Settings, outcome: Outcome) {
    let (pause_end, last_action, paused) = APP.with(|app| {
        app.status.set(outcome.status);
        let flags = system::keep_awake_flags(keep_awake(outcome.status, settings));
        if app.keep_awake.replace(flags) != flags {
            system::set_keep_awake(flags);
        }
        (
            app.pause_end.get().map(format_hhmm),
            app.last_action.get().map(format_hhmm),
            app.engine.borrow().is_paused(),
        )
    });

    let language = current_language();
    let texts = text::texts(language);
    let headline = text::headline(language, outcome.status, outcome.user_idle_ms, pause_end.as_deref());
    set_text(window, IDC_STATUS, &headline);
    set_text(window, IDC_LAST_ACTION, &text::last_action_line(language, last_action.as_deref()));
    set_text(window, IDC_PAUSE, if paused { texts.resume } else { texts.pause });

    // Also true while the icon is still missing, so a failed add is retried every
    // tick, and right after the language was changed.
    if APP.with(|app| app.tray_tip.get()) != text::tray_tip(language, outcome.status) {
        show_tray_icon(window);
    }
}

unsafe fn toggle_pause(window: HWND) {
    APP.with(|app| {
        let mut engine = app.engine.borrow_mut();
        if engine.is_paused() {
            engine.resume();
        } else {
            engine.pause();
        }
        app.pause_end.set(None);
    });
    tick(window);
}

unsafe fn pause_for_an_hour(window: HWND) {
    APP.with(|app| {
        app.engine.borrow_mut().pause_until(system::now_ms() + HOUR_MS);
        app.pause_end.set(Some((system::local_time().minute_of_day + 60) % MINUTES_PER_DAY));
    });
    tick(window);
}

// ---------------------------------------------------------------------------
// Showing, hiding and closing the window

unsafe fn show_window(window: HWND) {
    ShowWindow(window, SW_SHOW);
    if IsIconic(window) != 0 {
        ShowWindow(window, SW_RESTORE);
    }
    SetForegroundWindow(window);
}

/// Hides the window; Mowah keeps running behind its tray icon.
unsafe fn hide_window(window: HWND) {
    apply_settings(window);
    ShowWindow(window, SW_HIDE);
}

unsafe fn close_window(window: HWND) {
    apply_settings(window);
    if APP.with(|app| app.settings.get().close_to_tray) {
        ShowWindow(window, SW_HIDE);
    } else {
        DestroyWindow(window);
    }
}

// ---------------------------------------------------------------------------
// Settings <-> controls

/// Reads the controls, corrects out-of-range values, and saves if anything changed.
unsafe fn apply_settings(window: HWND) {
    let previous = APP.with(|app| app.settings.get());
    let updated = read_settings(window, previous);
    let language = text::resolve(updated.language, system::system_is_swedish());
    let language_changed = APP.with(|app| app.language.replace(language)) != language;
    if language_changed {
        // Refilling the lists drops their selections; `show_settings` puts them back.
        show_language(window);
    }
    show_settings(window, &updated);
    if updated != previous {
        APP.with(|app| app.settings.set(updated));
        system::save_settings(&updated);
    }
    if language_changed {
        // Rewrites the status, the pause button and the tip on the tray icon.
        tick(window);
    }
}

/// Writes every fixed text in the current language: the labels and both lists.
unsafe fn show_language(window: HWND) {
    let texts = current_texts();
    for (id, label) in labels(texts) {
        set_text(window, id, label);
    }
    fill_list(window, IDC_METHOD, &[texts.method_nudge, texts.method_visible_move, texts.method_key_f15]);
    fill_list(window, IDC_LANGUAGE, &[texts.follow_system, text::SWEDISH_NAME, text::ENGLISH_NAME]);
}

/// Replaces the entries of a drop-down list. Nothing is selected afterwards.
unsafe fn fill_list(window: HWND, id: i32, entries: &[&str]) {
    SendDlgItemMessageW(window, id, CB_RESETCONTENT, 0, 0);
    for entry in entries {
        let entry = wide(entry);
        SendDlgItemMessageW(window, id, CB_ADDSTRING, 0, entry.as_ptr() as LPARAM);
    }
}

/// The entry selected in a drop-down list, if any.
unsafe fn selected_index(window: HWND, id: i32) -> Option<usize> {
    usize::try_from(SendDlgItemMessageW(window, id, CB_GETCURSEL, 0, 0)).ok()
}

/// Anything unreadable in a text box keeps its previous value.
unsafe fn read_settings(window: HWND, previous: Settings) -> Settings {
    let method = selected_index(window, IDC_METHOD).and_then(|index| METHODS.get(index));
    let language = selected_index(window, IDC_LANGUAGE).and_then(|index| LANGUAGES.get(index));
    let time = |id: i32, fallback: u16| parse_hhmm(&get_text(window, id)).unwrap_or(fallback);
    Settings {
        method: method.copied().unwrap_or(previous.method),
        circle_diameter_px: get_number(window, IDC_CIRCLE).unwrap_or(previous.circle_diameter_px),
        idle_threshold_secs: get_number(window, IDC_IDLE).unwrap_or(previous.idle_threshold_secs),
        interval_min_secs: get_number(window, IDC_INTERVAL_MIN).unwrap_or(previous.interval_min_secs),
        interval_max_secs: get_number(window, IDC_INTERVAL_MAX).unwrap_or(previous.interval_max_secs),
        left_click: is_checked(window, IDC_CLICK),
        prevent_sleep: is_checked(window, IDC_PREVENT_SLEEP),
        keep_display_on: is_checked(window, IDC_KEEP_DISPLAY),
        schedule_enabled: is_checked(window, IDC_SCHEDULE),
        schedule_start_min: time(IDC_SCHEDULE_FROM, previous.schedule_start_min),
        schedule_end_min: time(IDC_SCHEDULE_TO, previous.schedule_end_min),
        start_minimized: is_checked(window, IDC_START_MINIMIZED),
        close_to_tray: is_checked(window, IDC_CLOSE_TO_TRAY),
        language: language.copied().unwrap_or(previous.language),
    }
    .normalized()
}

unsafe fn show_settings(window: HWND, settings: &Settings) {
    let method = METHODS.iter().position(|method| *method == settings.method).unwrap_or(0);
    SendDlgItemMessageW(window, IDC_METHOD, CB_SETCURSEL, method, 0);
    let language = LANGUAGES.iter().position(|language| *language == settings.language).unwrap_or(0);
    SendDlgItemMessageW(window, IDC_LANGUAGE, CB_SETCURSEL, language, 0);
    set_number(window, IDC_CIRCLE, settings.circle_diameter_px);
    // The circle size only means something for the visible movement.
    let draws_circle = i32::from(settings.method == Method::VisibleMove);
    for id in [IDC_LBL_CIRCLE, IDC_CIRCLE, IDC_LBL_CIRCLE_UNIT] {
        EnableWindow(GetDlgItem(window, id), draws_circle);
    }
    set_number(window, IDC_IDLE, settings.idle_threshold_secs);
    set_number(window, IDC_INTERVAL_MIN, settings.interval_min_secs);
    set_number(window, IDC_INTERVAL_MAX, settings.interval_max_secs);
    set_checked(window, IDC_CLICK, settings.left_click);
    set_checked(window, IDC_PREVENT_SLEEP, settings.prevent_sleep);
    set_checked(window, IDC_KEEP_DISPLAY, settings.keep_display_on);
    set_checked(window, IDC_SCHEDULE, settings.schedule_enabled);
    set_text(window, IDC_SCHEDULE_FROM, &format_hhmm(settings.schedule_start_min));
    set_text(window, IDC_SCHEDULE_TO, &format_hhmm(settings.schedule_end_min));
    set_checked(window, IDC_START_MINIMIZED, settings.start_minimized);
    set_checked(window, IDC_CLOSE_TO_TRAY, settings.close_to_tray);
}

unsafe fn get_text(window: HWND, id: i32) -> String {
    let mut buffer = [0u16; 512];
    let length = GetDlgItemTextW(window, id, buffer.as_mut_ptr(), buffer.len() as i32) as usize;
    String::from_utf16_lossy(&buffer[..length.min(buffer.len())])
}

/// Only touches the control when the text differs, so a status that is refreshed
/// every second does not flicker and a text box keeps its selection.
unsafe fn set_text(window: HWND, id: i32, text: &str) {
    if get_text(window, id) != text {
        SetDlgItemTextW(window, id, wide(text).as_ptr());
    }
}

unsafe fn get_number(window: HWND, id: i32) -> Option<u32> {
    let mut valid = 0;
    let value = GetDlgItemInt(window, id, &mut valid, 0);
    (valid != 0).then_some(value)
}

unsafe fn set_number(window: HWND, id: i32, value: u32) {
    if get_number(window, id) != Some(value) {
        SetDlgItemInt(window, id, value, 0);
    }
}

unsafe fn is_checked(window: HWND, id: i32) -> bool {
    IsDlgButtonChecked(window, id) == BST_CHECKED
}

unsafe fn set_checked(window: HWND, id: i32, checked: bool) {
    CheckDlgButton(window, id, if checked { BST_CHECKED } else { BST_UNCHECKED });
}

// ---------------------------------------------------------------------------
// Tray icon

unsafe fn tray_data(window: HWND) -> NOTIFYICONDATAW {
    let mut data: NOTIFYICONDATAW = zeroed();
    data.cbSize = size_of::<NOTIFYICONDATAW>() as u32;
    data.hWnd = window;
    data.uID = TRAY_ID;
    data
}

/// Adds the tray icon, or updates it to match the current status if it is already there.
unsafe fn show_tray_icon(window: HWND) {
    let (status, on_duty_icon, resting_icon, added) = APP.with(|app| {
        (app.status.get(), app.icon_on_duty.get(), app.icon_resting.get(), app.tray_added.get())
    });
    let action = if added { NIM_MODIFY } else { NIM_ADD };
    let tip = text::tray_tip(current_language(), status);

    let mut data = tray_data(window);
    data.uFlags = NIF_MESSAGE | NIF_ICON | NIF_TIP;
    data.uCallbackMessage = WM_APP_TRAY;
    data.hIcon = if status.is_armed() { on_duty_icon } else { resting_icon };
    // The tip buffer is zeroed, so leaving the last slot untouched keeps it terminated.
    let room = data.szTip.len() - 1;
    for (slot, unit) in data.szTip.iter_mut().zip(tip.encode_utf16().take(room)) {
        *slot = unit;
    }

    if Shell_NotifyIconW(action, &data) != 0 {
        APP.with(|app| {
            app.tray_added.set(true);
            app.tray_tip.set(tip);
        });
    }
}

unsafe fn show_tray_menu(window: HWND) {
    let paused = APP.with(|app| app.engine.borrow().is_paused());
    let menu = CreatePopupMenu();
    if menu.is_null() {
        return;
    }
    let texts = current_texts();
    // The menu copies each text, so the buffer only has to live through the call.
    let add = |id: usize, label: &str| AppendMenuW(menu, MF_STRING, id, wide(label).as_ptr());
    add(IDM_OPEN, texts.menu_open);
    add(IDM_TOGGLE_PAUSE, if paused { texts.resume } else { texts.pause });
    add(IDM_PAUSE_HOUR, texts.menu_pause_hour);
    AppendMenuW(menu, MF_SEPARATOR, 0, null());
    add(IDM_EXIT, texts.menu_exit);
    SetMenuDefaultItem(menu, IDM_OPEN as u32, 0);

    let mut cursor = POINT { x: 0, y: 0 };
    GetCursorPos(&mut cursor);
    // Without foreground status the menu would not close when clicking elsewhere.
    SetForegroundWindow(window);
    // Bottom-aligned so the menu opens upwards from the tray instead of over the taskbar.
    let flags = TPM_RIGHTBUTTON | TPM_RETURNCMD | TPM_NONOTIFY | TPM_BOTTOMALIGN;
    let choice = TrackPopupMenu(menu, flags, cursor.x, cursor.y, 0, window, null());
    PostMessageW(window, WM_NULL, 0, 0);
    DestroyMenu(menu);

    match choice as usize {
        IDM_OPEN => show_window(window),
        IDM_TOGGLE_PAUSE => toggle_pause(window),
        IDM_PAUSE_HOUR => pause_for_an_hour(window),
        IDM_EXIT => {
            DestroyWindow(window);
        }
        _ => {}
    }
}
