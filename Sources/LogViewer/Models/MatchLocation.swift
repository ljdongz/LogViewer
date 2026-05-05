import Foundation

struct MatchLocation: Equatable {
    let entryId: UUID
    let lowerBound: Int
    let upperBound: Int
}
