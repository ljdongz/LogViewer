import SwiftUI

struct LogEntryRow: View {
    let entry: LogEntry
    let searchText: String
    let currentMatch: MatchLocation?
    let showLocation: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                LevelBadge(level: entry.level)
                CategoryLabel(text: entry.category)
                Spacer()
                TimeLabel(date: entry.timestamp)
            }

            Text(highlightedMessage)
                .font(.system(.footnote, design: .monospaced))
                .textSelection(.enabled)

            if showLocation {
                Text("↳ \(entry.fileName):\(entry.line) \(entry.function)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var highlightedMessage: AttributedString {
        var attributed = AttributedString(entry.message)
        guard !searchText.isEmpty else { return attributed }

        let message = entry.message
        var searchStart = message.startIndex
        while searchStart < message.endIndex,
              let range = message.range(
                  of: searchText,
                  options: .caseInsensitive,
                  range: searchStart..<message.endIndex
              ) {
            let charStart = message.distance(from: message.startIndex, to: range.lowerBound)
            let charLength = message.distance(from: range.lowerBound, to: range.upperBound)

            let attrLower = attributed.index(attributed.startIndex, offsetByCharacters: charStart)
            let attrUpper = attributed.index(attrLower, offsetByCharacters: charLength)
            let attrRange = attrLower..<attrUpper

            let isCurrent = (currentMatch?.lowerBound == charStart
                             && currentMatch?.upperBound == charStart + charLength)
            attributed[attrRange].backgroundColor = isCurrent ? .yellow : .gray.opacity(0.4)
            attributed[attrRange].foregroundColor = .black

            searchStart = range.upperBound
        }
        return attributed
    }
}

// MARK: - Sub-components

private struct LevelBadge: View {
    let level: LogEntry.Level

    var body: some View {
        Text(level.rawValue)
            .font(.caption2.bold())
            .foregroundStyle(.white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color, in: Capsule())
    }

    private var color: Color {
        switch level {
        case .log: return .gray
        case .notice: return .blue
        case .warning: return .orange
        case .error: return .red
        case .critical: return .purple
        case .fault: return .red.opacity(0.8)
        }
    }
}

private struct CategoryLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.caption2)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(.quaternary, in: Capsule())
    }
}

private struct TimeLabel: View {
    let date: Date

    var body: some View {
        Text(date, format: .dateTime.hour().minute().second().secondFraction(.fractional(3)))
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
    }
}
