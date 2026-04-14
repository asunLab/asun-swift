import Foundation
import AsunSwift

func jsonEncode(_ value: AsunValue) -> Data {
    let obj = asunToJSON(value)
    return try! JSONSerialization.data(withJSONObject: obj, options: [])
}

func asunToJSON(_ v: AsunValue) -> Any {
    switch v {
    case .int(let i): return NSNumber(value: i)
        case .float(let d): return NSNumber(value: d)
    case .bool(let b): return NSNumber(value: b)
    case .string(let s): return s
    case .array(let arr): return arr.map { asunToJSON($0) }
    case .object(let obj):
        var dict: [String: Any] = [:]
        for (k, v) in obj { dict[k] = asunToJSON(v) }
        return dict
    case .null: return NSNull()
    }
}

func obj(_ pairs: [String: AsunValue]) -> AsunValue { .object(pairs) }
func arr(_ values: [AsunValue]) -> AsunValue { .array(values) }

func require(_ condition: @autoclosure () -> Bool, _ message: String) {
    if !condition() {
        fatalError(message)
    }
}

func makeCountry(_ name: String, _ code: String, _ population: Int64, _ gdp: Double, _ regions: [AsunValue]) -> AsunValue {
    obj([
        "name": .string(name),
        "code": .string(code),
        "population": .int(population),
        "gdp_trillion": .float(gdp),
        "regions": arr(regions)
    ])
}

print("=== ASUN Complex Examples ===")
print()

print("1. Nested struct:")
let emp = try decode("{id,name,dept@{title},skills,active}:(1,Alice,(Manager),[rust],true)")
print("   \(emp)\n")

print("2. Vec with nested structs:")
let input2 = """
[{id,name,dept@{title},skills@[str],active}]:
  (1, Alice, (Manager), [Rust, Go], true),
  (2, Bob, (Engineer), [Python], false),
  (3, "Carol Smith", (Director), [Leadership, Strategy], true)
"""
let employees = try decode(input2)
if case .array(let rows) = employees {
    for row in rows {
        print("   \(row)")
    }
}

print("\n3. Entry-list field:")
let withEntries = try decode("{name,attrs@[{key,value}]}:(Alice,[(age,30),(score,95)])")
print("   \(withEntries)")

print("\n3b. Nested entry-list field:")
let groups = try decode("{groups@[{key,value@[{name,age}]}]}:([(teamA,[(Alice,30),(Bob,28)]),(teamB,[(Carol,41)])])")
print("   \(groups)")

print("\n4. Nested struct roundtrip:")
let nested = obj(["name": .string("Alice"), "addr": obj(["city": .string("NYC"), "zip": .int(10001)])])
let nestedText = try encode(nested)
print("   serialized:   \(nestedText)")
let nestedBack = try decode(nestedText)
assert(nestedBack == nested, "nested roundtrip mismatch")
print("   ✓ roundtrip OK")

print("\n5. Escaped strings:")
let note = obj(["text": .string("say \"hi\", then (wave)\tnewline\nend")])
let noteText = try encode(note)
print("   serialized:   \(noteText)")
let noteBack = try decode(noteText)
assert(noteBack == note, "escape roundtrip mismatch")
print("   ✓ escape roundtrip OK")

print("\n6. Float fields:")
let measurement = obj(["id": .int(2), "value": .float(95.0), "label": .string("score")])
let measurementText = try encode(measurement)
print("   serialized: \(measurementText)")
let measurementBack = try decode(measurementText)
require(measurementBack == measurement, "float roundtrip mismatch")
print("   ✓ float roundtrip OK")

print("\n7. Negative numbers:")
let nums = obj(["a": .int(-42), "b": .float(-3.14), "c": .int(-9223372036854775807)])
let numsText = try encode(nums)
print("   serialized:   \(numsText)")
let numsBack = try decode(numsText)
require(numsBack == nums, "negative roundtrip mismatch")
print("   ✓ negative roundtrip OK")

