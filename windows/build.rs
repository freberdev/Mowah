use std::env;
use std::fs;
use std::path::PathBuf;
use std::time::{SystemTime, UNIX_EPOCH};

/// The name shown in the window footer and in the file's properties.
const COMPANY: &str = "freber dev AB";

fn main() {
    println!("cargo:rerun-if-changed=res");
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-env-changed=SOURCE_DATE_EPOCH");

    let year = build_year();
    println!("cargo:rustc-env=MOWAH_BUILD_YEAR={year}");
    println!("cargo:rustc-env=MOWAH_COMPANY={COMPANY}");

    // The icon, manifest, version info and dialog layout only exist in Windows builds.
    if env::var("CARGO_CFG_TARGET_OS").as_deref() == Ok("windows") {
        // The version in the file's properties comes from Cargo.toml, so there is
        // only one place to change it. res/mowah.rc includes this generated header.
        let part = |name: &str| env::var(name).unwrap_or_else(|_| "0".into());
        let (major, minor, patch) =
            (part("CARGO_PKG_VERSION_MAJOR"), part("CARGO_PKG_VERSION_MINOR"), part("CARGO_PKG_VERSION_PATCH"));
        let header = format!(
            "#define MOWAH_VERSION_NUMBERS {major},{minor},{patch},0\n\
             #define MOWAH_VERSION_TEXT \"{major}.{minor}.{patch}.0\"\n\
             #define MOWAH_COMPANY \"{COMPANY}\"\n\
             #define MOWAH_COPYRIGHT \"Copyright (C) {year} {COMPANY}\"\n"
        );
        let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR is set by cargo"));
        fs::write(out_dir.join("mowah_build.h"), header).expect("could not write mowah_build.h");

        embed_resource::compile("res/mowah.rc", embed_resource::ParamsIncludeDirs([&out_dir]))
            .manifest_required()
            .expect("could not compile res/mowah.rc");
    }
}

/// The calendar year (UTC) the build is made in. `SOURCE_DATE_EPOCH` overrides
/// the clock, which is the usual way to make a build reproducible.
fn build_year() -> i64 {
    let seconds = env::var("SOURCE_DATE_EPOCH")
        .ok()
        .and_then(|value| value.parse::<i64>().ok())
        .or_else(|| SystemTime::now().duration_since(UNIX_EPOCH).ok().map(|d| d.as_secs() as i64))
        .unwrap_or(0);
    year_of_day(seconds.div_euclid(86_400))
}

/// Gregorian year of a day counted from 1970-01-01.
fn year_of_day(days_since_epoch: i64) -> i64 {
    let shifted = days_since_epoch + 719_468;
    let era = shifted.div_euclid(146_097);
    let day_of_era = shifted.rem_euclid(146_097);
    let year_of_era = (day_of_era - day_of_era / 1_460 + day_of_era / 36_524 - day_of_era / 146_096) / 365;
    let day_of_year = day_of_era - (365 * year_of_era + year_of_era / 4 - year_of_era / 100);
    // Years are counted from 1 March here, so January and February belong to the next one.
    let starts_next_year = (5 * day_of_year + 2) / 153 >= 10;
    year_of_era + era * 400 + i64::from(starts_next_year)
}
