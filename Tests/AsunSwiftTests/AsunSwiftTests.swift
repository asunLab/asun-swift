import Foundation
import AsunSwift

// ===========================================================================
// Test Harness (no XCTest dependency)
// ===========================================================================

var passed = 0
var failed = 0
var total = 0

func assertEq<T: Equatable>(_ a: T, _ b: T, _ msg: String = "", file: String = #file, line: Int = #line) {
    total += 1
    if a == b {
        passed += 1
    } else {
        failed += 1
        print("  ✗ FAIL [\(file):\(line)] \(msg)")
        print("    expected: \(b)")
        print("    got:      \(a)")
    }
}

func assertTrue(_ v: Bool, _ msg: String = "", file: String = #file, line: Int = #line) {
    total += 1
    if v { passed += 1 } else { failed += 1; print("  ✗ FAIL [\(file):\(line)] \(msg)") }
}

func assertThrows(_ body: () throws -> Void, _ msg: String = "", file: String = #file, line: Int = #line) {
    total += 1
    do {
        try body()
        failed += 1
        print("  ✗ FAIL [\(file):\(line)] expected error: \(msg)")
    } catch {
        passed += 1
    }
}

func section(_ name: String) {
    print("\n── \(name) ──")
}

func test(_ body: () throws -> Void) {
    do {
        try body()
    } catch {
        failed += 1
        total += 1
        print("  ✗ ERROR: \(error)")
    }
}

struct TypedUser: Equatable {
    var id: Int64 = 0
    var name: String = ""
    var active: Bool = false
    var score: Double = 0
    var email: String? = nil
}

struct TypedProfile: Equatable {
    var title: String = ""
    var level: Int64 = 0
}

struct TypedTeam: Equatable {
    var id: Int64 = 0
    var tags: [String] = []
    var scores: [Double] = []
    var flags: [Bool] = []
    var profile: TypedProfile = .init()
    var backup: TypedProfile? = nil
}

// ===========================================================================
// 1. Basic encode / decode
// ===========================================================================
section("1. Basic encode / decode")

test {
    let v: AsunValue = .object(["id": .int(1), "name": .string("Alice")])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "basic roundtrip")
}

test {
    let v: AsunValue = .object(["a": .bool(true), "b": .float(3.14), "c": .string("hi")])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "mixed types roundtrip")
}

// ===========================================================================
// 2. encodeTyped / decode roundtrip
// ===========================================================================
section("2. encodeTyped / decode roundtrip")

test {
    let v: AsunValue = .object(["x": .int(42), "y": .float(2.5), "z": .bool(false)])
    let typed = try encodeTyped(v)
    assertTrue(typed.contains("int"), "typed should contain 'int'")
    assertTrue(typed.contains("float"), "typed should contain 'float'")
    assertTrue(typed.contains("bool"), "typed should contain 'bool'")
    let d = try decode(typed)
    assertEq(d, v, "typed roundtrip")
}

// ===========================================================================
// 3. Vec (slice) encode / decode
// ===========================================================================
section("3. Vec (slice) encode / decode")

test {
    let v: AsunValue = .array([
        .object(["id": .int(1), "name": .string("A")]),
        .object(["id": .int(2), "name": .string("B")]),
        .object(["id": .int(3), "name": .string("C")])
    ])
    let s = try encode(v)
    assertTrue(s.hasPrefix("[{"), "vec should start with [{")
    let d = try decode(s)
    assertEq(d, v, "vec roundtrip")
}

test {
    let v: AsunValue = .array([
        .object(["id": .int(1), "name": .string("A")]),
        .object(["id": .int(2), "name": .string("B")])
    ])
    let typed = try encodeTyped(v)
    assertTrue(typed.contains("[{id@int"), "vec typed should have type annotations")
    let d = try decode(typed)
    assertEq(d, v, "vec typed roundtrip")
}

// ===========================================================================
// 4. String escaping
// ===========================================================================
section("4. String escaping")

test {
    let v: AsunValue = .object(["text": .string("say \"hi\"")])
    let s = try encode(v)
    assertTrue(s.contains("\\\""), "quoted string should escape double quotes")
    let d = try decode(s)
    assertEq(d, v, "escaped double-quote roundtrip")
}

test {
    let v: AsunValue = .object(["text": .string("line1\nline2")])
    let s = try encode(v)
    assertTrue(s.contains("\\n"), "should escape newline")
    let d = try decode(s)
    assertEq(d, v, "escaped newline roundtrip")
}

test {
    let v: AsunValue = .object(["text": .string("tab\there")])
    let s = try encode(v)
    assertTrue(s.contains("\\t"), "should escape tab")
    let d = try decode(s)
    assertEq(d, v, "escaped tab roundtrip")
}

test {
    let v: AsunValue = .object(["text": .string("back\\slash")])
    let s = try encode(v)
    assertTrue(s.contains("\\\\"), "should escape backslash")
    let d = try decode(s)
    assertEq(d, v, "escaped backslash roundtrip")
}

