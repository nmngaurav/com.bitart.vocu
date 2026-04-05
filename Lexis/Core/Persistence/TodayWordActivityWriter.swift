import Foundation
import SwiftData

/// Upserts local activity rows for the in-app “today” recap.
enum TodayWordActivityWriter {

    static func dayKey(for date: Date = Date()) -> String {
        let cal = Calendar.current
        let c = cal.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    @MainActor
    static func recordLibraryBrowse(
        modelContext: ModelContext,
        wordId: Int,
        term: String,
        imageUrl: String?
    ) {
        let key = dayKey()
        let sid = "\(key)-\(wordId)"
        let now = Date()
        let desc = FetchDescriptor<WordDayActivityRecord>(
            predicate: #Predicate { $0.stableId == sid }
        )
        if let existing = try? modelContext.fetch(desc).first {
            existing.lastUpdatedAt = now
            existing.imageUrl = imageUrl ?? existing.imageUrl
            return
        }
        let row = WordDayActivityRecord(
            stableId: sid,
            wordId: wordId,
            term: term,
            dayKey: key,
            firstSeenAt: now,
            lastUpdatedAt: now,
            sourceRaw: WordActivitySource.library.rawValue,
            ratingLabel: nil,
            cardType: nil,
            imageUrl: imageUrl
        )
        modelContext.insert(row)
    }

    @MainActor
    static func recordReview(
        modelContext: ModelContext,
        card: ReviewQueueCard,
        rating: CardRating
    ) {
        let key = dayKey()
        let sid = "\(key)-\(card.wordId)"
        let now = Date()
        let label = rating.label
        let w = card.word
        let desc = FetchDescriptor<WordDayActivityRecord>(
            predicate: #Predicate { $0.stableId == sid }
        )
        if let existing = try? modelContext.fetch(desc).first {
            existing.lastUpdatedAt = now
            existing.ratingLabel = label
            existing.cardType = card.cardType
            existing.sourceRaw = WordActivitySource.review.rawValue
            existing.term = w.term
            existing.imageUrl = w.primaryImageUrl ?? existing.imageUrl
            existing.definitionText = w.definition
            existing.exampleText = w.example
            existing.phoneticText = w.phonetic
            existing.partOfSpeechText = w.partOfSpeech
            existing.audioUrlString = w.audioUrl
            return
        }
        let row = WordDayActivityRecord(
            stableId: sid,
            wordId: card.wordId,
            term: w.term,
            dayKey: key,
            firstSeenAt: now,
            lastUpdatedAt: now,
            sourceRaw: WordActivitySource.review.rawValue,
            ratingLabel: label,
            cardType: card.cardType,
            imageUrl: w.primaryImageUrl,
            definitionText: w.definition,
            exampleText: w.example,
            phoneticText: w.phonetic,
            partOfSpeechText: w.partOfSpeech,
            audioUrlString: w.audioUrl
        )
        modelContext.insert(row)
    }
}
