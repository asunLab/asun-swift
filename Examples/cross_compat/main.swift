import Foundation
import AsunSwift

// Cross-language compatibility example — matches asun-rs/examples/cross_compat.rs

let input = "[{ID@int,Name@str,Age@int,Gender@bool}]:(1,Alice,30,true),(2,Bob,25,false)"

do {
    // Decode
    let decoded = try decode(input)
    print("Decoded from ASUN:")
    if case .array(let arr) = decoded {
        for row in arr { print("   \(row)") }
    }

    // Re-encode
    let reEncoded = try encode(decoded)
    print("\nRe-encoded:")
    print("   \(reEncoded)")

    // Binary roundtrip
    let bin = try encodeBinary(decoded)
    let fromBin = try decodeBinary(bin)
    print("\nBinary size: \(bin.count) bytes")
    if case .array(let arr) = fromBin {
        for row in arr { print("   \(row)") }
    }

    // Verify roundtrip
    assert(fromBin == decoded, "binary roundtrip failed")
    print("\n✓ cross-compat roundtrip OK")

    // Typed output
    let typed = try encodeTyped(decoded)
    print("\nTyped output:")
    print("   \(typed)")

    // Pretty output
    let pretty = try encodePretty(decoded)
    print("\nPretty output:")
    print(pretty)
} catch {
    print("error: \(error)")
    exit(1)
}