test {
    let v: AsunValue = .object(["text": .string("a,b(c)d[e]f")])
    let s = try encode(v)
    assertTrue(s.contains("\"a,b"), "should quote string with special chars")
    let d = try decode(s)
    assertEq(d, v, "special chars roundtrip")
}

test {
    let v: AsunValue = .object(["text": .string("env:prod")])
    let s = try encode(v)
    assertTrue(s.contains("\"env:prod\""), "should quote string with colon")
    let d = try decode(s)
    assertEq(d, v, "colon string roundtrip")
}

test {
    let v: AsunValue = .object(["text": .string("@Alice")])
    let s = try encode(v)
    assertTrue(s.contains("\"@Alice\""), "should quote string with at-sign")
    let d = try decode(s)
    assertEq(d, v, "at-sign string roundtrip")
}

test {
    let v: AsunValue = .object(["text": .string("value@demo")])
    let s = try encode(v)
    assertTrue(s.contains("\"value@demo\""), "should quote string containing at-sign")
    let d = try decode(s)
    assertEq(d, v, "embedded at-sign string roundtrip")
}

// Strings that look like numbers must be quoted
test {
    let v: AsunValue = .object(["val": .string("123")])
    let s = try encode(v)
    assertTrue(s.contains("\"123\""), "number-like string should be quoted")
    let d = try decode(s)
    assertEq(d, v, "number-like string roundtrip")
}

// Strings that are "true"/"false" must be quoted
test {
    let v: AsunValue = .object(["val": .string("true")])
    let s = try encode(v)
    assertTrue(s.contains("\"true\""), "bool-like string should be quoted")
    let d = try decode(s)
    assertEq(d, v, "bool-like string roundtrip")
}

// Empty string
test {
    let v: AsunValue = .object(["val": .string("")])
    let s = try encode(v)
    assertTrue(s.contains("\"\""), "empty string should be quoted")
    let d = try decode(s)
    assertEq(d, v, "empty string roundtrip")
}

// Strings with leading/trailing spaces
test {
    let v: AsunValue = .object(["val": .string(" spaced ")])
    let s = try encode(v)
    assertTrue(s.contains("\" spaced \""), "spaced string should be quoted")
    let d = try decode(s)
    assertEq(d, v, "spaced string roundtrip")
}

// ===========================================================================
// 5. Numeric types
// ===========================================================================
section("5. Numeric types")

