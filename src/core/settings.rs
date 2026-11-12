/// Shortest and longest allowed timing values, in seconds. The upper bound stays
/// under five minutes because that is when Teams marks a user as away.
pub const MIN_SECS: u32 = 5;
pub const MAX_SECS: u32 = 240;

const MINUTES_PER_DAY: u16 = 24 * 60;
const DEFAULT_SCHEDULE_START: u16 = 8 * 60;
const DEFAULT_SCHEDULE_END: u16 = 17 * 60;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Method {
    /// Move the pointer one pixel and back. Not visible.
    Nudge,
    /// Move the pointer in a small visible loop.
    VisibleMove,
    /// Press F15, a key no normal keyboard has.
    KeyF15,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Settings {
    pub method: Method,
    pub idle_threshold_secs: u32,
    pub interval_min_secs: u32,
    pub interval_max_secs: u32,
    pub left_click: bool,
    pub prevent_sleep: bool,
    pub keep_display_on: bool,
    pub schedule_enabled: bool,
    /// Minutes since midnight.
    pub schedule_start_min: u16,
    pub schedule_end_min: u16,
    pub start_minimized: bool,
    pub close_to_tray: bool,
}

impl Default for Settings {
    fn default() -> Self {
        Settings {
            method: Method::Nudge,
            idle_threshold_secs: 60,
            interval_min_secs: 30,
            interval_max_secs: 90,
            left_click: false,
            prevent_sleep: true,
            keep_display_on: true,
            schedule_enabled: false,
            schedule_start_min: DEFAULT_SCHEDULE_START,
            schedule_end_min: DEFAULT_SCHEDULE_END,
            start_minimized: false,
            close_to_tray: true,
        }
    }
}

impl Settings {
    /// Returns a copy with every value forced into its valid range.
    pub fn normalized(self) -> Settings {
        let interval_min_secs = self.interval_min_secs.clamp(MIN_SECS, MAX_SECS);
        let valid_time = |minute: u16, fallback: u16| if minute < MINUTES_PER_DAY { minute } else { fallback };
        Settings {
            idle_threshold_secs: self.idle_threshold_secs.clamp(MIN_SECS, MAX_SECS),
            interval_min_secs,
            interval_max_secs: self.interval_max_secs.clamp(interval_min_secs, MAX_SECS),
            schedule_start_min: valid_time(self.schedule_start_min, DEFAULT_SCHEDULE_START),
            schedule_end_min: valid_time(self.schedule_end_min, DEFAULT_SCHEDULE_END),
            ..self
        }
    }

    pub fn to_ini(&self) -> String {
        let method = match self.method {
            Method::Nudge => "nudge",
            Method::VisibleMove => "visible_move",
            Method::KeyF15 => "key_f15",
        };
        format!(
            "method={method}\r\n\
             idle_threshold_secs={}\r\n\
             interval_min_secs={}\r\n\
             interval_max_secs={}\r\n\
             left_click={}\r\n\
             prevent_sleep={}\r\n\
             keep_display_on={}\r\n\
             schedule_enabled={}\r\n\
             schedule_start={}\r\n\
             schedule_end={}\r\n\
             start_minimized={}\r\n\
             close_to_tray={}\r\n",
            self.idle_threshold_secs,
            self.interval_min_secs,
            self.interval_max_secs,
            self.left_click,
            self.prevent_sleep,
            self.keep_display_on,
            self.schedule_enabled,
            format_hhmm(self.schedule_start_min),
            format_hhmm(self.schedule_end_min),
            self.start_minimized,
            self.close_to_tray,
        )
    }

    /// Reads `key=value` lines. Unknown keys and unreadable values fall back to defaults.
    pub fn from_ini(text: &str) -> Settings {
        let mut s = Settings::default();
        for line in text.trim_start_matches('\u{feff}').lines() {
            let Some((key, value)) = line.split_once('=') else { continue };
            let value = value.trim();
            match key.trim() {
                "method" => set(&mut s.method, parse_method(value)),
                "idle_threshold_secs" => set(&mut s.idle_threshold_secs, value.parse().ok()),
                "interval_min_secs" => set(&mut s.interval_min_secs, value.parse().ok()),
                "interval_max_secs" => set(&mut s.interval_max_secs, value.parse().ok()),
                "left_click" => set(&mut s.left_click, value.parse().ok()),
                "prevent_sleep" => set(&mut s.prevent_sleep, value.parse().ok()),
                "keep_display_on" => set(&mut s.keep_display_on, value.parse().ok()),
                "schedule_enabled" => set(&mut s.schedule_enabled, value.parse().ok()),
                "schedule_start" => set(&mut s.schedule_start_min, parse_hhmm(value)),
                "schedule_end" => set(&mut s.schedule_end_min, parse_hhmm(value)),
                "start_minimized" => set(&mut s.start_minimized, value.parse().ok()),
                "close_to_tray" => set(&mut s.close_to_tray, value.parse().ok()),
                _ => {}
            }
        }
        s.normalized()
    }
}

/// Parses "8:05", "08:05" or "08.05" into minutes since midnight.
pub fn parse_hhmm(text: &str) -> Option<u16> {
    let (hours, minutes) = text.trim().split_once([':', '.'])?;
    let all_digits = |part: &str| !part.is_empty() && part.len() <= 2 && part.bytes().all(|b| b.is_ascii_digit());
    if !all_digits(hours) || !all_digits(minutes) {
        return None;
    }
    let hours: u16 = hours.parse().ok()?;
    let minutes: u16 = minutes.parse().ok()?;
    (hours < 24 && minutes < 60).then_some(hours * 60 + minutes)
}

pub fn format_hhmm(minute_of_day: u16) -> String {
    format!("{:02}:{:02}", minute_of_day / 60, minute_of_day % 60)
}

fn parse_method(value: &str) -> Option<Method> {
    match value {
        "nudge" => Some(Method::Nudge),
        "visible_move" => Some(Method::VisibleMove),
        "key_f15" => Some(Method::KeyF15),
        _ => None,
    }
}

fn set<T>(field: &mut T, parsed: Option<T>) {
    if let Some(value) = parsed {
        *field = value;
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn defaults_are_unobtrusive() {
        let s = Settings::default();
        assert_eq!(s.method, Method::Nudge);
        assert!(!s.left_click);
        assert_eq!(s.idle_threshold_secs, 60);
        assert_eq!((s.interval_min_secs, s.interval_max_secs), (30, 90));
        assert!(s.prevent_sleep);
        assert!(s.keep_display_on);
        assert!(!s.schedule_enabled);
        assert_eq!((s.schedule_start_min, s.schedule_end_min), (8 * 60, 17 * 60));
        assert!(!s.start_minimized);
        assert!(s.close_to_tray);
    }

    #[test]
    fn defaults_are_already_normalized() {
        assert_eq!(Settings::default().normalized(), Settings::default());
    }

    #[test]
    fn ini_round_trip_preserves_every_field() {
        let s = Settings {
            method: Method::KeyF15,
            idle_threshold_secs: 45,
            interval_min_secs: 20,
            interval_max_secs: 200,
            left_click: true,
            prevent_sleep: false,
            keep_display_on: false,
            schedule_enabled: true,
            schedule_start_min: 7 * 60 + 30,
            schedule_end_min: 16 * 60 + 15,
            start_minimized: true,
            close_to_tray: false,
        };
        assert_eq!(Settings::from_ini(&s.to_ini()), s);
    }

    #[test]
    fn every_method_survives_a_round_trip() {
        for method in [Method::Nudge, Method::VisibleMove, Method::KeyF15] {
            let s = Settings { method, ..Settings::default() };
            assert_eq!(Settings::from_ini(&s.to_ini()).method, method);
        }
    }

    #[test]
    fn empty_file_gives_defaults() {
        assert_eq!(Settings::from_ini(""), Settings::default());
    }

    #[test]
    fn garbage_and_unknown_keys_are_ignored() {
        let text = "\u{feff}# comment\nno equals sign\nunknown=1\nmethod=teleport\nidle_threshold_secs=abc\nleft_click=true\r\n";
        let s = Settings::from_ini(text);
        assert_eq!(s, Settings { left_click: true, ..Settings::default() });
    }

    #[test]
    fn whitespace_around_keys_and_values_is_tolerated() {
        let s = Settings::from_ini("  idle_threshold_secs =  45  \n");
        assert_eq!(s.idle_threshold_secs, 45);
    }

    #[test]
    fn timing_values_are_clamped_when_loading() {
        let s = Settings::from_ini("idle_threshold_secs=0\ninterval_min_secs=9999\ninterval_max_secs=1\n");
        assert_eq!(s.idle_threshold_secs, MIN_SECS);
        assert_eq!(s.interval_min_secs, MAX_SECS);
        assert_eq!(s.interval_max_secs, MAX_SECS);
    }

    #[test]
    fn max_interval_never_ends_up_below_min() {
        let s = Settings { interval_min_secs: 120, interval_max_secs: 40, ..Settings::default() }.normalized();
        assert_eq!((s.interval_min_secs, s.interval_max_secs), (120, 120));
    }

    #[test]
    fn out_of_range_schedule_times_fall_back_to_defaults() {
        let s = Settings { schedule_start_min: 1440, schedule_end_min: 5000, ..Settings::default() }.normalized();
        assert_eq!((s.schedule_start_min, s.schedule_end_min), (8 * 60, 17 * 60));
    }

    #[test]
    fn parses_common_time_spellings() {
        assert_eq!(parse_hhmm("08:00"), Some(480));
        assert_eq!(parse_hhmm("8:05"), Some(485));
        assert_eq!(parse_hhmm(" 17.30 "), Some(17 * 60 + 30));
        assert_eq!(parse_hhmm("0:00"), Some(0));
        assert_eq!(parse_hhmm("23:59"), Some(1439));
    }

    #[test]
    fn rejects_invalid_times() {
        for bad in ["", "8", "24:00", "12:60", "ab:cd", "12:3x", "-1:00", "1:2:3"] {
            assert_eq!(parse_hhmm(bad), None, "{bad:?} should be rejected");
        }
    }

    #[test]
    fn formats_time_with_leading_zeros() {
        assert_eq!(format_hhmm(485), "08:05");
        assert_eq!(format_hhmm(0), "00:00");
        assert_eq!(format_hhmm(1439), "23:59");
    }
}
