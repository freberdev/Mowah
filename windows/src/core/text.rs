//! Every text Mowah shows, in Swedish and in English, and which of the two to use.

use super::engine::Status;
use super::settings::LanguageChoice;

/// The languages Mowah can be shown in.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Language {
    Swedish,
    English,
}

/// The languages' own names, as shown in the language list whatever language is in use.
pub const SWEDISH_NAME: &str = "Svenska";
pub const ENGLISH_NAME: &str = "English";

/// A chosen language is used as it is. Following the system gives Swedish on a
/// Swedish Windows and English on every other.
pub fn resolve(choice: LanguageChoice, system_is_swedish: bool) -> Language {
    match choice {
        LanguageChoice::Swedish => Language::Swedish,
        LanguageChoice::English => Language::English,
        LanguageChoice::System if system_is_swedish => Language::Swedish,
        LanguageChoice::System => Language::English,
    }
}

/// Whether a Windows language identifier means Swedish, in whichever country.
/// The primary language is the low ten bits; the rest names the country.
pub fn is_swedish(language_id: u16) -> bool {
    const PRIMARY_LANGUAGE_MASK: u16 = 0x03FF;
    const LANG_SWEDISH: u16 = 0x1D;
    language_id & PRIMARY_LANGUAGE_MASK == LANG_SWEDISH
}

/// The fixed texts: labels, list entries, buttons and menu items. A text missing
/// in one language is a compile error, since both sets fill in the same fields.
pub struct Texts {
    pub activity: &'static str,
    pub method: &'static str,
    pub method_nudge: &'static str,
    pub method_visible_move: &'static str,
    pub method_key_f15: &'static str,
    pub circle_size: &'static str,
    pub pixels: &'static str,
    pub idle_for: &'static str,
    pub seconds: &'static str,
    pub repeat_every: &'static str,
    pub left_click: &'static str,
    pub keep_awake: &'static str,
    pub prevent_sleep: &'static str,
    pub keep_display_on: &'static str,
    pub schedule: &'static str,
    pub schedule_between: &'static str,
    pub and: &'static str,
    pub program: &'static str,
    pub autostart: &'static str,
    pub start_minimized: &'static str,
    pub close_to_tray: &'static str,
    pub language: &'static str,
    pub follow_system: &'static str,
    pub pause: &'static str,
    pub resume: &'static str,
    pub menu_open: &'static str,
    pub menu_pause_hour: &'static str,
    pub menu_exit: &'static str,
    pub startup_failure: &'static str,
}

const SV: Texts = Texts {
    activity: "Aktivitet",
    method: "Metod",
    method_nudge: "Osynlig musknuff (1 pixel)",
    method_visible_move: "Synlig musrörelse",
    method_key_f15: "Tangenten F15",
    circle_size: "Cirkelns storlek",
    pixels: "pixlar",
    idle_for: "Kör när inaktiv i",
    seconds: "sekunder",
    repeat_every: "Upprepa var",
    left_click: "Vänsterklicka också (där pekaren står)",
    keep_awake: "Håll datorn vaken",
    prevent_sleep: "Förhindra viloläge",
    keep_display_on: "Förhindra att skärmen släcks",
    schedule: "Schema",
    schedule_between: "Bara mån–fre mellan",
    and: "och",
    program: "Program",
    autostart: "Starta med Windows",
    start_minimized: "Starta minimerad i systemfältet",
    close_to_tray: "Stäng-knappen minimerar till systemfältet",
    language: "Språk",
    follow_system: "Följ systemet",
    pause: "Pausa",
    resume: "Återuppta",
    menu_open: "Öppna Mowah",
    menu_pause_hour: "Pausa i 1 timme",
    menu_exit: "Avsluta",
    startup_failure: "Mowah kunde inte starta.",
};

const EN: Texts = Texts {
    activity: "Activity",
    method: "Method",
    method_nudge: "Invisible nudge (1 pixel)",
    method_visible_move: "Visible pointer movement",
    method_key_f15: "The F15 key",
    circle_size: "Circle size",
    pixels: "pixels",
    idle_for: "Start after being idle for",
    seconds: "seconds",
    repeat_every: "Repeat every",
    left_click: "Also left-click (where the pointer is)",
    keep_awake: "Keep the computer awake",
    prevent_sleep: "Prevent sleep",
    keep_display_on: "Keep the display on",
    schedule: "Schedule",
    schedule_between: "Only Mon–Fri between",
    and: "and",
    program: "Program",
    autostart: "Start with Windows",
    start_minimized: "Start minimized in the system tray",
    close_to_tray: "The close button minimizes to the system tray",
    language: "Language",
    follow_system: "Follow system",
    pause: "Pause",
    resume: "Resume",
    menu_open: "Open Mowah",
    menu_pause_hour: "Pause for 1 hour",
    menu_exit: "Exit",
    startup_failure: "Mowah could not start.",
};

pub fn texts(language: Language) -> &'static Texts {
    match language {
        Language::Swedish => &SV,
        Language::English => &EN,
    }
}

