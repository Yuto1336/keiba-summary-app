import SwiftUI

/// "2026-11-14" → "11月14日（土）"
func jpDateLabel(_ isoDate: String) -> String {
    let parser = DateFormatter()
    parser.locale = Locale(identifier: "en_US_POSIX")
    parser.dateFormat = "yyyy-MM-dd"
    guard let date = parser.date(from: isoDate) else { return isoDate }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "ja_JP")
    formatter.dateFormat = "M月d日（EEE）"
    return formatter.string(from: date)
}

struct ContentView: View {
    @StateObject private var store = DataStore()

    var body: some View {
        TabView {
            ResultsHomeView()
                .environmentObject(store)
                .tabItem { Label("結果", systemImage: "list.bullet.rectangle") }
            PreviewHomeView()
                .environmentObject(store)
                .tabItem { Label("展望", systemImage: "eye") }
        }
    }
}

// MARK: - 結果まとめ

struct ResultsHomeView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                if let message = store.statusMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.days, id: \.self) { date in
                    NavigationLink {
                        DayView(date: date).environmentObject(store)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(jpDateLabel(date)).font(.headline)
                            Text("全レース結果まとめ").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("競馬まとめ")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(store)
            }
            .task { await store.loadIndex() }
            .refreshable { await store.loadIndex() }
            .overlay {
                if store.isLoading && store.days.isEmpty {
                    ProgressView("読み込み中…")
                }
            }
        }
    }
}

struct DayView: View {
    @EnvironmentObject var store: DataStore
    let date: String
    @State private var day: DayData?

    var body: some View {
        Group {
            if let day {
                List {
                    if !day.summary.isEmpty {
                        Section("その日の総括") {
                            ForEach(day.summary, id: \.self) { line in
                                Text(line).font(.callout)
                            }
                        }
                    }
                    ForEach(day.venueGroups, id: \.venue) { group in
                        Section(group.venue) {
                            ForEach(group.races) { race in
                                NavigationLink {
                                    RaceView(race: race)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(race.raceNumber)R \(race.raceName)")
                                            .font(.headline)
                                        Text("\(race.courseLabel)／勝ち馬: \(race.winner?.name ?? "—")（\(race.winner?.popularityLabel ?? "")）")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView("読み込み中…")
            }
        }
        .navigationTitle(jpDateLabel(date))
        .navigationBarTitleDisplayMode(.inline)
        .task { day = await store.loadDay(date) }
    }
}

struct RaceView: View {
    let race: Race

    var body: some View {
        List {
            Section("レース概要") {
                LabeledContent("競馬場", value: race.venue)
                LabeledContent("コース", value: race.courseLabel)
                VStack(alignment: .leading, spacing: 4) {
                    Text("コース特徴").font(.footnote).foregroundStyle(.secondary)
                    Text(race.courseTrait)
                }
            }
            Section("レースの振り返り") {
                VStack(alignment: .leading, spacing: 4) {
                    Text("運び").font(.footnote).foregroundStyle(.secondary)
                    Text(race.raceFlow)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("勝ち馬の型").font(.footnote).foregroundStyle(.secondary)
                    Text(race.winnerStyle)
                }
            }
            Section("全馬結果（着順順）") {
                ForEach(race.horses) { horse in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(horse.finish == "中止" ? "中止" : "\(horse.finish)着")
                                .font(.headline)
                                .foregroundStyle(horse.finish == "1" ? .orange : .primary)
                            Text("\(horse.number) \(horse.name)")
                                .font(.headline)
                            Spacer()
                            Text(horse.popularityLabel)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                        Text("騎手: \(horse.jockey)／通過: \(horse.passing)／上がり: \(horse.last3f)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !horse.comment.isEmpty {
                            Text(horse.comment).font(.callout)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("\(race.raceNumber)R \(race.raceName)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - レース前展望

struct PreviewHomeView: View {
    @EnvironmentObject var store: DataStore
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            List {
                if store.previewWeekends.isEmpty {
                    Text("展望データがまだありません")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                ForEach(store.previewWeekends, id: \.self) { weekend in
                    NavigationLink {
                        PreviewDayView(weekend: weekend).environmentObject(store)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(jpDateLabel(weekend)) の週末").font(.headline)
                            Text("メイン・重賞のレース前展望").font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("レース前展望")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showingSettings) {
                SettingsView().environmentObject(store)
            }
            .task { await store.loadPreviewIndex() }
            .refreshable { await store.loadPreviewIndex() }
        }
    }
}

struct PreviewDayView: View {
    @EnvironmentObject var store: DataStore
    let weekend: String
    @State private var preview: PreviewDay?

    var body: some View {
        Group {
            if let preview {
                List {
                    ForEach(preview.dateGroups, id: \.date) { group in
                        Section(jpDateLabel(group.date)) {
                            ForEach(group.races) { race in
                                NavigationLink {
                                    PreviewRaceView(race: race)
                                } label: {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("\(race.raceNumber)R \(race.raceName)")
                                            .font(.headline)
                                        Text("\(race.venue)／\(race.courseLabel)／\(race.startTime)発走")
                                            .font(.footnote)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                ProgressView("読み込み中…")
            }
        }
        .navigationTitle("\(jpDateLabel(weekend)) の週末")
        .navigationBarTitleDisplayMode(.inline)
        .task { preview = await store.loadPreview(weekend) }
    }
}

struct PreviewRaceView: View {
    let race: PreviewRace

    var body: some View {
        List {
            Section("レース概要") {
                LabeledContent("競馬場", value: race.venue)
                LabeledContent("コース", value: race.courseLabel)
                LabeledContent("発走", value: race.startTime)
                VStack(alignment: .leading, spacing: 4) {
                    Text("コースで強いタイプ").font(.footnote).foregroundStyle(.secondary)
                    Text(race.courseTrait)
                }
            }
            Section("想定展開") {
                Text(race.pace)
                VStack(alignment: .leading, spacing: 4) {
                    Text("有利なタイプと注目馬").font(.footnote).foregroundStyle(.secondary)
                    Text(race.favored)
                }
                ForEach(race.notes, id: \.self) { note in
                    Text(note).font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section("脚質マップ（出走馬）") {
                ForEach(race.horses) { horse in
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(horse.numberLabel)
                                .font(.headline)
                                .foregroundStyle(.secondary)
                                .frame(minWidth: 22, alignment: .leading)
                            Text(horse.name).font(.headline)
                            Text(horse.style)
                                .font(.caption)
                                .fontWeight(.semibold)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.15))
                                .clipShape(Capsule())
                            Spacer()
                        }
                        Text("騎手: \(horse.jockey)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        if !horse.comment.isEmpty {
                            Text(horse.comment).font(.callout)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle("\(race.raceNumber)R \(race.raceName)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - 設定

struct SettingsView: View {
    @EnvironmentObject var store: DataStore
    @Environment(\.dismiss) private var dismiss
    @State private var urlText: String = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("データURL", text: $urlText, axis: .vertical)
                        .font(.footnote)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("データ取得元（index.json のあるフォルダのURL）")
                } footer: {
                    Text("GitHubリポジトリの Data フォルダを raw.githubusercontent.com で指します。新しい日のまとめ・展望JSONが置かれると、アプリ起動時に自動で取りに行きます。")
                }
                Button("保存して再読み込み") {
                    store.baseURLString = urlText
                    dismiss()
                    Task {
                        await store.loadIndex()
                        await store.loadPreviewIndex()
                    }
                }
            }
            .navigationTitle("設定")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .onAppear { urlText = store.baseURLString }
        }
    }
}