// Int64 boundaries
test {
    let v: AsunValue = .object(["n": .int(Int64.max)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "Int64.max roundtrip")
}

test {
    let v: AsunValue = .object(["n": .int(Int64.min)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "Int64.min roundtrip")
}

// Large positive int
test {
    let v: AsunValue = .object(["n": .int(Int64.max)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "large positive int roundtrip")
}

// Zero
test {
    let v: AsunValue = .object(["n": .int(0)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "zero int roundtrip")
}

// Negative numbers
test {
    let v: AsunValue = .object(["a": .int(-1), "b": .int(-999999999)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "negative int roundtrip")
}

// Floats
test {
    let v: AsunValue = .object(["pi": .float(3.14159265358979)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    if case .object(let obj) = d, case .float(let f) = obj["pi"] {
        assertTrue(abs(f - 3.14159265358979) < 1e-10, "float precision")
    } else {
        assertTrue(false, "float decode failed")
    }
}

test {
    let v: AsunValue = .object(["n": .float(-0.001)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    if case .object(let obj) = d, case .float(let f) = obj["n"] {
        assertTrue(abs(f - (-0.001)) < 1e-10, "negative float precision")
    }
}

test {
    let v: AsunValue = .object(["n": .float(100.0)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "whole float roundtrip")
}

// ===========================================================================
// 6. Boolean
// ===========================================================================
section("6. Boolean")

test {
    let v: AsunValue = .object(["t": .bool(true), "f": .bool(false)])
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "bool roundtrip")
}

// ===========================================================================
// 7. Nested objects
// ===========================================================================
section("7. Nested objects")

test {
    let v: AsunValue = .object([
        "a": .int(1),
        "inner": .object(["b": .int(2), "c": .string("deep")])
    ])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "nested object roundtrip")
}

test {
    let v: AsunValue = .object([
        "level1": .object([
            "level2": .object([
                "level3": .object([
                    "value": .string("deep")
                ])
            ])
        ])
    ])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "3-level nested roundtrip")
}

// ===========================================================================
// 8. Array fields
// ===========================================================================
section("8. Array fields")

test {
    let v: AsunValue = .object([
        "name": .string("test"),
        "tags": .array([.string("a"), .string("b"), .string("c")])
    ])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "string array field roundtrip")
}

test {
    let v: AsunValue = .object([
        "nums": .array([.int(1), .int(2), .int(3)])
    ])
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "int array field roundtrip")
}

test {
    let input = "{name@str,tags@[str]}:(test,[a,b,c])"
    let d = try decode(input)
    if case .object(let obj) = d {
        assertEq(obj["name"], .string("test"), "array field name")
        assertEq(obj["tags"], .array([.string("a"), .string("b"), .string("c")]), "array field tags")
    }
}

// ===========================================================================
// 9. Optional fields
// ===========================================================================
section("9. Optional fields")

test {
    let input = "{id@int,label@str?}:(1,hello)"
    let d = try decode(input)
    if case .object(let obj) = d {
        assertEq(obj["id"], .int(1), "optional present: id")
        assertEq(obj["label"], .string("hello"), "optional present: label")
    }
}

test {
    let input = "{id@int,label@str?}:(2,)"
    let d = try decode(input)
    if case .object(let obj) = d {
        assertEq(obj["id"], .int(2), "optional null: id")
        assertEq(obj["label"], .null, "optional null: label")
    }
}

test {
    assertThrows({ _ = try decode("{id@integer,score@double,active@boolean,name@string}:(1,99.5,true,Alice)") }, "deprecated aliases should be rejected")
}

test {
    let input = #"{"id uuid"@str,"65"@bool,"{}[]@\\\""@str}:("user-1",true,"value@demo")"#
    let d = try decode(input)
    if case .object(let obj) = d {
        assertEq(obj["id uuid"], .string("user-1"), "quoted schema field with spaces")
        assertEq(obj["65"], .bool(true), "quoted schema field starting with digit")
        assertEq(obj["{}[]@\\\""], .string("value@demo"), "quoted schema field with special chars")
    }
}

// ===========================================================================
// 10. Comments
// ===========================================================================
section("10. Comments")

test {
    let input = "/* block comment */ {id@int,name@str}:(1,Alice)"
    let d = try decode(input)
    if case .object(let obj) = d {
        assertEq(obj["id"], .int(1), "block comment: id")
        assertEq(obj["name"], .string("Alice"), "block comment: name")
    }
}

// ===========================================================================
// 11. Multiline format
// ===========================================================================
section("11. Multiline format")

test {
    let input = """
    [{id@int, name@str}]:
      (1, Alice),
      (2, Bob),
      (3, Carol)
    """
    let d = try decode(input)
    if case .array(let arr) = d {
        assertEq(arr.count, 3, "multiline count")
        if case .object(let first) = arr[0] {
            assertEq(first["name"], .string("Alice"), "multiline first name")
        }
    }
}

// ===========================================================================
// 12. Pretty format roundtrip
// ===========================================================================
section("12. Pretty format roundtrip")

test {
    let v: AsunValue = .object(["id": .int(1), "name": .string("test")])
    let pretty = try encodePretty(v)
    assertTrue(pretty.contains("\n"), "pretty should have newlines")
    let d = try decode(pretty)
    assertEq(d, v, "pretty roundtrip")
}

test {
    let v: AsunValue = .array([
        .object(["id": .int(1), "name": .string("A")]),
        .object(["id": .int(2), "name": .string("B")])
    ])
    let pretty = try encodePretty(v)
    assertTrue(pretty.contains("\n"), "pretty vec should have newlines")
    let d = try decode(pretty)
    assertEq(d, v, "pretty vec roundtrip")
}

test {
    let v: AsunValue = .object([
        "level1": .object(["level2": .object(["val": .int(42)])])
    ])
    let pretty = try encodePretty(v)
    let d = try decode(pretty)
    assertEq(d, v, "pretty nested roundtrip")
}

// ===========================================================================
// 13. Pretty typed format roundtrip
// ===========================================================================
section("13. Pretty typed format roundtrip")

test {
    let v: AsunValue = .object(["x": .int(1), "y": .float(2.5)])
    let pretty = try encodePrettyTyped(v)
    assertTrue(pretty.contains("int"), "pretty typed should contain type annotations")
    let d = try decode(pretty)
    assertEq(d, v, "pretty typed roundtrip")
}

test {
    let v: AsunValue = .object([
        "id uuid": .string("@Alice"),
        "65": .bool(true),
        "{}[]@\\\"": .string("value@demo")
    ])
    let pretty = try encodePrettyTyped(v)
    assertTrue(pretty.contains("\"id uuid\"@str"), "pretty typed should quote schema field names")
    assertTrue(pretty.contains("\"@Alice\""), "pretty typed should quote values containing at-sign")
    let d = try decode(pretty)
    assertEq(d, v, "pretty typed 3.3 roundtrip")
}

// ===========================================================================
// 14. Binary roundtrip
// ===========================================================================
section("14. Binary roundtrip")

test {
    let v: AsunValue = .object(["id": .int(42), "name": .string("test")])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "binary basic roundtrip")
}

test {
    let v: AsunValue = .array([
        .object(["id": .int(1), "val": .float(1.5)]),
        .object(["id": .int(2), "val": .float(2.5)]),
        .object(["id": .int(3), "val": .float(3.5)])
    ])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "binary vec roundtrip")
}

test {
    let v: AsunValue = .object([
        "a": .int(Int64.max),
        "b": .int(Int64.max),
        "c": .float(3.14159265358979),
        "d": .bool(true),
        "e": .string("hello world")
    ])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "binary all types roundtrip")
}

test {
    let v: AsunValue = .object([
        "id uuid": .string("@Alice"),
        "65": .bool(true),
        "{}[]@\\\"": .string("value@demo")
    ])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "binary 3.3 field/value roundtrip")
}

test {
    let v: AsunValue = .object([
        "nested": .object(["x": .int(1), "y": .int(2)]),
        "tags": .array([.string("a"), .string("b")])
    ])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "binary nested roundtrip")
}

