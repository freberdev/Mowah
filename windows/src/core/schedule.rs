use super::settings::Settings;

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct LocalTime {
    /// 0 = Sunday … 6 = Saturday, the same numbering Windows uses.
    pub weekday: u8,
    pub minute_of_day: u16,
}

/// True when Mowah is allowed to work at `now`. With the schedule switched off
/// that is always; otherwise Monday–Friday between the start and end time. An end
/// time earlier than the start means a shift that runs past midnight.
pub fn is_within_schedule(settings: &Settings, now: LocalTime) -> bool {
    if !settings.schedule_enabled {
        return true;
    }
    let start = settings.schedule_start_min;
    let end = settings.schedule_end_min;
    let minute = now.minute_of_day;
    let today = now.weekday % 7;
    let yesterday = (today + 6) % 7;

    if start == end {
        is_workday(today)
    } else if start < end {
        is_workday(today) && minute >= start && minute < end
    } else {
        (is_workday(today) && minute >= start) || (is_workday(yesterday) && minute < end)
    }
}

fn is_workday(weekday: u8) -> bool {
    (1..=5).contains(&weekday)
}

#[cfg(test)]
mod tests {
    use super::*;

    const SUN: u8 = 0;
    const MON: u8 = 1;
    const FRI: u8 = 5;
    const SAT: u8 = 6;

    fn at(weekday: u8, hour: u16, minute: u16) -> LocalTime {
        LocalTime { weekday, minute_of_day: hour * 60 + minute }
    }

    fn office_hours() -> Settings {
        Settings { schedule_enabled: true, ..Settings::default() }
    }

    fn night_shift() -> Settings {
        Settings {
            schedule_enabled: true,
            schedule_start_min: 22 * 60,
            schedule_end_min: 6 * 60,
            ..Settings::default()
        }
    }

    #[test]
    fn disabled_schedule_allows_any_time() {
        let s = Settings { schedule_enabled: false, ..Settings::default() };
        assert!(is_within_schedule(&s, at(SUN, 3, 0)));
        assert!(is_within_schedule(&s, at(SAT, 23, 59)));
    }

    #[test]
    fn weekday_inside_hours_is_allowed() {
        assert!(is_within_schedule(&office_hours(), at(MON, 9, 0)));
        assert!(is_within_schedule(&office_hours(), at(FRI, 16, 59)));
    }

    #[test]
    fn start_is_inclusive_and_end_is_exclusive() {
        assert!(is_within_schedule(&office_hours(), at(MON, 8, 0)));
        assert!(!is_within_schedule(&office_hours(), at(MON, 7, 59)));
        assert!(!is_within_schedule(&office_hours(), at(MON, 17, 0)));
    }

    #[test]
    fn weekends_are_outside_schedule() {
        assert!(!is_within_schedule(&office_hours(), at(SAT, 10, 0)));
        assert!(!is_within_schedule(&office_hours(), at(SUN, 10, 0)));
    }

    #[test]
    fn night_shift_covers_both_sides_of_midnight() {
        assert!(is_within_schedule(&night_shift(), at(MON, 23, 0)));
        assert!(is_within_schedule(&night_shift(), at(FRI, 5, 59)));
        assert!(!is_within_schedule(&night_shift(), at(MON, 12, 0)));
        assert!(!is_within_schedule(&night_shift(), at(MON, 6, 0)));
    }

    #[test]
    fn night_shift_belongs_to_the_day_it_started() {
        // Friday's shift runs into Saturday morning; Sunday's never started.
        assert!(is_within_schedule(&night_shift(), at(SAT, 1, 0)));
        assert!(!is_within_schedule(&night_shift(), at(MON, 1, 0)));
        assert!(!is_within_schedule(&night_shift(), at(SAT, 23, 0)));
    }

    #[test]
    fn equal_start_and_end_means_the_whole_weekday() {
        let s = Settings {
            schedule_enabled: true,
            schedule_start_min: 8 * 60,
            schedule_end_min: 8 * 60,
            ..Settings::default()
        };
        assert!(is_within_schedule(&s, at(MON, 3, 0)));
        assert!(is_within_schedule(&s, at(FRI, 23, 0)));
        assert!(!is_within_schedule(&s, at(SAT, 12, 0)));
    }
}