print("\n8. All types struct:")
let all = obj([
    "b": .bool(true),
    "i8v": .int(-128),
    "i16v": .int(-32768),
    "i32v": .int(-2147483648),
    "i64v": .int(-9223372036854775807),
    "u8v": .int(255),
    "u16v": .int(65535),
    "u32v": .int(4294967295),
    "u64v": .int(9223372036854775807),
    "f32v": .float(3.15),
    "f64v": .float(2.718281828459045),
    "s": .string("hello, world (test) [arr]"),
    "opt_some": .int(42),
    "opt_none": .null,
    "vec_int": arr([.int(1), .int(2), .int(3), .int(-4), .int(0)]),
    "vec_str": arr([.string("alpha"), .string("beta gamma"), .string("delta")]),
    "nested_vec": arr([arr([.int(1), .int(2)]), arr([.int(3), .int(4), .int(5)])])
])
let allText = try encodeTyped(all)
print("   serialized (\(allText.utf8.count) bytes):")
print("   \(allText)")
let allBack = try decode(allText)
require(allBack == all, "all-types roundtrip mismatch")
print("   ✓ all-types roundtrip OK")

print("\n9. Five-level nesting (Country>Region>City>District>Street>Building):")
let country = makeCountry("Rustland", "RL", 50_000_000, 1.5, [
    obj([
        "name": .string("Northern"),
        "cities": arr([
            obj([
                "name": .string("Ferriton"),
                "population": .int(2_000_000),
                "area_km2": .float(350.5),
                "districts": arr([
                    obj([
                        "name": .string("Downtown"),
                        "population": .int(500_000),
                        "streets": arr([
                            obj([
                                "name": .string("Main St"),
                                "length_km": .float(2.5),
                                "buildings": arr([
                                    obj(["name": .string("Tower A"), "floors": .int(50), "residential": .bool(false), "height_m": .float(200.0)]),
                                    obj(["name": .string("Apt Block 1"), "floors": .int(12), "residential": .bool(true), "height_m": .float(40.5)])
                                ])
                            ]),
                            obj([
                                "name": .string("Oak Ave"),
                                "length_km": .float(1.2),
                                "buildings": arr([
                                    obj(["name": .string("Library"), "floors": .int(3), "residential": .bool(false), "height_m": .float(15.0)])
                                ])
                            ])
                        ])
                    ]),
                    obj([
                        "name": .string("Harbor"),
                        "population": .int(150_000),
                        "streets": arr([
                            obj([
                                "name": .string("Dock Rd"),
                                "length_km": .float(0.8),
                                "buildings": arr([
                                    obj(["name": .string("Warehouse 7"), "floors": .int(1), "residential": .bool(false), "height_m": .float(8.0)])
                                ])
                            ])
                        ])
                    ])
                ])
            ])
        ])
    ]),
    obj([
        "name": .string("Southern"),
        "cities": arr([
            obj([
                "name": .string("Crabville"),
                "population": .int(800_000),
                "area_km2": .float(120.0),
                "districts": arr([
                    obj([
                        "name": .string("Old Town"),
                        "population": .int(200_000),
                        "streets": arr([
                            obj([
                                "name": .string("Heritage Ln"),
                                "length_km": .float(0.5),
                                "buildings": arr([
                                    obj(["name": .string("Museum"), "floors": .int(2), "residential": .bool(false), "height_m": .float(12.0)]),
                                    obj(["name": .string("Town Hall"), "floors": .int(4), "residential": .bool(false), "height_m": .float(20.0)])
                                ])
                            ])
                        ])
                    ])
                ])
            ])
        ])
    ])
])
let countryText = try encode(country)
print("   serialized (\(countryText.utf8.count) bytes)")
let preview = String(countryText.prefix(200))
print("   first 200 chars: \(preview)...")
let countryBack = try decode(countryText)
require(countryBack == country, "5-level text roundtrip mismatch")
print("   ✓ 5-level ASUN-text roundtrip OK")
let countryBin = try encodeBinary(country)
let countryBinBack = try decodeBinary(countryBin)
require(countryBinBack == country, "5-level binary roundtrip mismatch")
print("   ✓ 5-level ASUN-bin roundtrip OK")
let countryJSON = jsonEncode(country)
print("   ASUN text: \(countryText.utf8.count) B | ASUN bin: \(countryBin.count) B | JSON: \(countryJSON.count) B")
print(String(format: "   BIN vs JSON: %.0f%% smaller | TEXT vs JSON: %.0f%% smaller",
             (1.0 - Double(countryBin.count) / Double(countryJSON.count)) * 100.0,
             (1.0 - Double(countryText.utf8.count) / Double(countryJSON.count)) * 100.0))

