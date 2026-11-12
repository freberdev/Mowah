use super::rng::Rng;
use super::schedule::{is_within_schedule, LocalTime};
use super::settings::Settings;

/// Input that arrives within this long after one of Mowah's own actions is taken
/// to be that action, not the user. The slowest action, the visible pointer loop,
/// takes about half a second. Erring short is the safe side: if Mowah mistakes its
/// own input for the user it merely waits one idle threshold before acting again.
pub const OWN_INPUT_WINDOW_MS: u64 = 1_000;

/// Everything the engine needs to know about the outside world for one tick.
#[derive(Clone, Copy, Debug)]
pub struct TickInput {
    /// Monotonic clock in milliseconds.
    pub now_ms: u64,
    /// Time since Windows last saw any input, including input Mowah injected.
    pub system_idle_ms: u64,
    pub local: LocalTime,
    pub locked: bool,
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub enum Status {
    /// Paused by the user until they resume.
    Paused,
    /// Paused by the user for a fixed time.
    PausedUntil,
    OutsideSchedule,
    /// The Windows session is locked.
    Locked,
    /// Armed, but the user is working so nothing is injected.
    UserActive,
    /// The user is away and Mowah is producing activity.
    KeepingAlive,
}

impl Status {
    /// True when Mowah is on duty, whether or not it is injecting input right now.
    pub fn is_armed(self) -> bool {
        matches!(self, Status::UserActive | Status::KeepingAlive)
    }
}

/// What Windows should be asked to keep awake in a given state.
#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct KeepAwake {
    pub system: bool,
    pub display: bool,
}

pub fn keep_awake(status: Status, settings: &Settings) -> KeepAwake {
    // A locked computer keeps running so work in progress survives, but nobody is
    // looking at the screen.
    KeepAwake {
        system: settings.prevent_sleep && (status.is_armed() || status == Status::Locked),
        display: settings.keep_display_on && status.is_armed(),
    }
}

#[derive(Clone, Copy, Debug, PartialEq, Eq)]
pub struct Outcome {
    pub status: Status,
    /// True when the caller should perform one activity action now.
    pub act: bool,
    /// How long the real user has been away, ignoring Mowah's own input.
    pub user_idle_ms: u64,
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Pause {
    None,
    Manual,
    Until(u64),
}

pub struct Engine {
    rng: Rng,
    pause: Pause,
    /// Timestamp of the newest system input already accounted for.
    last_input_seen_ms: Option<u64>,
    /// When the real user last touched mouse or keyboard.
    user_last_active_ms: u64,
    /// When Mowah last asked for an action; input right after this is its own.
    own_action_ms: Option<u64>,
    next_action_ms: Option<u64>,
}

impl Engine {
    pub fn new(seed: u64) -> Self {
        Engine {
            rng: Rng::new(seed),
            pause: Pause::None,
            last_input_seen_ms: None,
            user_last_active_ms: 0,
            own_action_ms: None,
            next_action_ms: None,
        }
    }

    pub fn tick(&mut self, settings: &Settings, input: &TickInput) -> Outcome {
        let now = input.now_ms;
        self.note_system_input(now.saturating_sub(input.system_idle_ms));
        let user_idle_ms = now.saturating_sub(self.user_last_active_ms);

        if let Pause::Until(deadline) = self.pause {
            if now >= deadline {
                self.pause = Pause::None;
            }
        }

        let status = match self.pause {
            Pause::Manual => Status::Paused,
            Pause::Until(_) => Status::PausedUntil,
            Pause::None if input.locked => Status::Locked,
            Pause::None if !is_within_schedule(settings, input.local) => Status::OutsideSchedule,
            Pause::None if user_idle_ms < u64::from(settings.idle_threshold_secs) * 1_000 => Status::UserActive,
            Pause::None => Status::KeepingAlive,
        };

        if status != Status::KeepingAlive {
            // Forget the cadence so the next away period starts with an immediate action.
            self.next_action_ms = None;
            return Outcome { status, act: false, user_idle_ms };
        }

        let act = self.next_action_ms.map_or(true, |due| now >= due);
        if act {
            let wait_secs = self
                .rng
                .range_inclusive(settings.interval_min_secs.into(), settings.interval_max_secs.into());
            self.own_action_ms = Some(now);
            self.next_action_ms = Some(now + wait_secs * 1_000);
        }
        Outcome { status, act, user_idle_ms }
    }

