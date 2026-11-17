//! Small wrappers around the parts of Windows that are not about the window itself:
//! the clock, sleep prevention, the settings file, autostart and single-instance.

use std::path::PathBuf;
use std::ptr::{null, null_mut};

use windows_sys::core::{w, PCWSTR};
use windows_sys::Win32::Foundation::{ERROR_SUCCESS, SYSTEMTIME};
use windows_sys::Win32::Globalization::GetUserDefaultUILanguage;
use windows_sys::Win32::System::Power::{
    SetThreadExecutionState, ES_CONTINUOUS, ES_DISPLAY_REQUIRED, ES_SYSTEM_REQUIRED, EXECUTION_STATE,
};
use windows_sys::Win32::System::Registry::{
    RegCloseKey, RegDeleteValueW, RegGetValueW, RegOpenKeyExW, RegSetValueExW, HKEY, HKEY_CURRENT_USER,
    KEY_SET_VALUE, REG_SZ, RRF_RT_REG_SZ,
};
use windows_sys::Win32::System::SystemInformation::{GetLocalTime, GetTickCount64};
use windows_sys::Win32::System::Threading::Sleep;
use windows_sys::Win32::UI::WindowsAndMessaging::{
    AllowSetForegroundWindow, FindWindowW, GetWindowThreadProcessId, PostMessageW,
};

use crate::core::engine::KeepAwake;
use crate::core::schedule::LocalTime;
use crate::core::settings::Settings;
use crate::core::text;

/// UTF-16 copy of `text` with the terminating zero Windows expects.
pub fn wide(text: &str) -> Vec<u16> {
    text.encode_utf16().chain(std::iter::once(0)).collect()
}

/// Whether the user has Windows itself shown in Swedish.
pub fn system_is_swedish() -> bool {
    text::is_swedish(unsafe { GetUserDefaultUILanguage() })
}

pub fn now_ms() -> u64 {
    unsafe { GetTickCount64() }
}

pub fn local_time() -> LocalTime {
    let mut time: SYSTEMTIME = unsafe { std::mem::zeroed() };
    unsafe { GetLocalTime(&mut time) };
    LocalTime { weekday: time.wDayOfWeek as u8, minute_of_day: time.wHour * 60 + time.wMinute }
}

// ---------------------------------------------------------------------------
// Sleep prevention

/// Translates what should stay awake into the flags Windows understands.
pub fn keep_awake_flags(needs: KeepAwake) -> EXECUTION_STATE {
    let mut flags = ES_CONTINUOUS;
    if needs.system {
        flags |= ES_SYSTEM_REQUIRED;
    }
    if needs.display {
        flags |= ES_DISPLAY_REQUIRED;
    }
    flags
}

/// Tells Windows what this thread needs kept awake. `ES_CONTINUOUS` alone clears the request.
pub fn set_keep_awake(flags: EXECUTION_STATE) {
    unsafe { SetThreadExecutionState(flags) };
}

// ---------------------------------------------------------------------------
// Settings file: %APPDATA%\Mowah\settings.ini

fn settings_path() -> Option<PathBuf> {
    Some(PathBuf::from(std::env::var_os("APPDATA")?).join("Mowah").join("settings.ini"))
}

/// Returns the saved settings, or `None` when there is no file yet (first run).
pub fn load_settings() -> Option<Settings> {
    let text = std::fs::read_to_string(settings_path()?).ok()?;
    Some(Settings::from_ini(&text))
}

/// Saving is best effort: if the profile is read-only the settings simply last for this run.
pub fn save_settings(settings: &Settings) {
    let Some(path) = settings_path() else { return };
    if let Some(folder) = path.parent() {
        let _ = std::fs::create_dir_all(folder);
    }
    let _ = std::fs::write(path, settings.to_ini());
}

// ---------------------------------------------------------------------------
// Autostart: a value under the current user's Run key. No admin rights involved.

const RUN_KEY: PCWSTR = w!("Software\\Microsoft\\Windows\\CurrentVersion\\Run");
const RUN_VALUE: PCWSTR = w!("Mowah");

/// The argument autostart adds so the window stays in the tray at logon.
pub const MINIMIZED_ARG: &str = "--minimized";

fn autostart_command() -> Option<String> {
    let exe = std::env::current_exe().ok()?;
    Some(format!("\"{}\" {MINIMIZED_ARG}", exe.display()))
}

fn registered_autostart_command() -> Option<String> {
    let mut buffer = [0u16; 1024];
    let mut bytes = std::mem::size_of_val(&buffer) as u32;
    let result = unsafe {
        RegGetValueW(
            HKEY_CURRENT_USER,
            RUN_KEY,
            RUN_VALUE,
            RRF_RT_REG_SZ,
            null_mut(),
            buffer.as_mut_ptr().cast(),
            &mut bytes,
        )
    };
    if result != ERROR_SUCCESS {
        return None;
    }
    let chars = (bytes as usize / 2).min(buffer.len());
    let text = String::from_utf16_lossy(&buffer[..chars]);
    Some(text.trim_end_matches('\0').to_string())
}

pub fn autostart_enabled() -> bool {
    registered_autostart_command().is_some()
}

/// Adds or removes the autostart entry. Returns false if Windows refused.
pub fn set_autostart(enabled: bool) -> bool {
    let mut key: HKEY = null_mut();
    if unsafe { RegOpenKeyExW(HKEY_CURRENT_USER, RUN_KEY, 0, KEY_SET_VALUE, &mut key) } != ERROR_SUCCESS {
        return false;
    }
    let result = if enabled {
        match autostart_command() {
            Some(command) => {
                let data = wide(&command);
                unsafe { RegSetValueExW(key, RUN_VALUE, 0, REG_SZ, data.as_ptr().cast(), (data.len() * 2) as u32) }
            }
            None => 1,
        }
    } else {
        unsafe { RegDeleteValueW(key, RUN_VALUE) }
    };
    unsafe { RegCloseKey(key) };
    result == ERROR_SUCCESS
}

/// If autostart is on but points at an old location (the .exe was moved), repoint it.
pub fn refresh_autostart_path() {
    if let (Some(registered), Some(current)) = (registered_autostart_command(), autostart_command()) {
        if registered != current {
            set_autostart(true);
        }
    }
}

// ---------------------------------------------------------------------------
// Single instance

/// Asks the already running Mowah to show its window. It may still be starting,
/// so the window is looked for a few times before giving up.
pub fn activate_running_instance(class_name: PCWSTR, show_message: u32) {
    for _ in 0..30 {
        unsafe {
            let window = FindWindowW(class_name, null());
            if !window.is_null() {
                let mut process_id = 0;
                GetWindowThreadProcessId(window, &mut process_id);
                // Only the process the user just started may hand over the foreground.
                AllowSetForegroundWindow(process_id);
                PostMessageW(window, show_message, 0, 0);
                return;
            }
            Sleep(100);
        }
    }
}