print("\n10. Seven-level nesting (Universe>Galaxy>SolarSystem>Planet>Continent>Nation>State):")
let universe = obj([
    "name": .string("Observable"),
    "age_billion_years": .float(13.8),
    "galaxies": arr([
        obj([
            "name": .string("Milky Way"),
            "star_count_billions": .float(250.0),
            "systems": arr([
                obj([
                    "name": .string("Sol"),
                    "star_type": .string("G2V"),
                    "planets": arr([
                        obj([
                            "name": .string("Earth"),
                            "radius_km": .float(6371.0),
                            "has_life": .bool(true),
                            "continents": arr([
                                obj([
                                    "name": .string("Asia"),
                                    "nations": arr([
                                        obj([
                                            "name": .string("Japan"),
                                            "states": arr([
                                                obj(["name": .string("Tokyo"), "capital": .string("Shinjuku"), "population": .int(14_000_000)]),
                                                obj(["name": .string("Osaka"), "capital": .string("Osaka City"), "population": .int(8_800_000)])
                                            ])
                                        ])
                                    ])
                                ])
                            ])
                        ]),
                        obj([
                            "name": .string("Mars"),
                            "radius_km": .float(3389.5),
                            "has_life": .bool(false),
                            "continents": arr([])
                        ])
                    ])
                ])
            ])
        ])
    ])
])
let universeText = try encode(universe)
print("   serialized (\(universeText.utf8.count) bytes)")
let universeBack = try decode(universeText)
require(universeBack == universe, "7-level text roundtrip mismatch")
print("   ✓ 7-level ASUN-text roundtrip OK")
let universeBin = try encodeBinary(universe)
let universeBinBack = try decodeBinary(universeBin)
require(universeBinBack == universe, "7-level binary roundtrip mismatch")
print("   ✓ 7-level ASUN-bin roundtrip OK")
let universeJSON = jsonEncode(universe)
print("   ASUN text: \(universeText.utf8.count) B | ASUN bin: \(universeBin.count) B | JSON: \(universeJSON.count) B")
print(String(format: "   BIN vs JSON: %.0f%% smaller | TEXT vs JSON: %.0f%% smaller",
             (1.0 - Double(universeBin.count) / Double(universeJSON.count)) * 100.0,
             (1.0 - Double(universeText.utf8.count) / Double(universeJSON.count)) * 100.0))

print("\n11. Complex config struct (nested + entry list + optional):")
let config = obj([
    "name": .string("my-service"),
    "version": .string("2.1.0"),
    "db": obj([
        "host": .string("db.example.com"),
        "port": .int(5432),
        "max_connections": .int(100),
        "ssl": .bool(true),
        "timeout_ms": .float(3000.5)
    ]),
    "cache": obj([
        "enabled": .bool(true),
        "ttl_seconds": .int(3600),
        "max_size_mb": .int(512)
    ]),
    "log": obj([
        "level": .string("info"),
        "file": .string("/var/log/app.log"),
        "rotate": .bool(true)
    ]),
    "features": arr([.string("auth"), .string("rate-limit"), .string("websocket")]),
    "env": arr([
        obj(["key": .string("RUST_LOG"), "value": .string("debug")]),
        obj(["key": .string("DATABASE_URL"), "value": .string("postgres://localhost:5432/mydb")]),
        obj(["key": .string("SECRET_KEY"), "value": .string("abc123!@#")])
    ])
])
let configText = try encode(config)
print("   serialized (\(configText.utf8.count) bytes):")
print("   \(configText)")
let configBack = try decode(configText)
require(configBack == config, "config text roundtrip mismatch")
print("   ✓ config ASUN-text roundtrip OK")
let configJSON = jsonEncode(config)
print(String(format: "   ASUN text: %d B | JSON: %d B | TEXT vs JSON: %.0f%% smaller",
             configText.utf8.count, configJSON.count,
             (1.0 - Double(configText.utf8.count) / Double(configJSON.count)) * 100.0))