    /// Decides whether newly observed system input came from the user or from Mowah.
    fn note_system_input(&mut self, input_ms: u64) {
        if self.last_input_seen_ms.is_some_and(|seen| input_ms <= seen) {
            return;
        }
        self.last_input_seen_ms = Some(input_ms);
        let is_own = self
            .own_action_ms
            .is_some_and(|acted| input_ms >= acted && input_ms - acted <= OWN_INPUT_WINDOW_MS);
        if !is_own {
            self.user_last_active_ms = input_ms;
        }
    }

    pub fn pause(&mut self) {
        self.pause = Pause::Manual;
    }

    pub fn pause_until(&mut self, deadline_ms: u64) {
        self.pause = Pause::Until(deadline_ms);
    }

    pub fn resume(&mut self) {
        self.pause = Pause::None;
    }

    pub fn is_paused(&self) -> bool {
        self.pause != Pause::None
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    const MONDAY_NOON: LocalTime = LocalTime { weekday: 1, minute_of_day: 12 * 60 };
    const SATURDAY_NOON: LocalTime = LocalTime { weekday: 6, minute_of_day: 12 * 60 };

    /// Drives the engine the way the Windows layer does: one tick per second, and
    /// every action the engine asks for shows up as fresh system input shortly after.
    struct Sim {
        engine: Engine,
        settings: Settings,
        now_ms: u64,
        last_input_ms: u64,
        local: LocalTime,
        locked: bool,
        action_times: Vec<u64>,
    }

    impl Sim {
        fn new(settings: Settings) -> Self {
            Sim {
                engine: Engine::new(1),
                settings,
                now_ms: 1_000_000,
                last_input_ms: 1_000_000,
                local: MONDAY_NOON,
                locked: false,
                action_times: Vec::new(),
            }
        }

        fn with_seed(mut self, seed: u64) -> Self {
            self.engine = Engine::new(seed);
            self
        }

        fn user_input(&mut self) {
            self.last_input_ms = self.now_ms;
        }

        fn tick(&mut self) -> Outcome {
            let outcome = self.engine.tick(
                &self.settings,
                &TickInput {
                    now_ms: self.now_ms,
                    system_idle_ms: self.now_ms - self.last_input_ms,
                    local: self.local,
                    locked: self.locked,
                },
            );
            if outcome.act {
                self.action_times.push(self.now_ms);
                self.last_input_ms = self.now_ms + 15;
            }
            outcome
        }

        /// Advances one second at a time, ticking after each step. Returns the last outcome.
        fn run_secs(&mut self, secs: u64) -> Outcome {
            let mut last = None;
            for _ in 0..secs {
                self.now_ms += 1_000;
                last = Some(self.tick());
            }
            last.expect("run_secs needs at least one second")
        }
    }

    fn fixed_interval(secs: u32) -> Settings {
        Settings { interval_min_secs: secs, interval_max_secs: secs, ..Settings::default() }
    }

    #[test]
    fn does_nothing_while_the_user_is_working() {
        let mut sim = Sim::new(Settings::default());
        for _ in 0..600 {
            sim.now_ms += 1_000;
            sim.user_input();
            let outcome = sim.tick();
            assert_eq!(outcome.status, Status::UserActive);
        }
        assert!(sim.action_times.is_empty());
    }

    #[test]
    fn stays_quiet_until_the_idle_threshold_is_reached() {
        let mut sim = Sim::new(Settings::default());
        let outcome = sim.run_secs(59);
        assert_eq!(outcome.status, Status::UserActive);
        assert!(sim.action_times.is_empty());
    }

    #[test]
    fn acts_as_soon_as_the_user_has_been_idle_for_the_threshold() {
        let mut sim = Sim::new(Settings::default());
        let outcome = sim.run_secs(60);
        assert_eq!(outcome.status, Status::KeepingAlive);
        assert!(outcome.act);
        assert_eq!(sim.action_times, vec![1_060_000]);
    }

    #[test]
    fn repeats_at_the_configured_interval_while_the_user_is_away() {
        let mut sim = Sim::new(fixed_interval(30));
        sim.run_secs(60 + 95);
        assert_eq!(sim.action_times, vec![1_060_000, 1_090_000, 1_120_000, 1_150_000]);
    }

    #[test]
    fn its_own_input_does_not_count_as_the_user_returning() {
        let mut sim = Sim::new(fixed_interval(30));
        let outcome = sim.run_secs(300);
        assert_eq!(outcome.status, Status::KeepingAlive);
        assert_eq!(outcome.user_idle_ms, 300_000);
    }

    #[test]
    fn random_interval_stays_within_the_configured_range() {
        for seed in 1..=20 {
            let settings = Settings { interval_min_secs: 30, interval_max_secs: 90, ..Settings::default() };
            let mut sim = Sim::new(settings).with_seed(seed);
            sim.run_secs(3_600);
            assert!(sim.action_times.len() > 10);
            for pair in sim.action_times.windows(2) {
                let gap = pair[1] - pair[0];
                assert!((30_000..=90_000).contains(&gap), "seed {seed}: gap {gap} ms outside 30–90 s");
            }
        }
    }

    #[test]
    fn random_interval_actually_varies() {
        let settings = Settings { interval_min_secs: 30, interval_max_secs: 90, ..Settings::default() };
        let mut sim = Sim::new(settings);
        sim.run_secs(3_600);
        let gaps: Vec<u64> = sim.action_times.windows(2).map(|p| p[1] - p[0]).collect();
        assert!(gaps.iter().any(|g| *g != gaps[0]));
    }

    #[test]
    fn stops_the_moment_the_user_comes_back() {
        let mut sim = Sim::new(fixed_interval(30));
        sim.run_secs(70);
        assert_eq!(sim.action_times.len(), 1);

        sim.now_ms += 5_000;
        sim.user_input();
        let outcome = sim.tick();
        assert_eq!(outcome.status, Status::UserActive);
        assert_eq!(outcome.user_idle_ms, 0);

        sim.run_secs(59);
        assert_eq!(sim.action_times.len(), 1, "must wait a full idle threshold again");
        sim.run_secs(1);
        assert_eq!(sim.action_times.len(), 2);
    }

    #[test]
    fn user_input_long_after_an_action_is_recognised_as_the_user() {
        let mut sim = Sim::new(fixed_interval(200));
        sim.run_secs(60);
        sim.now_ms += OWN_INPUT_WINDOW_MS + 1_000;
        sim.user_input();
        assert_eq!(sim.tick().status, Status::UserActive);
    }

    #[test]
    fn user_input_a_second_and_a_half_after_an_action_is_the_user() {
        let mut sim = Sim::new(fixed_interval(200));
        sim.run_secs(60);
        sim.now_ms += 1_500;
        sim.user_input();
        assert_eq!(sim.tick().status, Status::UserActive);
    }

    #[test]
    fn idle_time_from_before_startup_counts() {
        let mut sim = Sim::new(Settings::default());
        sim.last_input_ms = sim.now_ms - 120_000;
        let outcome = sim.tick();
        assert!(outcome.act);
        assert_eq!(outcome.user_idle_ms, 120_000);
    }

    #[test]
    fn manual_pause_blocks_actions_until_resumed() {
        let mut sim = Sim::new(Settings::default());
        sim.engine.pause();
        assert!(sim.engine.is_paused());
        let outcome = sim.run_secs(600);
        assert_eq!(outcome.status, Status::Paused);
        assert!(sim.action_times.is_empty());

        sim.engine.resume();
        assert!(!sim.engine.is_paused());
        let outcome = sim.run_secs(1);
        assert!(outcome.act, "the user is long idle, so it acts right after resuming");
    }

    #[test]
    fn timed_pause_ends_by_itself() {
        let mut sim = Sim::new(Settings::default());
        sim.engine.pause_until(sim.now_ms + 3_600_000);
        let outcome = sim.run_secs(3_599);
        assert_eq!(outcome.status, Status::PausedUntil);
        assert!(sim.engine.is_paused());
        assert!(sim.action_times.is_empty());

        let outcome = sim.run_secs(1);
        assert_eq!(outcome.status, Status::KeepingAlive);
        assert!(outcome.act);
        assert!(!sim.engine.is_paused());
    }

    #[test]
    fn locked_session_blocks_actions() {
        let mut sim = Sim::new(Settings::default());
        sim.locked = true;
        let outcome = sim.run_secs(600);
        assert_eq!(outcome.status, Status::Locked);
        assert!(sim.action_times.is_empty());
    }

    #[test]
    fn nothing_happens_outside_the_schedule() {
        let mut sim = Sim::new(Settings { schedule_enabled: true, ..Settings::default() });
        sim.local = SATURDAY_NOON;
        let outcome = sim.run_secs(600);
        assert_eq!(outcome.status, Status::OutsideSchedule);
        assert!(sim.action_times.is_empty());

        sim.local = MONDAY_NOON;
        assert!(sim.run_secs(1).act);
    }

    #[test]
    fn user_activity_is_still_tracked_while_paused() {
        let mut sim = Sim::new(Settings::default());
        sim.engine.pause();
        sim.run_secs(600);
        sim.user_input();
        sim.run_secs(10);
        sim.engine.resume();
        let outcome = sim.run_secs(1);
        assert_eq!(outcome.status, Status::UserActive);
        assert_eq!(outcome.user_idle_ms, 11_000);
        assert!(sim.action_times.is_empty());
    }

    #[test]
    fn pause_reports_paused_even_when_also_locked_or_off_schedule() {
        let mut sim = Sim::new(Settings { schedule_enabled: true, ..Settings::default() });
        sim.local = SATURDAY_NOON;
        sim.locked = true;
        sim.engine.pause();
        assert_eq!(sim.run_secs(1).status, Status::Paused);
    }

    #[test]
    fn only_on_duty_statuses_are_armed() {
        assert!(Status::UserActive.is_armed());
        assert!(Status::KeepingAlive.is_armed());
        for status in [Status::Paused, Status::PausedUntil, Status::OutsideSchedule, Status::Locked] {
            assert!(!status.is_armed());
        }
    }

    #[test]
    fn on_duty_keeps_system_and_display_awake() {
        for status in [Status::UserActive, Status::KeepingAlive] {
            assert_eq!(keep_awake(status, &Settings::default()), KeepAwake { system: true, display: true });
        }
    }

    #[test]
    fn keep_awake_follows_each_setting_separately() {
        let only_system = Settings { keep_display_on: false, ..Settings::default() };
        assert_eq!(keep_awake(Status::UserActive, &only_system), KeepAwake { system: true, display: false });
        let only_display = Settings { prevent_sleep: false, ..Settings::default() };
        assert_eq!(keep_awake(Status::UserActive, &only_display), KeepAwake { system: false, display: true });
    }

    #[test]
    fn paused_or_off_schedule_lets_the_computer_sleep() {
        for status in [Status::Paused, Status::PausedUntil, Status::OutsideSchedule] {
            assert_eq!(keep_awake(status, &Settings::default()), KeepAwake { system: false, display: false });
        }
    }

    #[test]
    fn locked_computer_stays_awake_but_may_turn_off_the_screen() {
        assert_eq!(keep_awake(Status::Locked, &Settings::default()), KeepAwake { system: true, display: false });
        let sleep_allowed = Settings { prevent_sleep: false, ..Settings::default() };
        assert_eq!(keep_awake(Status::Locked, &sleep_allowed), KeepAwake { system: false, display: false });
    }
}
