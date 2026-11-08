import Foundation

@MainActor
final class DataStore: ObservableObject {
    @Published var days: [String] = []
    @Published var isLoading = false
    @Published var statusMessage: String?

    /// データ取得元のベースURL（GitHubリポジトリの Data フォルダを raw で指す）。
    /// 自分のリポジトリを作ったら YOUR_GITHUB_NAME を自分のアカウント名に書き換える。
    /// アプリの設定画面からも変更できる。
    static let defaultBaseURL = "https://raw.githubusercontent.com/Yuto1336/keiba-summary-app/main/Data"

    private let defaultsKey = "dataBaseURL"

    var baseURLString: String {
        get { UserDefaults.standard.string(forKey: defaultsKey) ?? Self.defaultBaseURL }
        set { UserDefaults.standard.set(newValue, forKey: defaultsKey) }
    }

    private func remoteURL(_ file: String) -> URL? {
        let base = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !base.isEmpty, !base.contains("YOUR_GITHUB_NAME") else { return nil }
        return URL(string: base.hasSuffix("/") ? base + file : base + "/" + file)
    }

    private func fetchJSON<T: Decodable>(_ type: T.Type, file: String) async -> T? {
        // まずリモート（新しい日付のまとめを再インストールなしで取得するため）
        if let url = remoteURL(file),
           let (data, response) = try? await URLSession.shared.data(from: url),
           (response as? HTTPURLResponse)?.statusCode == 200,
           let value = try? JSONDecoder().decode(type, from: data) {
            return value
        }
        // ダメなら同梱データ
        let name = (file as NSString).deletingPathExtension
        if let url = Bundle.main.url(forResource: name, withExtension: "json"),
           let data = try? Data(contentsOf: url),
           let value = try? JSONDecoder().decode(type, from: data) {
            return value
        }
        return nil
    }

    func loadIndex() async {
        isLoading = true
        defer { isLoading = false }
        if let index = await fetchJSON(DayIndex.self, file: "index.json") {
            days = index.days
            statusMessage = remoteURL("index.json") == nil ? "同梱データを表示中（設定でデータURLを入れると最新化されます）" : nil
        } else {
            statusMessage = "データを読み込めませんでした"
        }
    }

    func loadDay(_ date: String) async -> DayData? {
        await fetchJSON(DayData.self, file: "\(date).json")
    }
}
