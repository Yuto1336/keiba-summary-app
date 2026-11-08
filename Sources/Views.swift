import SwiftUI

struct ContentView: View {
    @StateObject private var store = DataStore()
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
                            Text(date).font(.headline)
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
        .navigationTitle(date)
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
                    Text("GitHubリポジトリの Data フォルダを raw.githubusercontent.com で指します。新しい日のまとめJSONが置かれると、アプリ起動時に自動で取りに行きます。")
                }
                Button("保存して再読み込み") {
                    store.baseURLString = urlText
                    dismiss()
                    Task { await store.loadIndex() }
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
