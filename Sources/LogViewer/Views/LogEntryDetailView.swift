import SwiftUI

struct LogEntryDetailView: View {
    let entry: LogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("메시지") {
                    Text(entry.message)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                }

                Section("메타") {
                    LabeledContent("Level", value: entry.level.rawValue)
                    LabeledContent("Category", value: entry.category)
                    LabeledContent("Time", value: entry.timestamp.formatted(
                        .dateTime.year().month().day().hour().minute().second()
                    ))
                }

                Section("위치") {
                    LabeledContent("File", value: entry.fileName)
                    LabeledContent("Function", value: entry.function)
                    LabeledContent("Line", value: "\(entry.line)")
                }
            }
            .navigationTitle("로그 상세")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("복사") {
                        UIPasteboard.general.string = entry.formatted(includeLocation: true)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
            }
        }
    }
}
