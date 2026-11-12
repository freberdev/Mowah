//! Platform-neutral logic: when to act, with which settings. No Windows calls here,
//! so everything in this module is unit-tested on any OS.

pub mod engine;
pub mod rng;
pub mod schedule;
pub mod settings;
pub mod text;
