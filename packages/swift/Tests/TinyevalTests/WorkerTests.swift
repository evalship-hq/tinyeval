import Foundation
#if canImport(Glibc)
import Glibc  // Foundation may not re-export it on Linux
#endif
import Testing
import TinyevalStdout

@testable import Tinyeval

enum AppError: Error { case boom }
struct APIError: Error { let status: Int }  // shaped like an SDK's error

func app(_ input: String) async throws -> String {
    switch input {
    case "no key": throw Tinyeval.CouldntRun("ANTHROPIC_API_KEY\nisn't set ")
    case "429": throw APIError(status: 429)
    case "crash": throw AppError.boom
    case "nul": return "a\0b"
    default: return "You said: \(input)"
    }
}

/// Writes each chunk to a worker around app, pausing so it reads them one at a time, then closes its stdin.
/// Returns the replies, split at NUL.
func replies(_ chunks: [UInt8]...) async -> [String] {
    var input: [Int32] = [0, 0]
    var output: [Int32] = [0, 0]
    _ = pipe(&input)
    _ = pipe(&output)
    let writer = input[1]
    Thread {
        for chunk in chunks {
            writeAll(chunk, to: writer)
            usleep(20_000)
        }
        close(writer)
    }.start()
    await Tinyeval.serve(from: input[0], to: output[1], app)
    close(input[0])
    close(output[1])
    return readAll(output[0]).components(separatedBy: "\0")
}

func readAll(_ fd: Int32) -> String {
    String(decoding: FileHandle(fileDescriptor: fd, closeOnDealloc: true).readDataToEndOfFile(), as: UTF8.self)
}

@Suite(.serialized) struct WorkerTests {
    @Test func severalInputsInOneChunk() async {
        let got = await replies(Array("one\0two\0three\0partial".utf8))
        #expect(got == ["You said: one", "You said: two", "You said: three", ""])
    }

    @Test func utf8InputSplitInsideACharacter() async {
        let bytes = Array("naïve 日本語 ✓\0".utf8)
        let got = await replies(Array(bytes[..<3]), Array(bytes[3..<9]), Array(bytes[9...]))
        #expect(got == ["You said: naïve 日本語 ✓", ""])
    }

    @Test func couldntRun() async {
        #expect(await replies(Array("no key\0".utf8)) == ["#tinyeval couldnt_run ANTHROPIC_API_KEY isn't set\n", ""])
    }

    // Swift has no official Anthropic or OpenAI SDK, so an API error is the app's own until it throws CouldntRun.
    @Test func otherErrorsBecomeTheReply() async {
        let got = await replies(Array("crash\0".utf8), Array("429\0after\0nul\0".utf8))
        #expect(got == ["AppError: boom", "APIError: APIError(status: 429)", "You said: after", "ab", ""])
    }

    @Test func appOutputGoesToStderr() {
        #expect(tinyeval_replies() > 2)  // the constructor moved this test process's stdout when it started
        // What it did there, again, onto pipes.
        var out: [Int32] = [0, 0]
        var err: [Int32] = [0, 0]
        _ = pipe(&out)
        _ = pipe(&err)
        let (realOut, realErr) = (dup(1), dup(2))
        dup2(out[1], 1)
        dup2(err[1], 2)
        let replies = tinyeval_move_stdout()
        writeAll(Array("app output".utf8), to: 1)
        writeAll(Array("reply".utf8), to: replies)
        dup2(realOut, 1)
        dup2(realErr, 2)
        for fd in [out[1], err[1], replies, realOut, realErr] { close(fd) }
        #expect(readAll(out[0]) == "reply")
        #expect(readAll(err[0]).contains("app output"))
    }
}
