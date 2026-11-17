//! Resource and control IDs. Must match the `#define`s in res/mowah.rc.

pub const IDI_APP: u16 = 1;
pub const IDI_PAUSED: u16 = 2;
pub const IDD_MAIN: u16 = 100;

pub const IDC_STATUS: i32 = 1001;
pub const IDC_LAST_ACTION: i32 = 1002;
pub const IDC_PAUSE: i32 = 1003;
pub const IDC_GRP_ACTIVITY: i32 = 1010;
pub const IDC_LBL_METHOD: i32 = 1011;
pub const IDC_METHOD: i32 = 1012;
pub const IDC_LBL_IDLE: i32 = 1013;
pub const IDC_IDLE: i32 = 1014;
pub const IDC_LBL_IDLE_UNIT: i32 = 1015;
pub const IDC_LBL_INTERVAL: i32 = 1016;
pub const IDC_INTERVAL_MIN: i32 = 1017;
pub const IDC_LBL_DASH: i32 = 1018;
pub const IDC_INTERVAL_MAX: i32 = 1019;
pub const IDC_LBL_INT_UNIT: i32 = 1020;
pub const IDC_CLICK: i32 = 1021;
pub const IDC_LBL_CIRCLE: i32 = 1022;
pub const IDC_CIRCLE: i32 = 1023;
pub const IDC_LBL_CIRCLE_UNIT: i32 = 1024;
pub const IDC_GRP_AWAKE: i32 = 1030;
pub const IDC_PREVENT_SLEEP: i32 = 1031;
pub const IDC_KEEP_DISPLAY: i32 = 1032;
pub const IDC_GRP_SCHEDULE: i32 = 1040;
pub const IDC_SCHEDULE: i32 = 1041;
pub const IDC_SCHEDULE_FROM: i32 = 1042;
pub const IDC_LBL_AND: i32 = 1043;
pub const IDC_SCHEDULE_TO: i32 = 1044;
pub const IDC_GRP_PROGRAM: i32 = 1050;
pub const IDC_AUTOSTART: i32 = 1051;
pub const IDC_START_MINIMIZED: i32 = 1052;
pub const IDC_CLOSE_TO_TRAY: i32 = 1053;
pub const IDC_LBL_LANGUAGE: i32 = 1054;
pub const IDC_LANGUAGE: i32 = 1055;
pub const IDC_FOOTER: i32 = 1060;

/// Tray menu commands.
pub const IDM_OPEN: usize = 2001;
pub const IDM_TOGGLE_PAUSE: usize = 2002;
pub const IDM_PAUSE_HOUR: usize = 2003;
pub const IDM_EXIT: usize = 2004;