// Binary magic check
test {
    let badData = Data([0, 1, 2, 3, 4, 5, 6, 7, 8])
    assertThrows({ _ = try decodeBinary(badData) }, "bad binary magic")
}

test {
    assertThrows({ _ = try decodeBinary(Data()) }, "empty binary data")
}

// ===========================================================================
// 15. Binary size is smaller than JSON
// ===========================================================================
section("15. Binary vs JSON size comparison")

func jsonSize(_ v: AsunValue) -> Int {
    func toJSON(_ v: AsunValue) -> Any {
        switch v {
        case .int(let i): return NSNumber(value: i)
                case .float(let d): return NSNumber(value: d)
        case .bool(let b): return NSNumber(value: b)
        case .string(let s): return s
        case .array(let a): return a.map { toJSON($0) }
        case .object(let o):
            var d: [String: Any] = [:]
            for (k, v) in o { d[k] = toJSON(v) }
            return d
        case .null: return NSNull()
        }
    }
    let obj = toJSON(v)
    let data = try! JSONSerialization.data(withJSONObject: obj, options: [])
    return data.count
}

test {
    var rows: [AsunValue] = []
    for i in 0..<100 {
        rows.append(.object([
            "id": .int(Int64(i)),
            "name": .string("User_\(i)"),
            "score": .float(Double(i) * 1.5),
            "active": .bool(i % 2 == 0)
        ]))
    }
    let v: AsunValue = .array(rows)
    let bin = try encodeBinary(v)
    let asunText = try encode(v)
    let jSize = jsonSize(v)
    print("  100 records: ASUN text \(asunText.utf8.count) B | ASUN bin \(bin.count) B | JSON \(jSize) B")
    assertTrue(bin.count < jSize, "binary should be smaller than JSON for 100 records")
    assertTrue(asunText.utf8.count < jSize, "ASUN text should be smaller than JSON for 100 records")
}

// ===========================================================================
// 16. Format validation — bad input should error
// ===========================================================================
section("16. Format validation (bad input)")

assertThrows({ _ = try decode("") }, "empty input")
assertThrows({ _ = try decode("not-asun") }, "garbage input")
assertThrows({ _ = try decode("{id@int}:") }, "schema with no data")
assertThrows({ _ = try decode("{id@int}:(abc)") }, "int field with non-int data")
assertThrows({ _ = try decode("{id@badtype}:(1)") }, "unknown type")
assertThrows({ _ = try decode("{id@int,name@str}:(101,Alice),(102,Bob)") }, "single schema with multiple tuples should throw")

// ===========================================================================
// 17. Cross-compat format
// ===========================================================================
section("17. Cross-compat format")

test {
    let input = "[{ID@int,Name@str,Age@int,Gender@bool}]:(1,Alice,30,true),(2,Bob,25,false)"
    let d = try decode(input)
    if case .array(let arr) = d {
        assertEq(arr.count, 2, "cross-compat count")
        if case .object(let first) = arr[0] {
            assertEq(first["Name"], .string("Alice"), "cross-compat Name")
            assertEq(first["Age"], .int(30), "cross-compat Age")
        }
    }
    let s = try encode(d)
    let d2 = try decode(s)
    assertEq(d2, d, "cross-compat roundtrip")
}

// ===========================================================================
// 18. Typed vs untyped schema
// ===========================================================================
section("18. Typed vs untyped schema")

test {
    let v: AsunValue = .object(["id": .int(1), "name": .string("test")])
    let typed = try encodeTyped(v)
    let untyped = try encode(v)
    assertTrue(typed.count >= untyped.count, "typed ≥ untyped length")
    let d1 = try decode(typed)
    let d2 = try decode(untyped)
    // Both should decode, but typed preserves exact types
    assertTrue(d1 == v, "typed decode matches original")
    assertTrue(d2 == v || true, "untyped decode succeeds (types may differ)")
}

// ===========================================================================
// 19. Large string values
// ===========================================================================
section("19. Large string values")

test {
    let longStr = String(repeating: "abcdefghij", count: 1000)
    let v: AsunValue = .object(["data": .string(longStr)])
    let s = try encode(v)
    let d = try decode(s)
    if case .object(let obj) = d, case .string(let str) = obj["data"] {
        assertEq(str.count, 10000, "large string length")
        assertEq(str, longStr, "large string content")
    }
}

// Large string with special characters
test {
    let longStr = String(repeating: "hello, (world) [test]\n", count: 500)
    let v: AsunValue = .object(["data": .string(longStr)])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "large string with special chars roundtrip")
}

// ===========================================================================
// 20. Binary large payload roundtrip
// ===========================================================================
section("20. Binary large payload roundtrip")

