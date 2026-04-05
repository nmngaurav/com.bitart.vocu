import Foundation

struct WordProgressBrief: Decodable {
    let status: String?
    let intervalDays: Int
    let nextReviewAt: Date?
}

struct PackWordProgressResponse: Decodable, Identifiable {
    let id: Int
    let term: String
    let phonetic: String?
    let partOfSpeech: String?
    let definition: String?
    let audioUrl: String?
    let primaryImageUrl: String?
    let example: String?
    let progress: WordProgressBrief?
}
