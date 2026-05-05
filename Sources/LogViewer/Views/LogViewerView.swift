import SwiftUI

/// The SwiftUI log screen provided by LogViewer.
///
/// Shows the entries from ``LogStore/shared`` and includes search and highlighting,
/// level and category filters, text sharing, and `.log` file export. The library does not
/// present this view automatically, so the host app is free to present it via sheet,
/// `NavigationLink`, full-screen cover, or any other mechanism. See
/// <doc:PresentationRecipes> for a collection of trigger patterns.
///
/// ```swift
/// struct DebugMenu: View {
///     @State private var showLog = false
///     var body: some View {
///         Button("로그 보기") { showLog = true }
///             .sheet(isPresented: $showLog) { LogViewerView() }
///     }
/// }
/// ```
///
/// The view embeds its own `NavigationStack`, so it works correctly as the root of a
/// sheet — title and toolbar behave as expected. The close button uses
/// `Environment(\.dismiss)`, so it works regardless of the presenter.
public struct LogViewerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var store = LogStore.shared

    // Filters
    @State private var searchText: String = ""
    @State private var selectedLevels: Set<LogEntry.Level> = Set(LogEntry.Level.allCases)
    @State private var selectedCategory: String? = nil
    @State private var showLocation: Bool = false

    // Search navigation
    @State private var matches: [MatchLocation] = []
    @State private var currentMatchIndex: Int = 0

    // Search debounce
    @State private var searchTask: Task<Void, Never>?

    // Detail view
    @State private var selectedEntry: LogEntry?

    // Search focus
    @FocusState private var isSearchFocused: Bool

    // Initial scroll flag
    @State private var didInitialScroll: Bool = false

    /// Creates an empty ``LogViewerView``.
    ///
    /// All state is sourced from ``LogStore/shared``, so no parameters are needed.
    public init() {}

    // MARK: - Filtered Entries

    private var filteredEntries: [LogEntry] {
        store.entries.filter { entry in
            guard selectedLevels.contains(entry.level) else { return false }
            if let selectedCategory, entry.category != selectedCategory { return false }
            return true
        }
    }

    // MARK: - Body

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                filterBar
                if !searchText.isEmpty && !matches.isEmpty {
                    searchNavigationBar
                }
                if filteredEntries.isEmpty {
                    emptyState
                } else {
                    logList
                }
            }
            .onTapGesture { isSearchFocused = false }
            .navigationTitle("Debug Logs (\(filteredEntries.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("닫기") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    toolbarMenu
                }
            }
            .onChange(of: searchText) { _ in debounceRecalculate() }
            .onChange(of: selectedLevels) { _ in recalculateMatches() }
            .onChange(of: selectedCategory) { _ in recalculateMatches() }
            .onReceive(store.$entries) { _ in recalculateMatches() }
        }
        .sheet(item: $selectedEntry) { entry in
            LogEntryDetailView(entry: entry)
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("로그 검색", text: $searchText)
                    .focused($isSearchFocused)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(.systemGray6), in: RoundedRectangle(cornerRadius: 10))

            if isSearchFocused {
                Button("취소") {
                    searchText = ""
                    isSearchFocused = false
                }
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .animation(.easeInOut(duration: 0.2), value: isSearchFocused)
    }

    // MARK: - Filter Bar

    private var isAllLevelsSelected: Bool {
        selectedLevels.count == LogEntry.Level.allCases.count
    }

    private var filterBar: some View {
        VStack(spacing: 0) {
            // Level chips row
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    // "All" button
                    Button {
                        selectedLevels = Set(LogEntry.Level.allCases)
                    } label: {
                        Text("전체")
                            .font(.caption.bold())
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                isAllLevelsSelected ? Color.accentColor.opacity(0.2) : Color(.systemGray5),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)

                    ForEach(LogEntry.Level.allCases, id: \.self) { level in
                        levelChip(level: level)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }

            Divider()

            // Category + Location row
            HStack(spacing: 12) {
                Menu {
                    Button("전체") { selectedCategory = nil }
                    ForEach(store.availableCategories, id: \.self) { cat in
                        Button(cat) { selectedCategory = cat }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "line.3.horizontal.decrease")
                        Text(selectedCategory ?? "Category")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        selectedCategory != nil ? Color.accentColor.opacity(0.15) : Color(.systemGray5),
                        in: Capsule()
                    )
                }

                Button {
                    showLocation.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: showLocation ? "mappin.circle.fill" : "mappin.circle")
                        Text("위치")
                    }
                    .font(.caption)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        showLocation ? Color.accentColor.opacity(0.15) : Color(.systemGray5),
                        in: Capsule()
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
        .background(Color(.systemBackground))
    }

    private func levelChip(level: LogEntry.Level) -> some View {
        let isIndividuallySelected = !isAllLevelsSelected && selectedLevels.contains(level)
        return Button {
            if isAllLevelsSelected {
                // "All" selected -> select only this level
                selectedLevels = [level]
            } else if selectedLevels.contains(level) {
                // Deselect an already-selected level
                selectedLevels.remove(level)
                // If everything is deselected, re-enable all
                if selectedLevels.isEmpty {
                    selectedLevels = Set(LogEntry.Level.allCases)
                }
            } else {
                // Add a level that wasn't selected
                selectedLevels.insert(level)
            }
        } label: {
            Text(level.rawValue)
                .font(.caption.bold())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    isIndividuallySelected ? Color.accentColor.opacity(0.2) : Color(.systemGray5),
                    in: Capsule()
                )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Search Navigation Bar

    private var searchNavigationBar: some View {
        HStack {
            Text("\(currentMatchIndex + 1) / \(matches.count)")
                .font(.caption)
                .monospacedDigit()
                .foregroundStyle(.secondary)

            Spacer()

            Button {
                goToPreviousMatch()
            } label: {
                Image(systemName: "chevron.up")
            }
            .disabled(matches.isEmpty)

            Button {
                goToNextMatch()
            } label: {
                Image(systemName: "chevron.down")
            }
            .disabled(matches.isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("로그 없음")
                .font(.title3.bold())
            if !isAllLevelsSelected || selectedCategory != nil {
                Text("현재 필터 조건에 맞는 로그가 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("아직 기록된 로그가 없습니다.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Log List

    private var logList: some View {
        ScrollViewReader { proxy in
            List(filteredEntries) { entry in
                LogEntryRow(
                    entry: entry,
                    searchText: searchText,
                    currentMatch: currentMatchForEntry(entry),
                    showLocation: showLocation
                )
                .id(entry.id)
                .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                .onTapGesture { selectedEntry = entry }
                .contextMenu {
                    Button {
                        UIPasteboard.general.string = entry.formatted(includeLocation: true)
                    } label: {
                        Label("복사", systemImage: "doc.on.doc")
                    }
                }
            }
            .listStyle(.plain)
            .onAppear {
                guard !didInitialScroll else { return }
                didInitialScroll = true
                DispatchQueue.main.async {
                    if let lastId = filteredEntries.last?.id {
                        proxy.scrollTo(lastId, anchor: .bottom)
                    }
                }
            }
            .onChange(of: matches) { newMatches in
                guard let first = newMatches.first else { return }
                withAnimation {
                    proxy.scrollTo(first.entryId, anchor: .center)
                }
            }
            .onChange(of: currentMatchIndex) { newIndex in
                guard matches.indices.contains(newIndex) else { return }
                withAnimation {
                    proxy.scrollTo(matches[newIndex].entryId, anchor: .center)
                }
            }
        }
    }

    // MARK: - Toolbar Menu

    private var toolbarMenu: some View {
        Menu {
            Menu {
                ShareLink(item: store.exportAsText(includeLocation: showLocation)) {
                    Label("텍스트로 공유", systemImage: "doc.text")
                }
                ShareLink(item: store.exportAsLogFile(includeLocation: showLocation)) {
                    Label(".log 파일로 공유", systemImage: "doc")
                }
            } label: {
                Label("전체 공유", systemImage: "square.and.arrow.up")
            }

            Button(role: .destructive) {
                store.clear()
            } label: {
                Label("초기화", systemImage: "trash")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
    }

    // MARK: - Search Logic

    private func currentMatchForEntry(_ entry: LogEntry) -> MatchLocation? {
        guard matches.indices.contains(currentMatchIndex) else { return nil }
        let current = matches[currentMatchIndex]
        return current.entryId == entry.id ? current : nil
    }

    private func debounceRecalculate() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(200))
            guard !Task.isCancelled else { return }
            recalculateMatches()
        }
    }

    private func recalculateMatches() {
        currentMatchIndex = 0
        guard !searchText.isEmpty else {
            matches = []
            return
        }
        var result: [MatchLocation] = []
        for entry in filteredEntries {
            let message = entry.message
            var searchStart = message.startIndex
            while searchStart < message.endIndex,
                  let range = message.range(
                      of: searchText,
                      options: .caseInsensitive,
                      range: searchStart..<message.endIndex
                  ) {
                result.append(MatchLocation(
                    entryId: entry.id,
                    lowerBound: message.distance(from: message.startIndex, to: range.lowerBound),
                    upperBound: message.distance(from: message.startIndex, to: range.upperBound)
                ))
                searchStart = range.upperBound
            }
        }
        matches = result
    }

    private func goToPreviousMatch() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex <= 0)
            ? matches.count - 1
            : currentMatchIndex - 1
    }

    private func goToNextMatch() {
        guard !matches.isEmpty else { return }
        currentMatchIndex = (currentMatchIndex >= matches.count - 1)
            ? 0
            : currentMatchIndex + 1
    }
}
