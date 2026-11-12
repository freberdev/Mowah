/// Small xorshift64* generator. Randomness here only spreads out timing, so a
/// dependency-free generator is enough.
#[derive(Clone, Copy, Debug)]
pub struct Rng(u64);

impl Rng {
    pub fn new(seed: u64) -> Self {
        // xorshift never leaves zero, so mix the seed with a non-zero constant.
        Rng(seed ^ 0x9E37_79B9_7F4A_7C15 | 1)
    }

    pub fn next_u64(&mut self) -> u64 {
        let mut x = self.0;
        x ^= x >> 12;
        x ^= x << 25;
        x ^= x >> 27;
        self.0 = x;
        x.wrapping_mul(0x2545_F491_4F6C_DD1D)
    }

    /// Uniform-ish value in `lo..=hi`. Returns `lo` when the range is empty or inverted.
    pub fn range_inclusive(&mut self, lo: u64, hi: u64) -> u64 {
        if hi <= lo {
            return lo;
        }
        // The high bits of xorshift64* are the well-mixed ones.
        lo + (self.next_u64() >> 33) % (hi - lo + 1)
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn range_stays_within_bounds() {
        let mut rng = Rng::new(42);
        for _ in 0..10_000 {
            let v = rng.range_inclusive(30, 90);
            assert!((30..=90).contains(&v), "{v} outside 30..=90");
        }
    }

    #[test]
    fn range_reaches_both_ends() {
        let mut rng = Rng::new(7);
        let draws: Vec<u64> = (0..10_000).map(|_| rng.range_inclusive(1, 4)).collect();
        assert!(draws.contains(&1));
        assert!(draws.contains(&4));
    }

    #[test]
    fn single_value_range_returns_that_value() {
        let mut rng = Rng::new(1);
        assert_eq!(rng.range_inclusive(30, 30), 30);
    }

    #[test]
    fn inverted_range_returns_low_bound() {
        let mut rng = Rng::new(1);
        assert_eq!(rng.range_inclusive(90, 30), 90);
    }

    #[test]
    fn zero_seed_still_produces_varied_output() {
        let mut rng = Rng::new(0);
        let a = rng.next_u64();
        let b = rng.next_u64();
        assert_ne!(a, 0);
        assert_ne!(a, b);
    }
}