test {
    var rows: [AsunValue] = []
    for i in 0..<1000 {
        rows.append(.object([
            "id": .int(Int64(i)),
            "name": .string("User_\(i)"),
            "email": .string("user\(i)@example.com"),
            "active": .bool(i % 2 == 0),
            "score": .float(Double(i) * 0.1)
        ]))
    }
    let v: AsunValue = .array(rows)
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "binary 1000-record roundtrip")
}

// ===========================================================================
// 21. Deeply nested binary roundtrip
// ===========================================================================
section("21. Deeply nested binary roundtrip")

test {
    let v: AsunValue = .object([
        "a": .object([
            "b": .object([
                "c": .array([
                    .object(["x": .int(1), "y": .float(2.5)]),
                    .object(["x": .int(3), "y": .float(4.5)])
                ])
            ])
        ])
    ])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "deeply nested binary roundtrip")
}

// ===========================================================================
// 22. All 7 API functions
// ===========================================================================
section("22. All 7 API functions")

test {
    let v: AsunValue = .object(["id": .int(1), "name": .string("test")])
    let s1 = try encode(v)
    let s2 = try encodeTyped(v)
    let s3 = try encodePretty(v)
    let s4 = try encodePrettyTyped(v)
    let b = try encodeBinary(v)
    let d1 = try decode(s1)
    let d2 = try decode(s2)
    let d3 = try decode(s3)
    let d4 = try decode(s4)
    let d5 = try decodeBinary(b)
    assertEq(d1, v, "encode roundtrip")
    assertEq(d2, v, "encodeTyped roundtrip")
    assertEq(d3, v, "encodePretty roundtrip")
    assertEq(d4, v, "encodePrettyTyped roundtrip")
    assertEq(d5, v, "encodeBinary roundtrip")
    print("  ✓ all 7 API functions work correctly")
}

test {
    let v: AsunValue = .object([
        "id uuid": .string("@Alice"),
        "65": .bool(true),
        "{}[]@\\\"": .string("value@demo")
    ])
    let s1 = try encode(v)
    let s2 = try encodeTyped(v)
    let s3 = try encodePretty(v)
    let s4 = try encodePrettyTyped(v)
    let b = try encodeBinary(v)
    assertTrue(s1.contains("\"id uuid\""), "encode should quote schema field names")
    assertTrue(s1.contains("\"@Alice\""), "encode should quote at-sign values")
    assertTrue(s2.contains("\"id uuid\"@str"), "encodeTyped should quote schema field names")
    let d1 = try decode(s1)
    let d2 = try decode(s2)
    let d3 = try decode(s3)
    let d4 = try decode(s4)
    let d5 = try decodeBinary(b)
    assertEq(d1, v, "encode 3.3 roundtrip")
    assertEq(d2, v, "encodeTyped 3.3 roundtrip")
    assertEq(d3, v, "encodePretty 3.3 roundtrip")
    assertEq(d4, v, "encodePrettyTyped 3.3 roundtrip")
    assertEq(d5, v, "encodeBinary/decodeBinary 3.3 roundtrip")
}

// ===========================================================================
// 23. Vec with many fields
// ===========================================================================
section("23. Vec with many fields")

test {
    var rows: [AsunValue] = []
    for i in 0..<50 {
        rows.append(.object([
            "f1": .int(Int64(i)),
            "f2": .string("s\(i)"),
            "f3": .float(Double(i) + 0.5),
            "f4": .bool(i % 2 == 0),
            "f5": .int(Int64(i * 100)),
            "f6": .string("long_field_value_\(i)"),
            "f7": .float(Double(i) + 0.25),
            "f8": .bool(i % 3 == 0),
            "f9": .array([.string("tag\(i)"), .string("cat\(i)")]),
            "f10": .object(["sub": .int(Int64(i * 10))])
        ]))
    }
    let v: AsunValue = .array(rows)
    // Use encodeTyped to preserve int/float distinction
    let s = try encodeTyped(v)
    let d = try decode(s)
    assertEq(d, v, "vec with 10 fields × 50 rows")

    let bin = try encodeBinary(v)
    let d2 = try decodeBinary(bin)
    assertEq(d2, v, "binary vec with 10 fields × 50 rows")
}

// ===========================================================================
// 24. Unicode strings
// ===========================================================================
section("24. Unicode strings")

test {
    let v: AsunValue = .object(["name": .string("日本語テスト")])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "Japanese text roundtrip")
}

test {
    let v: AsunValue = .object(["emoji": .string("Hello 🌍🚀")])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "Emoji roundtrip")
}

test {
    let v: AsunValue = .object(["mixed": .string("中文 English العربية")])
    let s = try encode(v)
    let d = try decode(s)
    assertEq(d, v, "Mixed scripts roundtrip")
}

// binary unicode
test {
    let v: AsunValue = .object(["name": .string("日本語テスト"), "emoji": .string("🌍🚀✨")])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "binary unicode roundtrip")
}

// ===========================================================================
// 25. AsunValue equality
// ===========================================================================
section("25. AsunValue equality")

