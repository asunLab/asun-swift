import Foundation
import AsunSwift

func debugTest(_ label: String, _ block: () throws -> Void) {
    do {
        try block()
        print("  OK: \(label)")
    } catch {
        print("  ERR: \(label): \(error)")
    }
}

print("=== Unicode Debug ===")

debugTest("Japanese") {
    let v: AsunValue = .object(["name": .string("日本語テスト")])
    let s = try encode(v)
    print("    encoded: \(s)")
    let d = try decode(s)
    print("    match: \(d == v)")
}

debugTest("Emoji") {
    let v: AsunValue = .object(["emoji": .string("Hello 🌍🚀")])
    let s = try encode(v)
    print("    encoded: \(s)")
    let d = try decode(s)
    print("    match: \(d == v)")
}

debugTest("Mixed") {
    let v: AsunValue = .object(["mixed": .string("中文 English العربية")])
    let s = try encode(v)
    print("    encoded: \(s)")
    let d = try decode(s)
    print("    match: \(d == v)")
}

debugTest("Binary unicode") {
    let v: AsunValue = .object(["name": .string("日本語テスト"), "emoji": .string("🌍🚀✨")])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    print("    match: \(d == v)")
}

print("\n=== Text vs Binary equiv Debug ===")

debugTest("Text vs Binary") {
    let v: AsunValue = .object([
        "id": .int(42),
        "name": .string("Alice"),
        "scores": .array([.float(95.5), .float(87.3), .float(92.1)]),
        "meta": .object(["role": .string("admin"), "level": .int(5)])
    ])
    let text = try encode(v)
    print("    text: \(text)")
    let fromText = try decode(text)
    let bin = try encodeBinary(v)
    let fromBin = try decodeBinary(bin)
    print("    text==bin: \(fromText == fromBin)")
    print("    text==orig: \(fromText == v)")
}
