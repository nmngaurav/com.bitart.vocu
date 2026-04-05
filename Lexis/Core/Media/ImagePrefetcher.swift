import Foundation

/// Actor-based image prefetcher. Warms URLSession cache and keeps an in-memory data cache
/// so `RevealableCardView` can paint the first card without a second network round-trip
/// when `URLCache` does not retain the response.
actor ImagePrefetcher {
    static let shared = ImagePrefetcher()

    private init() {}

    private var memory: [String: Data] = [:]
    private var orderedKeys: [String] = []
    private let maxMemoryEntries = 48

    /// Returns in-memory bytes if this URL was prefetched or loaded through this actor.
    func cachedData(for urlString: String) -> Data? {
        memory[urlString]
    }

    private func storeMemory(urlString: String, data: Data) {
        memory[urlString] = data
        orderedKeys.removeAll { $0 == urlString }
        orderedKeys.append(urlString)
        while orderedKeys.count > maxMemoryEntries, let first = orderedKeys.first {
            orderedKeys.removeFirst()
            memory.removeValue(forKey: first)
        }
    }

    /// Warms caches with a single image URL.
    func prefetch(urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        if memory[urlString] != nil { return }
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 25)
        guard let (data, response) = try? await URLSession.shared.data(for: req),
              let http = response as? HTTPURLResponse,
              (200...299).contains(http.statusCode),
              !data.isEmpty
        else { return }
        storeMemory(urlString: urlString, data: data)
    }

    func prefetch(urlStrings: [String]) async {
        await withTaskGroup(of: Void.self) { group in
            for s in urlStrings {
                group.addTask { await self.prefetch(urlString: s) }
            }
        }
    }

    /// Loads the first URL to completion before returning, then prefetches the rest concurrently.
    /// Use so the visible card’s image is not starved when many URLs are requested at once.
    func prefetchFirstThenRest(urlStrings: [String]) async {
        guard let first = urlStrings.first else { return }
        await prefetch(urlString: first)
        let rest = Array(urlStrings.dropFirst())
        guard !rest.isEmpty else { return }
        Task { await self.prefetch(urlStrings: rest) }
    }

    /// Stores bytes after a successful card load so the next prefetch stack can reuse them.
    func storeFromNetwork(urlString: String, data: Data) {
        guard !data.isEmpty else { return }
        storeMemory(urlString: urlString, data: data)
    }
}
