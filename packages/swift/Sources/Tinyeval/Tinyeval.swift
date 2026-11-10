// tinyeval's worker helper. Linking it moves stdout to stderr as the worker starts (see TinyevalStdout), so
// nothing the app prints mixes into a reply. The replies go to the real stdout.
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#endif
import TinyevalStdout

public enum Tinyeval {
    /// Throw it when the AI call couldn't run: no API key, a 401, a 429, a 5xx, a timeout or a lost connection.
    /// tinyeval counts the test case as couldn't run, apart from the failures.
    public struct CouldntRun: Error, CustomStringConvertible {
        public let reason: String
        public init(_ reason: String) { self.reason = reason }
        public var description: String { "couldn't run: \(reason)" }
    }

    /// Answers each input tinyeval sends with `answer(input)`. Returns when tinyeval closes stdin.
    public static func worker(
        isolation: isolated (any Actor)? = #isolation, _ answer: (String) async throws -> String
    ) async {
        await serve(from: 0, to: tinyeval_replies(), answer)
    }

    static func serve(
        isolation: isolated (any Actor)? = #isolation, from input: Int32, to output: Int32,
        _ answer: (String) async throws -> String
    ) async {
        var pending: [UInt8] = []
        var chunk = [UInt8](repeating: 0, count: 65536)
        while true {
            let count = read(input, &chunk, chunk.count)
            if count < 0 && errno == EINTR { continue }
            if count <= 0 { return }  // a partial input at the end is dropped
            pending += chunk[..<count]
            while let end = pending.firstIndex(of: 0) {
                let text = String(decoding: pending[..<end], as: UTF8.self)  // whole, so a split character survives
                pending.removeSubrange(...end)
                var reply: String
                do {
                    reply = try await answer(text)
                } catch let error as CouldntRun {
                    let reason = error.reason.split(whereSeparator: \.isWhitespace).joined(separator: " ")
                    reply = "#tinyeval couldnt_run \(reason)\n"
                } catch {
                    writeAll(Array("\(String(reflecting: error))\n".utf8), to: 2)  // Swift errors carry no stack trace
                    reply = "\(type(of: error)): \(error)"  // the reply, so the eval fails
                }
                writeAll(reply.utf8.filter { $0 != 0 } + [0], to: output)
            }
        }
    }
}

/// Writes all the bytes, since write can take only part of them.
func writeAll(_ bytes: [UInt8], to fd: Int32) {
    var sent = 0
    while sent < bytes.count {
        let count = bytes[sent...].withUnsafeBytes { write(fd, $0.baseAddress, $0.count) }
        if count < 0 && errno == EINTR { continue }
        if count <= 0 { return }
        sent += count
    }
}
