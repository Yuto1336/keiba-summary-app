import Foundation

struct DayIndex: Codable {
    let days: [String]
}

struct DayData: Codable, Identifiable {
    let date: String
    let summary: [String]
    let races: [Race]
    var id: String { date }

    /// 競馬場ごとにグループ化（元の並び順を維持）
    var venueGroups: [(venue: String, races: [Race])] {
        var order: [String] = []
        var dict: [String: [Race]] = [:]
        for race in races {
            if dict[race.venue] == nil { order.append(race.venue) }
            dict[race.venue, default: []].append(race)
        }
        return order.map { (venue: $0, races: dict[$0] ?? []) }
    }
}

struct Race: Codable, Identifiable {
    let venue: String
    let raceNumber: Int
    let raceName: String
    let surface: String
    let distance: Int
    let courseTrait: String
    let raceFlow: String
    let winnerStyle: String
    let horses: [Horse]
    var id: String { "\(venue)-\(raceNumber)" }
    var winner: Horse? { horses.first { $0.finish == "1" } }
    var courseLabel: String { "\(surface)\(distance)m" }
}

struct Horse: Codable, Identifiable {
    let finish: String
    let number: Int
    let name: String
    let popularity: Int?
    let jockey: String
    let passing: String
    let last3f: String
    let comment: String
    var id: String { "\(number)-\(name)" }
    var popularityLabel: String {
        if let popularity { return "\(popularity)人気" }
        return "人気不明"
    }
}