let configBin = try encodeBinary(config)
let configBinBack = try decodeBinary(configBin)
require(configBinBack == config, "config binary roundtrip mismatch")
print("   ✓ config ASUN-bin roundtrip OK")
print(String(format: "   ASUN bin: %d B | BIN vs JSON: %.0f%% smaller",
             configBin.count,
             (1.0 - Double(configBin.count) / Double(configJSON.count)) * 100.0))

print("\n12. Large structure (100 countries × nested regions):")
var totalASUN = 0
var totalJSON = 0
var totalBIN = 0
for i in 0..<100 {
    var regions: [AsunValue] = []
    for r in 0..<3 {
        var cities: [AsunValue] = []
        for c in 0..<2 {
            let city = obj([
                "name": .string("City_\(i)_\(r)_\(c)"),
                "population": .int(Int64(100_000 + c * 50_000)),
                "area_km2": .float(50.0 + Double(c) * 25.5),
                "districts": arr([
                    obj([
                        "name": .string("Dist_\(c)"),
                        "population": .int(Int64(50_000 + c * 10_000)),
                        "streets": arr([
                            obj([
                                "name": .string("St_\(c)"),
                                "length_km": .float(1.0 + Double(c) * 0.5),
                                "buildings": arr([
                                    obj(["name": .string("Bldg_\(c)_0"), "floors": .int(5), "residential": .bool(true), "height_m": .float(15.0)]),
                                    obj(["name": .string("Bldg_\(c)_1"), "floors": .int(8), "residential": .bool(false), "height_m": .float(25.5)])
                                ])
                            ])
                        ])
                    ])
                ])
            ])
            cities.append(city)
        }
        regions.append(obj(["name": .string("Region_\(i)_\(r)"), "cities": arr(cities)]))
    }
    let c = makeCountry("Country_\(i)", String(format: "C%02d", i % 100), Int64(1_000_000 + i * 500_000), Double(i) * 0.5, regions)
    let asunText = try encode(c)
    let js = jsonEncode(c)
    let bs = try encodeBinary(c)
    let decodedCountry = try decode(asunText)
    let decodedCountryBin = try decodeBinary(bs)
    if case .object(let textObj) = decodedCountry, case .string(let textName) = textObj["name"] {
        require(textName == "Country_\(i)", "country text roundtrip failed")
    } else {
        fatalError("country text roundtrip failed")
    }
    if case .object(let binObj) = decodedCountryBin, case .string(let binName) = binObj["name"] {
        require(binName == "Country_\(i)", "country binary roundtrip failed")
    } else {
        fatalError("country binary roundtrip failed")
    }
    totalASUN += asunText.utf8.count
    totalJSON += js.count
    totalBIN += bs.count
}
print("   100 countries with 5-level nesting:")
print(String(format: "   Total ASUN text: %d bytes (%.1f KB)", totalASUN, Double(totalASUN) / 1024.0))
print(String(format: "   Total ASUN bin:  %d bytes (%.1f KB)", totalBIN, Double(totalBIN) / 1024.0))
print(String(format: "   Total JSON:      %d bytes (%.1f KB)", totalJSON, Double(totalJSON) / 1024.0))
print(String(format: "   TEXT vs JSON: %.0f%% smaller | BIN vs JSON: %.0f%% smaller",
             (1.0 - Double(totalASUN) / Double(totalJSON)) * 100.0,
             (1.0 - Double(totalBIN) / Double(totalJSON)) * 100.0))
