import Foundation

#if DEBUG
enum LexisLogger {
    static func networkResponse(
        request: URLRequest,
        http: HTTPURLResponse,
        data: Data?,
        start: Date
    ) {
        let ms = Int(Date().timeIntervalSince(start) * 1000)
        let method = request.httpMethod ?? "?"
        let path = request.url?.path ?? "?"
        let status = http.statusCode
        var line = "[Lexis NET] \(method) \(path) → \(status) (\(ms)ms)"
        if let len = data?.count { line += " body:\(len)b" }
        print(line)
        if let data, !data.isEmpty,
           let snippet = String(data: data.prefix(2048), encoding: .utf8) {
            let trimmed = snippet.replacingOccurrences(of: "\n", with: " ")
            print("[Lexis NET] Body: \(trimmed)")
        }
    }

    static func networkDecodeFailure(url: URL?, data: Data?, error: Error) {
        print("[Lexis NET] Decode failed \(url?.path ?? "?"): \(error.localizedDescription)")
        if let data, let s = String(data: data.prefix(1024), encoding: .utf8) {
            print("[Lexis NET] Raw: \(s.replacingOccurrences(of: "\n", with: " "))")
        }
    }
}
#endif
