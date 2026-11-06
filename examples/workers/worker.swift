// tinyeval worker in Swift. In your eval file:
//   worker swift evals/worker.swift
// In a Swift package, make it an executable target, run swift build, and use its binary: worker .build/debug/worker
import Foundation

func reply(_ input: String) -> String {
    "You said: " + input // your app's AI call goes here
}

var rest: [UInt8] = []
while true {
    let chunk = FileHandle.standardInput.availableData
    if chunk.isEmpty { break }
    rest += chunk
    while let i = rest.firstIndex(of: 0) {
        let input = String(decoding: rest[..<i], as: UTF8.self)
        rest.removeSubrange(...i)
        FileHandle.standardOutput.write(Data((reply(input) + "\0").utf8))
    }
}
