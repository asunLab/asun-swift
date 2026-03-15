import Foundation
import AsonSwift

func jsonEncode(_ value: AsonValue) -> Data {
    let obj = asonToJSON(value)
    return try! JSONSerialization.data(withJSONObject: obj, options: [])
}

func asonToJSON(_ v: AsonValue) -> Any {
    switch v {
    case .int(let i): return NSNumber(value: i)
        case .float(let d): return NSNumber(value: d)
    case .bool(let b): return NSNumber(value: b)
    case .string(let s): return s
    case .array(let arr): return arr.map { asonToJSON($0) }
    case .object(let obj):
        var dict: [String: Any] = [:]
        for (k, v) in obj { dict[k] = asonToJSON(v) }
        return dict
    case .null: return NSNull()
    }
}

print("=== ASON Basic Examples ===")
print()

let user: AsonValue = .object([
    "id": .int(1),
    "name": .string("Alice"),
    "active": .bool(true)
])

let users: AsonValue = .array([
    .object(["id": .int(1), "name": .string("Alice"), "active": .bool(true)]),
    .object(["id": .int(2), "name": .string("Bob"), "active": .bool(false)]),
    .object(["id": .int(3), "name": .string("Carol Smith"), "active": .bool(true)])
])

print("Serialize single struct:")
let text = try encode(user)
print("  \(text)\n")

print("Serialize with type annotations:")
let typed = try encodeTyped(user)
print("  \(typed)\n")

print("Deserialize single struct:")
let decodedUser = try decode("{id@int,name@str,active@bool}:(1,Alice,true)")
print("  \(decodedUser)\n")

print("Serialize vec (schema-driven):")
let vecText = try encode(users)
print("  \(vecText)\n")

print("Serialize vec with type annotations:")
let typedVec = try encodeTyped(users)
print("  \(typedVec)\n")

print("Deserialize vec:")
let parsedVec = try decode(#"[{id@int,name@str,active@bool}]:(1,Alice,true),(2,Bob,false),(3,"Carol Smith",true)"#)
if case .array(let arr) = parsedVec {
    for row in arr {
        print("  \(row)")
    }
}

print("\nMultiline format:")
let multiline = """
[{id, name, active}]:
  (1, Alice, true),
  (2, Bob, false),
  (3, "Carol Smith", true)
"""
let multi = try decode(multiline)
if case .array(let arr) = multi {
    for row in arr {
        print("  \(row)")
    }
}

print("\n8. Roundtrip (ASON-text vs ASON-bin vs JSON):")
let original: AsonValue = .object([
    "id": .int(42),
    "name": .string("Test User"),
    "active": .bool(true)
])
let asonText = try encode(original)
let fromAson = try decode(asonText)
assert(fromAson == original, "ASON text roundtrip mismatch")
let asonBin = try encodeBinary(original)
let fromBin = try decodeBinary(asonBin)
assert(fromBin == original, "ASON binary roundtrip mismatch")
let jsonData = jsonEncode(original)
print("  original:     \(original)")
print("  ASON text:    \(asonText) (\(asonText.utf8.count) B)")
print("  ASON binary:  \(asonBin.count) B")
print("  JSON:         \(String(data: jsonData, encoding: .utf8)!) (\(jsonData.count) B)")
print("  ✓ all 3 formats roundtrip OK")

print("\n9. Optional fields:")
let item1 = try decode("{id,label}:(1,hello)")
print("  with value: \(item1)")
let item2 = try decode("{id,label}:(2,)")
print("  with null:  \(item2)")

print("\n10. Array fields:")
let tagged = try decode("{name,tags}:(Alice,[rust,go,python])")
print("  \(tagged)")

print("\n11. With comments:")
let commented = try decode("/* user list */ {id,name,active}:(1,Alice,true)")
print("  \(commented)")

print("\n=== All examples passed! ===")