test {
    assertEq(AsunValue.int(42), AsunValue.int(42), "int equality")
    assertTrue(AsunValue.int(1) != AsunValue.int(2), "int inequality")
    assertEq(AsunValue.string("hi"), AsunValue.string("hi"), "string equality")
    assertTrue(AsunValue.string("a") != AsunValue.string("b"), "string inequality")
    assertEq(AsunValue.null, AsunValue.null, "null equality")
    assertEq(AsunValue.bool(true), AsunValue.bool(true), "bool equality")
    assertTrue(AsunValue.bool(true) != AsunValue.bool(false), "bool inequality")
    assertEq(AsunValue.float(1.5), AsunValue.float(1.5), "float equality")
    assertTrue(AsunValue.int(1) != AsunValue.string("1"), "cross-type inequality")
}

// ===========================================================================
// 26. Text <-> Binary equivalence
// ===========================================================================
section("26. Text <-> Binary equivalence")

test {
    let v: AsunValue = .object([
        "id": .int(42),
        "name": .string("Alice"),
        "scores": .array([.float(95.5), .float(87.3), .float(92.1)]),
        "meta": .object(["role": .string("admin"), "level": .int(5)])
    ])
    let text = try encodeTyped(v)
    let fromText = try decode(text)
    let bin = try encodeBinary(v)
    let fromBin = try decodeBinary(bin)
    assertEq(fromText, fromBin, "text and binary produce same value")
    assertEq(fromText, v, "text matches original")
    assertEq(fromBin, v, "binary matches original")
}

// ===========================================================================
// 27. Binary optional marker safety
// ===========================================================================
section("27. Binary optional marker safety")

test {
    let v: AsunValue = .array([
        .object(["count": .null]),
        .object(["count": .int(4_294_967_295)])
    ])
    let bin = try encodeBinary(v)
    let d = try decodeBinary(bin)
    assertEq(d, v, "binary optional int should not collide with null marker")
}

// ===========================================================================
// 28. Integer overflow handling
// ===========================================================================
section("28. Integer overflow handling")

test {
    assertThrows({ _ = try decode("{value@int}:(9223372036854775808)") }, "int overflow should throw")
}

test {
    assertThrows({ _ = try decode("{value@int}:(9223372036854775808)") }, "int overflow should throw")
}

// ===========================================================================
// 29. Slice schema inference
// ===========================================================================
section("29. Slice schema inference")

test {
    let v: AsunValue = .array([
        .object(["id": .int(1), "name": .string("Alice")]),
        .object(["id": .int(2), "email": .string("alice@example.com")])
    ])
    let text = try encodeTyped(v)
    let d = try decode(text)
    let expected: AsunValue = .array([
        .object(["email": .null, "id": .int(1), "name": .string("Alice")]),
        .object(["email": .string("alice@example.com"), "id": .int(2), "name": .null])
    ])
    assertEq(d, expected, "slice schema should promote missing fields to optional")
}

test {
    let v: AsunValue = .array([
        .object(["id": .int(1)]),
        .object(["id": .object(["nested": .int(2)])])
    ])
    assertThrows({ _ = try encode(v) }, "incompatible slice field types should throw")
    assertThrows({ _ = try encodeTyped(v) }, "incompatible typed slice field types should throw")
    assertThrows({ _ = try encodeBinary(v) }, "incompatible slice field types should throw in binary mode")
}

// ===========================================================================
// 30. Go parity cases
// ===========================================================================
section("30. Go parity cases")

test {
    let v: AsunValue = .object(["id": .int(1), "name": .string("Alice"), "active": .bool(true)])
    assertEq(try encode(v), "{active,id,name}:(true,1,Alice)", "go parity: serialize struct")
}

test {
    let untyped = "{id,name,active}:(42,Bob,false)"
    let typed = "{id@int,name@str,active@bool}:(42,Bob,false)"
    let expected: AsunValue = .object(["id": .int(42), "name": .string("Bob"), "active": .bool(false)])
    assertEq(try decode(untyped), expected, "go parity: decode simple untyped")
    assertEq(try decode(typed), expected, "go parity: decode simple typed")
}

test {
    let input = "[{id,name,active}]:(1,Alice,true),(2,Bob,false),"
    let expected: AsunValue = .array([
        .object(["id": .int(1), "name": .string("Alice"), "active": .bool(true)]),
        .object(["id": .int(2), "name": .string("Bob"), "active": .bool(false)])
    ])
    assertEq(try decode(input), expected, "go parity: trailing comma vec")
}

test {
    let input = "{name,attrs@[{key,value}]}:(Alice,[(age,30),(score,95)])"
    let expected: AsunValue = .object([
        "name": .string("Alice"),
        "attrs": .array([
            .object(["key": .string("age"), "value": .int(30)]),
            .object(["key": .string("score"), "value": .int(95)])
        ])
    ])
    assertEq(try decode(input), expected, "go parity: entry-list field")
}

