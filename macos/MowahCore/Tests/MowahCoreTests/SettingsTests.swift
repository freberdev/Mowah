import Testing
@testable import MowahCore

@Suite struct SettingsTests {
    @Test func defaultsAreUnobtrusive() {
        let s = Settings()
        #expect(s.method == .invisible)
        #expect(s.circleDiameter == 300)
        #expect(!s.leftClick)
        #expect(s.idleThresholdSecs == 60)
        #expect(s.intervalMinSecs == 30)
        #expect(s.intervalMaxSecs == 90)
        #expect(s.preventSleep)
        #expect(s.keepDisplayOn)
        #expect(!s.scheduleEnabled)
        #expect(s.scheduleStartMinute == 8 * 60)
        #expect(s.scheduleEndMinute == 17 * 60)
    }

    @Test func defaultsAreAlreadyNormalized() {
        #expect(Settings().normalized() == Settings())
    }

    @Test func timingValuesAreClamped() {
        var s = Settings()
        s.idleThresholdSecs = 0
        s.intervalMinSecs = 9999
        s.intervalMaxSecs = 1
        let n = s.normalized()
        #expect(n.idleThresholdSecs == 5)
        #expect(n.intervalMinSecs == 240)
        #expect(n.intervalMaxSecs == 240)
    }

    @Test func circleSizeIsClamped() {
        var s = Settings()
        s.circleDiameter = 5
        #expect(s.normalized().circleDiameter == 20)
        s.circleDiameter = 99_999
        #expect(s.normalized().circleDiameter == 1000)
        s.circleDiameter = 450
        #expect(s.normalized().circleDiameter == 450)
    }

    @Test func maxIntervalNeverEndsUpBelowMin() {
        var s = Settings()
        s.intervalMinSecs = 120
        s.intervalMaxSecs = 40
        let n = s.normalized()
        #expect(n.intervalMinSecs == 120)
        #expect(n.intervalMaxSecs == 120)
    }

    @Test func outOfRangeScheduleTimesFallBackToDefaults() {
        var s = Settings()
        s.scheduleStartMinute = 1440
        s.scheduleEndMinute = 5000
        let n = s.normalized()
        #expect(n.scheduleStartMinute == 8 * 60)
        #expect(n.scheduleEndMinute == 17 * 60)
    }

    @Test func negativeScheduleTimesFallBackToDefaults() {
        var s = Settings()
        s.scheduleStartMinute = -1
        #expect(s.normalized().scheduleStartMinute == 8 * 60)
    }

    @Test func parsesCommonTimeSpellings() {
        #expect(parseTime("08:00") == 480)
        #expect(parseTime("8:05") == 485)
        #expect(parseTime(" 17.30 ") == 17 * 60 + 30)
        #expect(parseTime("0:00") == 0)
        #expect(parseTime("23:59") == 1439)
    }

    @Test func rejectsInvalidTimes() {
        for bad in ["", "8", "24:00", "12:60", "ab:cd", "12:3x", "-1:00", "1:2:3", "25:00", "٠٨:٠٠"] {
            #expect(parseTime(bad) == nil, "\(bad) should be rejected")
        }
    }

    @Test func formatsTimeWithLeadingZeros() {
        #expect(formatTime(485) == "08:05")
        #expect(formatTime(0) == "00:00")
        #expect(formatTime(1439) == "23:59")
    }

    @Test func parsesWholeNumbersAsTyped() {
        #expect(parseWholeNumber("60") == 60)
        #expect(parseWholeNumber(" 300 ") == 300)
        #expect(parseWholeNumber("007") == 7)
        #expect(parseWholeNumber("0") == 0)
    }

    @Test func rejectsEverythingThatIsNotAWholeNumber() {
        for bad in ["", " ", "abc", "8,5", "8.5", "-5", "+5", "1 000", "12a", "٣٠", "1e3", "99999999999999999999"] {
            #expect(parseWholeNumber(bad) == nil, "\(bad) should be rejected")
        }
    }

    @Test func a300PixelCircleMovesAboutFifteenPixelsPerStep() {
        #expect(circleSteps(diameter: 300) == 63)
    }

    @Test func stepCountGrowsWithTheCircleButStaysWithinLimits() {
        #expect(circleSteps(diameter: 20) == 24)
        #expect(circleSteps(diameter: 1000) == 96)
        #expect(circleSteps(diameter: 200) < circleSteps(diameter: 400))
    }
}
