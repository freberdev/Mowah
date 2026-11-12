//! Reading how long the system has been idle, and producing harmless input.

use std::f64::consts::TAU;
use std::mem::size_of;

use windows_sys::Win32::Foundation::POINT;
use windows_sys::Win32::System::SystemInformation::GetTickCount64;
use windows_sys::Win32::System::Threading::{GetCurrentProcessId, Sleep};
use windows_sys::Win32::UI::HiDpi::GetDpiForSystem;
use windows_sys::Win32::UI::Input::KeyboardAndMouse::{
    GetLastInputInfo, SendInput, INPUT, INPUT_0, INPUT_KEYBOARD, INPUT_MOUSE, KEYBDINPUT, KEYEVENTF_KEYUP,
    LASTINPUTINFO, MOUSEEVENTF_LEFTDOWN, MOUSEEVENTF_LEFTUP, MOUSEEVENTF_MOVE, MOUSEINPUT, VK_F15,
};
use windows_sys::Win32::UI::WindowsAndMessaging::{
    GetCursorPos, GetSystemMetrics, GetWindowThreadProcessId, SetCursorPos, WindowFromPoint, SM_CXVIRTUALSCREEN,
    SM_XVIRTUALSCREEN,
};

use crate::core::settings::Method;

/// The current time on Windows' tick clock, and how many milliseconds ago Windows
/// last saw mouse or keyboard input of any origin.
pub fn clock_and_idle_ms() -> (u64, u64) {
    let mut info = LASTINPUTINFO { cbSize: size_of::<LASTINPUTINFO>() as u32, dwTime: 0 };
    let known = unsafe { GetLastInputInfo(&mut info) } != 0;
    // The clock is read after the input time. The other way round, input landing
    // between the two calls would look like it happened in the future.
    let now_ms = unsafe { GetTickCount64() };
    // If the call fails, report "just active" so Mowah errs on the side of doing nothing.
    let idle_ms = if known { u64::from((now_ms as u32).wrapping_sub(info.dwTime)) } else { 0 };
    (now_ms, idle_ms)
}

/// Performs one round of activity. Only called when the user has been away.
/// Returns false if the user took over the mouse before it was finished.
pub fn perform(method: Method, left_click: bool) -> bool {
    match method {
        Method::Nudge => nudge(),
        Method::VisibleMove => {
            if !visible_loop() {
                // The user grabbed the mouse mid-loop. They are back, so stop here.
                return false;
            }
            // Moving the pointer with SetCursorPos is visible but does not count as
            // input, so the nudge afterwards is what actually resets the idle clock.
            nudge();
        }
        Method::KeyF15 => send(&[key(VK_F15, 0), key(VK_F15, KEYEVENTF_KEYUP)]),
    }
    if left_click && !pointer_is_over_own_window() {
        send(&[mouse(MOUSEEVENTF_LEFTDOWN, 0, 0), mouse(MOUSEEVENTF_LEFTUP, 0, 0)]);
    }
    true
}

/// One pixel sideways and back again.
fn nudge() {
    // At the right-hand edge a move to the right is swallowed, which would leave
    // the pointer one pixel off after the return move. Start leftwards there.
    let first = if pointer_at_right_edge() { -1 } else { 1 };
    send(&[mouse(MOUSEEVENTF_MOVE, first, 0), mouse(MOUSEEVENTF_MOVE, -first, 0)]);
}

/// Draws a circle with the pointer, about a second long and big enough to notice,
/// and ends where it started. Returns false, leaving the pointer alone, as soon as
/// something else moves it, so it never fights a returning user.
fn visible_loop() -> bool {
    const STEPS: i32 = 48;
    /// Radius at 100 % display scaling. Mowah works in physical pixels, so on a
    /// high-resolution screen the same number would be a much smaller circle.
    const RADIUS_AT_96_DPI: f64 = 40.0;

    let radius = RADIUS_AT_96_DPI * f64::from(unsafe { GetDpiForSystem() }) / 96.0;
    let Some(origin) = cursor_pos() else { return false };
    for step in 1..=STEPS {
        let angle = TAU * f64::from(step) / f64::from(STEPS);
        let target = POINT {
            x: origin.x + (radius * (1.0 - angle.cos())).round() as i32,
            y: origin.y + (radius * angle.sin()).round() as i32,
        };
        unsafe { SetCursorPos(target.x, target.y) };
        // Read back at once: at a screen edge Windows puts the pointer somewhere
        // other than where it was sent, and that must not be mistaken for the user.
        let placed = cursor_pos().unwrap_or(target);
        unsafe { Sleep(16) };
        match cursor_pos() {
            Some(actual) if actual.x == placed.x && actual.y == placed.y => {}
            _ => return false,
        }
    }
    unsafe { SetCursorPos(origin.x, origin.y) };
    true
}

fn cursor_pos() -> Option<POINT> {
    let mut point = POINT { x: 0, y: 0 };
    (unsafe { GetCursorPos(&mut point) } != 0).then_some(point)
}

fn pointer_at_right_edge() -> bool {
    let Some(point) = cursor_pos() else { return false };
    let right = unsafe { GetSystemMetrics(SM_XVIRTUALSCREEN) + GetSystemMetrics(SM_CXVIRTUALSCREEN) };
    point.x >= right - 1
}

/// A click on Mowah's own window could press its pause button, so those are skipped.
fn pointer_is_over_own_window() -> bool {
    let Some(point) = cursor_pos() else { return false };
    unsafe {
        let window = WindowFromPoint(point);
        if window.is_null() {
            return false;
        }
        let mut process_id = 0;
        GetWindowThreadProcessId(window, &mut process_id);
        process_id == GetCurrentProcessId()
    }
}

fn mouse(flags: u32, dx: i32, dy: i32) -> INPUT {
    INPUT {
        r#type: INPUT_MOUSE,
        Anonymous: INPUT_0 { mi: MOUSEINPUT { dx, dy, mouseData: 0, dwFlags: flags, time: 0, dwExtraInfo: 0 } },
    }
}

fn key(virtual_key: u16, flags: u32) -> INPUT {
    INPUT {
        r#type: INPUT_KEYBOARD,
        Anonymous: INPUT_0 {
            ki: KEYBDINPUT { wVk: virtual_key, wScan: 0, dwFlags: flags, time: 0, dwExtraInfo: 0 },
        },
    }
}

fn send(inputs: &[INPUT]) {
    unsafe { SendInput(inputs.len() as u32, inputs.as_ptr(), size_of::<INPUT>() as i32) };
}