print("   ✓ all 100 countries roundtrip OK (text + bin)")

print("\n13. Deserialize with nested schema type hints:")
let deepInput = "{name,code,population,gdp_trillion,regions@[{name,cities@[{name,population,area_km2,districts@[{name,population,streets@[{name,length_km,buildings@[{name,floors,residential,height_m}]}]}]}]}]}:(TestLand,TL,1000000,0.5,[(TestRegion,[(TestCity,500000,100.0,[(Central,250000,[(Main St,2.5,[(HQ,10,false,45.0)])])])])])"
let deep = try decode(deepInput)
print("   ✓ deep schema type-hint parse OK")
print("   \(deep)")

print("\n14. Typed serialization (EncodeTyped):")
let typedEmployee = obj([
    "id": .int(1),
    "name": .string("Alice"),
    "dept": obj(["title": .string("Engineering")]),
    "skills": arr([.string("Rust"), .string("Go")]),
    "active": .bool(true)
])
let typedEmployeeText = try encodeTyped(typedEmployee)
print("   nested struct: \(typedEmployeeText)")
let typedEmployeeBack = try decode(typedEmployeeText)
require(typedEmployeeBack == typedEmployee, "typed nested struct roundtrip mismatch")
print("   ✓ typed nested struct roundtrip OK")
let allTyped = try encodeTyped(all)
print("   all-types (\(allTyped.utf8.count) bytes): \(String(allTyped.prefix(80)))...")
let allTypedBack = try decode(allTyped)
require(allTypedBack == all, "typed all-types roundtrip mismatch")
print("   ✓ typed all-types roundtrip OK")
let configTyped = try encodeTyped(config)
print("   config (\(configTyped.utf8.count) bytes): \(String(configTyped.prefix(100)))...")
let configTypedBack = try decode(configTyped)
require(configTypedBack == config, "typed config roundtrip mismatch")
print("   ✓ typed config roundtrip OK")
print("   untyped: \(configText.utf8.count) bytes | typed: \(configTyped.utf8.count) bytes | overhead: \(configTyped.utf8.count - configText.utf8.count) bytes")

print("\n15. Edge cases:")
let emptyVec = obj(["items": arr([])])
print("   empty vec: \(try encode(emptyVec))")
let special = obj(["val": .string("tabs\there, newlines\nhere, quotes\"and\\backslash")])
let specialText = try encode(special)
print("   special chars: \(specialText)")
let specialBack = try decode(specialText)
require(specialBack == special, "special chars roundtrip mismatch")
let boolLike = obj(["val": .string("true")])
let boolLikeText = try encode(boolLike)
print("   bool-like string: \(boolLikeText)")
let boolLikeBack = try decode(boolLikeText)
require(boolLikeBack == boolLike, "bool-like roundtrip mismatch")
let numberLike = obj(["val": .string("12345")])
let numberLikeText = try encode(numberLike)
print("   number-like string: \(numberLikeText)")
let numberLikeBack = try decode(numberLikeText)
require(numberLikeBack == numberLike, "number-like roundtrip mismatch")
print("   ✓ all edge cases OK")

print("\n16. Triple-nested arrays:")
let matrix3D = obj([
    "data": arr([
        arr([arr([.int(1), .int(2)]), arr([.int(3), .int(4)])]),
        arr([arr([.int(5), .int(6), .int(7)]), arr([.int(8)])])
    ])
])
let matrixText = try encode(matrix3D)
print("   \(matrixText)")
let matrixBack = try decode(matrixText)
require(matrixBack == matrix3D, "triple-nested array roundtrip mismatch")
print("   ✓ triple-nested array roundtrip OK")

print("\n17. Comments:")
let commentText = "{id,name,dept@{title},skills,active}:/* inline */ (1,Alice,(HR),[rust],true)"
let commentValue = try decode(commentText)
print("   with inline comment: \(commentValue)")
print("   ✓ comment parsing OK")

print("\n=== All 17 complex examples passed! ===")