impl Texts {
    /// Every text in the set, for checks that concern them all.
    #[cfg(test)]
    pub fn all(&self) -> [&'static str; 29] {
        [
            self.activity,
            self.method,
            self.method_nudge,
            self.method_visible_move,
            self.method_key_f15,
            self.circle_size,
            self.pixels,
            self.idle_for,
            self.seconds,
            self.repeat_every,
            self.left_click,
            self.keep_awake,
            self.prevent_sleep,
            self.keep_display_on,
            self.schedule,
            self.schedule_between,
            self.and,
            self.program,
            self.autostart,
            self.start_minimized,
            self.close_to_tray,
            self.language,
            self.follow_system,
            self.pause,
            self.resume,
            self.menu_open,
            self.menu_pause_hour,
            self.menu_exit,
            self.startup_failure,
        ]
    }
}

/// The main status line in the window. `pause_end` is the clock time a timed pause ends.
pub fn headline(language: Language, status: Status, user_idle_ms: u64, pause_end: Option<&str>) -> String {
    use Language::{English, Swedish};
    let text = match (status, pause_end, language) {
        (Status::PausedUntil, Some(end), Swedish) => return format!("Pausad till {end}"),
        (Status::PausedUntil, Some(end), English) => return format!("Paused until {end}"),
        (Status::Paused | Status::PausedUntil, _, Swedish) => "Pausad",
        (Status::Paused | Status::PausedUntil, _, English) => "Paused",
        (Status::OutsideSchedule, _, Swedish) => "Vilar – utanför schemat",
        (Status::OutsideSchedule, _, English) => "Resting – outside the schedule",
        (Status::Locked, _, Swedish) => "Vilar – datorn är låst",
        (Status::Locked, _, English) => "Resting – the computer is locked",
        (Status::UserActive, _, Swedish) => "Redo – väntar på att du blir inaktiv",
        (Status::UserActive, _, English) => "Ready – waiting for you to go idle",
        (Status::KeepingAlive, _, Swedish) => {
            return format!("Håller dig online – du har varit borta i {}", duration(user_idle_ms));
        }
        (Status::KeepingAlive, _, English) => {
            return format!("Keeping you online – you have been away for {}", duration(user_idle_ms));
        }
    };
    text.to_string()
}

/// The tooltip on the tray icon.
pub fn tray_tip(language: Language, status: Status) -> &'static str {
    use Language::{English, Swedish};
    match (status, language) {
        (Status::UserActive | Status::KeepingAlive, Swedish) => "Mowah – aktiv",
        (Status::UserActive | Status::KeepingAlive, English) => "Mowah – active",
        (Status::Paused | Status::PausedUntil, Swedish) => "Mowah – pausad",
        (Status::Paused | Status::PausedUntil, English) => "Mowah – paused",
        (Status::OutsideSchedule | Status::Locked, Swedish) => "Mowah – vilar",
        (Status::OutsideSchedule | Status::Locked, English) => "Mowah – resting",
    }
}

/// The line under the headline. `last_action` is the clock time of the latest action.
pub fn last_action_line(language: Language, last_action: Option<&str>) -> String {
    match (last_action, language) {
        (Some(time), Language::Swedish) => format!("Senaste åtgärd {time}"),
        (Some(time), Language::English) => format!("Last action {time}"),
        (None, Language::Swedish) => "Ingen åtgärd ännu".to_string(),
        (None, Language::English) => "No action yet".to_string(),
    }
}

/// The line at the bottom of the window: which version this is and who made it.
pub fn footer(version: &str, year: &str, company: &str) -> String {
    format!("Mowah {version} · © {year} {company}")
}