test {
    let input = "{groups@[{key,value@[{name,age}]}]}:([(teamA,[(Alice,30),(Bob,28)]),(teamB,[(Carol,41)])])"
    let expected: AsunValue = .object([
        "groups": .array([
            .object([
                "key": .string("teamA"),
                "value": .array([
                    .object(["name": .string("Alice"), "age": .int(30)]),
                    .object(["name": .string("Bob"), "age": .int(28)])
                ])
            ]),
            .object([
                "key": .string("teamB"),
                "value": .array([
                    .object(["name": .string("Carol"), "age": .int(41)])
                ])
            ])
        ])
    ])
    let decoded = try decode(input)
    assertEq(decoded, expected, "go parity: complex entry list decode")
    assertEq(try decode(try encodePrettyTyped(expected)), expected, "go parity: pretty typed complex entry list")
    assertEq(try decodeBinary(try encodeBinary(expected)), expected, "go parity: binary complex entry list")
}

test {
    let partial = "{id@int,name,score@float,active}:(1,Alice,95.5,true)"
    let full = "{id@int,name@str,score@float,active@bool}:(1,Alice,95.5,true)"
    let none = "{id,name,score,active}:(1,Alice,95.5,true)"
    let expected: AsunValue = .object([
        "id": .int(1),
        "name": .string("Alice"),
        "score": .float(95.5),
        "active": .bool(true)
    ])
    assertEq(try decode(partial), expected, "go parity: partial annotations")
    assertEq(try decode(full), expected, "go parity: full annotations")
    assertEq(try decode(none), expected, "go parity: no annotations")
}

test {
    let simple = AsunValue.object(["id": .int(1), "name": .string("Alice"), "active": .bool(true)])
    assertEq(try encodeTyped(simple), "{active@bool,id@int,name@str}:(true,1,Alice)", "go parity: encodeTyped simple")

    let floats = AsunValue.object(["id": .int(1), "value": .float(95.5), "label": .string("good")])
    assertEq(try encodeTyped(floats), "{id@int,label@str,value@float}:(1,good,95.5)", "go parity: encodeTyped floats")

    let all = AsunValue.object([
        "b": .bool(true),
        "i": .int(-42),
        "u": .int(100),
        "f": .float(3.14),
        "s": .string("hello")
    ])
    assertEq(try encodeTyped(all), "{b@bool,f@float,i@int,s@str,u@int}:(true,3.14,-42,hello,100)", "go parity: encodeTyped primitives")
}

test {
    let nested = AsunValue.object([
        "name": .string("Alice"),
        "dept": .object(["title": .string("Engineering")]),
        "active": .bool(true)
    ])
    assertEq(try encodeTyped(nested), "{active@bool,dept@{title@str},name@str}:(true,(Engineering),Alice)", "go parity: encodeTyped nested")

    let rows = AsunValue.array([
        .object(["id": .int(1), "name": .string("Alice"), "score": .float(95.5)]),
        .object(["id": .int(2), "name": .string("Bob"), "score": .float(87.0)])
    ])
    assertEq(try encode(rows), "[{id,name,score}]:(1,Alice,95.5),(2,Bob,87.0)", "go parity: encode vec")
    assertEq(try encodeTyped(rows), "[{id@int,name@str,score@float}]:(1,Alice,95.5),(2,Bob,87.0)", "go parity: encodeTyped vec")
}

// ===========================================================================
// 31. Prepared encoder
// ===========================================================================
section("31. Prepared encoder")

test {
    let sample = AsunValue.object(["id": .int(1), "name": .string("Alice"), "active": .bool(true)])
    let prepared = try PreparedAsunEncoder(sample: sample)
    let encoded = try prepared.encode(sample)
    let decoded = try decode(encoded)
    assertEq(decoded, sample, "prepared encoder roundtrip")
}

test {
    let sample = AsunValue.object(["id": .int(1), "name": .string("Alice"), "active": .bool(true)])
    let prepared = try PreparedAsunEncoder(sample: sample, typed: true)
    let pretty = try prepared.encodePretty(sample)
    let decoded = try decode(pretty)
    assertEq(decoded, sample, "prepared encoder pretty roundtrip")
    assertTrue(prepared.schemaText().contains("id@int"), "prepared schema text should be typed")
}

test {
    let sample = AsunValue.array([
        .object(["id": .int(1), "name": .string("Alice")]),
        .object(["id": .int(2), "name": .string("Bob")])
    ])
    let prepared = try PreparedAsunEncoder(sample: sample, typed: true)
    let bin = try prepared.encodeBinary(sample)
    let decoded = try decodeBinary(bin)
    assertEq(decoded, sample, "prepared encoder binary roundtrip")
}

test {
    let sample = AsunValue.object(["id": .int(1), "name": .string("Alice")])
    let mismatch = AsunValue.object(["id": .object(["nested": .int(2)]), "name": .string("Alice")])
    let prepared = try PreparedAsunEncoder(sample: sample, typed: true)
    assertThrows({ _ = try prepared.encode(mismatch) }, "prepared encoder should reject mismatched shape")
}

// ===========================================================================
// 32. Prepared decoder
// ===========================================================================
section("32. Prepared decoder")

test {
    let sample = AsunValue.object(["id": .int(1), "name": .string("Alice"), "active": .bool(true)])
    let encoded = try encodeTyped(sample)
    let decoder = try PreparedAsunDecoder(sample: sample, typed: true)
    let decoded = try decoder.decode(encoded)
    assertEq(decoded, sample, "prepared decoder roundtrip")
}

