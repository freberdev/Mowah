//! The Swedish wording of the status shown in the window and in the tray.

use super::engine::Status;

/// The main status line in the window. `pause_end` is the clock time a timed pause ends.
pub fn headline(status: Status, user_idle_ms: u64, pause_end: Option<&str>) -> String {
    match (status, pause_end) {
        (Status::PausedUntil, Some(end)) => format!("Pausad till {end}"),
        (Status::Paused | Status::PausedUntil, _) => "Pausad".to_string(),
        (Status::OutsideSchedule, _) => "Vilar – utanför schemat".to_string(),
        (Status::Locked, _) => "Vilar – datorn är låst".to_string(),
        (Status::UserActive, _) => "Redo – väntar på att du blir inaktiv".to_string(),
        (Status::KeepingAlive, _) => {
            format!("Håller dig online – du har varit borta i {}", duration(user_idle_ms))
        }
    }
}

/// The tooltip on the tray icon.
pub fn tray_tip(status: Status) -> &'static str {
    match status {
        Status::UserActive | Status::KeepingAlive => "Mowah – aktiv",
        Status::Paused | Status::PausedUntil => "Mowah – pausad",
        Status::OutsideSchedule | Status::Locked => "Mowah – vilar",
    }
}

/// The line under the headline. `last_action` is the clock time of the latest action.
pub fn last_action_line(last_action: Option<&str>) -> String {
    match last_action {
        Some(time) => format!("Senaste åtgärd {time}"),
        None => "Ingen åtgärd ännu".to_string(),
    }
}

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

    #[test]
    fn working_user_sees_that_mowah_is_waiting() {
        assert_eq!(headline(Status::UserActive, 12_000, None), "Redo – väntar på att du blir inaktiv");
    }

    #[test]
    fn away_time_is_shown_in_seconds_under_a_minute() {
        assert_eq!(headline(Status::KeepingAlive, 59_999, None), "Håller dig online – du har varit borta i 59 s");
    }

    #[test]
    fn away_time_is_shown_in_whole_minutes() {
        assert_eq!(headline(Status::KeepingAlive, 60_000, None), "Håller dig online – du har varit borta i 1 min");
        assert_eq!(headline(Status::KeepingAlive, 3_599_000, None), "Håller dig online – du har varit borta i 59 min");
    }

    #[test]
    fn away_time_is_shown_in_hours_and_minutes() {
        assert_eq!(headline(Status::KeepingAlive, 3_600_000, None), "Håller dig online – du har varit borta i 1 h 0 min");
        assert_eq!(headline(Status::KeepingAlive, 9_000_000, None), "Håller dig online – du har varit borta i 2 h 30 min");
    }

    #[test]
    fn manual_pause_has_no_end_time() {
        assert_eq!(headline(Status::Paused, 0, None), "Pausad");
        assert_eq!(headline(Status::Paused, 0, Some("11:42")), "Pausad");
    }

    #[test]
    fn timed_pause_shows_when_it_ends() {
        assert_eq!(headline(Status::PausedUntil, 0, Some("11:42")), "Pausad till 11:42");
        assert_eq!(headline(Status::PausedUntil, 0, None), "Pausad");
    }

    #[test]
    fn resting_states_say_why() {
        assert_eq!(headline(Status::OutsideSchedule, 0, None), "Vilar – utanför schemat");
        assert_eq!(headline(Status::Locked, 0, None), "Vilar – datorn är låst");
    }

    #[test]
    fn tray_tip_names_the_state() {
        assert_eq!(tray_tip(Status::UserActive), "Mowah – aktiv");
        assert_eq!(tray_tip(Status::KeepingAlive), "Mowah – aktiv");
        assert_eq!(tray_tip(Status::Paused), "Mowah – pausad");
        assert_eq!(tray_tip(Status::PausedUntil), "Mowah – pausad");
        assert_eq!(tray_tip(Status::OutsideSchedule), "Mowah – vilar");
        assert_eq!(tray_tip(Status::Locked), "Mowah – vilar");
    }

    #[test]
    fn last_action_line_shows_the_time_or_that_nothing_happened() {
        assert_eq!(last_action_line(Some("10:42")), "Senaste åtgärd 10:42");
        assert_eq!(last_action_line(None), "Ingen åtgärd ännu");
    }
}