/// The units are written the same way in both languages.
fn duration(ms: u64) -> String {
    let secs = ms / 1_000;
    let mins = secs / 60;
    if secs < 60 {
        format!("{secs} s")
    } else if mins < 60 {
        format!("{mins} min")
    } else {
        format!("{} h {} min", mins / 60, mins % 60)
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use Language::{English as En, Swedish as Sv};

    #[test]
    fn the_choice_decides_the_language_unless_it_follows_the_system() {
        assert_eq!(resolve(LanguageChoice::Swedish, false), Language::Swedish);
        assert_eq!(resolve(LanguageChoice::English, true), Language::English);
        assert_eq!(resolve(LanguageChoice::System, true), Language::Swedish);
        assert_eq!(resolve(LanguageChoice::System, false), Language::English);
    }

    #[test]
    fn swedish_is_recognised_whatever_the_country() {
        assert!(is_swedish(0x041D)); // Sweden
        assert!(is_swedish(0x081D)); // Finland
        assert!(!is_swedish(0x0409)); // English
        assert!(!is_swedish(0x0407)); // German
        assert!(!is_swedish(0));
    }

    #[test]
    fn no_text_is_empty_in_either_language() {
        for language in [Sv, En] {
            for text in texts(language).all() {
                assert!(!text.trim().is_empty(), "{language:?} has an empty text");
            }
        }
    }

    #[test]
    fn the_two_languages_differ_except_where_the_word_is_the_same() {
        let (sv, en) = (texts(Sv), texts(En));
        assert_ne!(sv.pause, en.pause);
        assert_ne!(sv.language, en.language);
        assert_eq!(sv.program, en.program);
    }

    #[test]
    fn the_language_names_are_never_translated() {
        assert_eq!(SWEDISH_NAME, "Svenska");
        assert_eq!(ENGLISH_NAME, "English");
    }

    #[test]
    fn working_user_sees_that_mowah_is_waiting() {
        assert_eq!(headline(Sv, Status::UserActive, 12_000, None), "Redo – väntar på att du blir inaktiv");
    }

    #[test]
    fn away_time_is_shown_in_seconds_under_a_minute() {
        assert_eq!(headline(Sv, Status::KeepingAlive, 59_999, None), "Håller dig online – du har varit borta i 59 s");
    }

    #[test]
    fn away_time_is_shown_in_whole_minutes() {
        assert_eq!(headline(Sv, Status::KeepingAlive, 60_000, None), "Håller dig online – du har varit borta i 1 min");
        assert_eq!(headline(Sv, Status::KeepingAlive, 3_599_000, None), "Håller dig online – du har varit borta i 59 min");
    }

    #[test]
    fn away_time_is_shown_in_hours_and_minutes() {
        assert_eq!(
            headline(Sv, Status::KeepingAlive, 3_600_000, None),
            "Håller dig online – du har varit borta i 1 h 0 min"
        );
        assert_eq!(
            headline(Sv, Status::KeepingAlive, 9_000_000, None),
            "Håller dig online – du har varit borta i 2 h 30 min"
        );
    }

    #[test]
    fn manual_pause_has_no_end_time() {
        assert_eq!(headline(Sv, Status::Paused, 0, None), "Pausad");
        assert_eq!(headline(Sv, Status::Paused, 0, Some("11:42")), "Pausad");
        assert_eq!(headline(En, Status::Paused, 0, Some("11:42")), "Paused");
    }

    #[test]
    fn timed_pause_shows_when_it_ends() {
        assert_eq!(headline(Sv, Status::PausedUntil, 0, Some("11:42")), "Pausad till 11:42");
        assert_eq!(headline(Sv, Status::PausedUntil, 0, None), "Pausad");
        assert_eq!(headline(En, Status::PausedUntil, 0, None), "Paused");
    }

    #[test]
    fn resting_states_say_why() {
        assert_eq!(headline(Sv, Status::OutsideSchedule, 0, None), "Vilar – utanför schemat");
        assert_eq!(headline(Sv, Status::Locked, 0, None), "Vilar – datorn är låst");
    }

    #[test]
    fn tray_tip_names_the_state() {
        assert_eq!(tray_tip(Sv, Status::UserActive), "Mowah – aktiv");
        assert_eq!(tray_tip(Sv, Status::KeepingAlive), "Mowah – aktiv");
        assert_eq!(tray_tip(Sv, Status::Paused), "Mowah – pausad");
        assert_eq!(tray_tip(Sv, Status::PausedUntil), "Mowah – pausad");
        assert_eq!(tray_tip(Sv, Status::OutsideSchedule), "Mowah – vilar");
        assert_eq!(tray_tip(Sv, Status::Locked), "Mowah – vilar");
    }

    #[test]
    fn english_status_matches_the_mac_app() {
        assert_eq!(headline(En, Status::UserActive, 0, None), "Ready – waiting for you to go idle");
        assert_eq!(
            headline(En, Status::KeepingAlive, 59_999, None),
            "Keeping you online – you have been away for 59 s"
        );
        assert_eq!(headline(En, Status::Paused, 0, None), "Paused");
        assert_eq!(headline(En, Status::PausedUntil, 0, Some("11:42")), "Paused until 11:42");
        assert_eq!(headline(En, Status::OutsideSchedule, 0, None), "Resting – outside the schedule");
        assert_eq!(headline(En, Status::Locked, 0, None), "Resting – the computer is locked");
        assert_eq!(last_action_line(En, Some("10:42")), "Last action 10:42");
        assert_eq!(last_action_line(En, None), "No action yet");
        assert_eq!(tray_tip(En, Status::KeepingAlive), "Mowah – active");
        assert_eq!(tray_tip(En, Status::Paused), "Mowah – paused");
        assert_eq!(tray_tip(En, Status::Locked), "Mowah – resting");
    }

    #[test]
    fn footer_names_the_version_the_year_and_the_company() {
        assert_eq!(footer("1.0.0", "2026", "freber dev AB"), "Mowah 1.0.0 · © 2026 freber dev AB");
    }

    #[test]
    fn last_action_line_shows_the_time_or_that_nothing_happened() {
        assert_eq!(last_action_line(Sv, Some("10:42")), "Senaste åtgärd 10:42");
        assert_eq!(last_action_line(Sv, None), "Ingen åtgärd ännu");
    }
}