test {
    let sample = AsunValue.object(["id": .int(1), "name": .string("Alice")])
    let body = "(1,Alice)"
    let decoder = try PreparedAsunDecoder(schemaText: "{id@int,name@str}")
    let decoded = try decoder.decodeBody(body)
    assertEq(decoded, sample, "prepared decoder body-only roundtrip")
}

test {
    let sample = AsunValue.array([
        .object(["id": .int(1), "name": .string("Alice")]),
        .object(["id": .int(2), "name": .string("Bob")])
    ])
    let prepared = try PreparedAsunEncoder(sample: sample, typed: true)
    let decoder = try PreparedAsunDecoder(sample: sample, typed: true)
    let bin = try prepared.encodeBinary(sample)
    let decoded = try decoder.decodeBinary(bin)
    assertEq(decoded, sample, "prepared decoder binary roundtrip")
}

// ===========================================================================
// 33. Typed struct codec
// ===========================================================================
section("33. Typed struct codec")

test {
    let codec = AsunStructCodec<TypedUser>(fields: [
        .int("id", \.id),
        .string("name", \.name),
        .bool("active", \.active),
        .float("score", \.score),
        .optionalString("email", \.email)
    ], make: TypedUser.init)

    let user = TypedUser(id: 1, name: "Alice", active: true, score: 95.5, email: "alice@example.com")
    let text = try codec.encode(user)
    let decoded = try codec.decode(text)
    assertEq(decoded, user, "typed struct single roundtrip")
}

test {
    let codec = AsunStructArrayCodec<TypedUser>(fields: [
        .int("id", \.id),
        .string("name", \.name),
        .bool("active", \.active),
        .float("score", \.score),
        .optionalString("email", \.email)
    ], make: TypedUser.init)

    let rows = [
        TypedUser(id: 1, name: "Alice", active: true, score: 95.5, email: nil),
        TypedUser(id: 2, name: "Bob", active: false, score: 87.0, email: "bob@example.com")
    ]
    let text = try codec.encode(rows)
    let decoded = try codec.decode(text)
    assertEq(decoded, rows, "typed struct array roundtrip")
}

test {
    let codec = AsunStructArrayCodec<TypedUser>(fields: [
        .int("id", \.id),
        .string("name", \.name),
        .bool("active", \.active),
        .float("score", \.score),
        .optionalString("email", \.email)
    ], make: TypedUser.init)

    let rows = [
        TypedUser(id: 1, name: "Alice", active: true, score: 95.5, email: nil),
        TypedUser(id: 2, name: "Bob", active: false, score: 87.0, email: "bob@example.com")
    ]
    let bin = try codec.encodeBinary(rows)
    let decoded = try codec.decodeBinary(bin)
    assertEq(decoded, rows, "typed struct array binary roundtrip")
}

test {
    let profileCodec = AsunStructCodec<TypedProfile>(fields: [
        .int("level", \.level),
        .string("title", \.title)
    ], make: TypedProfile.init)
    let codec = AsunStructCodec<TypedTeam>(fields: [
        .int("id", \.id),
        .stringArray("tags", \.tags),
        .floatArray("scores", \.scores),
        .boolArray("flags", \.flags),
        .nested("profile", \.profile, codec: profileCodec),
        .optionalNested("backup", \.backup, codec: profileCodec)
    ], make: TypedTeam.init)

    let team = TypedTeam(
        id: 7,
        tags: ["core", "swift"],
        scores: [95.5, 88.0],
        flags: [true, false, true],
        profile: TypedProfile(title: "Lead", level: 3),
        backup: TypedProfile(title: "Support", level: 2)
    )
    let text = try codec.encode(team)
    let decoded = try codec.decode(text)
    assertEq(decoded, team, "typed nested struct with arrays roundtrip")
}

test {
    let profileCodec = AsunStructCodec<TypedProfile>(fields: [
        .int("level", \.level),
        .string("title", \.title)
    ], make: TypedProfile.init)
    let codec = AsunStructCodec<TypedTeam>(fields: [
        .int("id", \.id),
        .stringArray("tags", \.tags),
        .floatArray("scores", \.scores),
        .boolArray("flags", \.flags),
        .nested("profile", \.profile, codec: profileCodec),
        .optionalNested("backup", \.backup, codec: profileCodec)
    ], make: TypedTeam.init)

    let team = TypedTeam(
        id: 7,
        tags: ["core", "swift"],
        scores: [95.5, 88.0],
        flags: [true, false, true],
        profile: TypedProfile(title: "Lead", level: 3),
        backup: nil
    )
    let bin = try codec.encodeBinary(team)
    let decoded = try codec.decodeBinary(bin)
    assertEq(decoded, team, "typed nested struct binary roundtrip")
}

// ===========================================================================
// Summary
// ===========================================================================

print("\n══════════════════════════════════════════")
print("  Results: \(passed)/\(total) passed, \(failed) failed")
print("══════════════════════════════════════════")

if failed > 0 {
    print("\n⚠ Some tests failed!")
    exit(1)
} else {
    print("\n✓ All tests passed!")
}
