/// How long the user has been away, in the unit it is shown with. The words
/// themselves are chosen by the app, in the user's language.
public enum AwayDuration: Equatable, Sendable {
    case seconds(Int)
    case minutes(Int)
    case hoursAndMinutes(Int, Int)

    public init(ms: UInt64) {
        let seconds = Int(ms / 1_000)
        let minutes = seconds / 60
        if seconds < 60 {
            self = .seconds(seconds)
        } else if minutes < 60 {
            self = .minutes(minutes)
        } else {
            self = .hoursAndMinutes(minutes / 60, minutes % 60)
        }
    }
}
