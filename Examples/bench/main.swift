import Foundation
import AsunSwift

func jsonEncode(_ value: AsunValue) -> Data {
    let obj = asunToJSON(value)
    return try! JSONSerialization.data(withJSONObject: obj, options: [])
}

func jsonDecode(_ data: Data) -> Any {
    return try! JSONSerialization.jsonObject(with: data, options: [])
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

func elapsedMs(_ body: () throws -> Void) rethrows -> Double {
    let t0 = DispatchTime.now().uptimeNanoseconds
    try body()
    let t1 = DispatchTime.now().uptimeNanoseconds
    return Double(t1 - t0) / 1_000_000.0
}

func formatRatio(_ base: Double, _ target: Double) -> String {
    if target <= 0 { return "infx" }
    var s = String(format: "%.1f", base / target)
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s + "x"
}

func formatPercent(_ part: Int, _ whole: Int) -> String {
    if whole <= 0 { return "0%" }
    var s = String(format: "%.1f", Double(part) * 100.0 / Double(whole))
    while s.hasSuffix("0") { s.removeLast() }
    if s.hasSuffix(".") { s.removeLast() }
    return s + "%"
}

func printSection(_ title: String, _ width: Int) {
    let line = String(repeating: "─", count: width - 2)
    print("┌\(line)┐")
    let text = title.padding(toLength: width - 4, withPad: " ", startingAt: 0)
    print("│ \(text) │")
    print("└\(line)┘")
}

func obj(_ pairs: [String: AsunValue]) -> AsunValue { .object(pairs) }
func arr(_ values: [AsunValue]) -> AsunValue { .array(values) }

struct TypedBenchUser {
    var active: Bool = false
    var age: Int64 = 0
    var city: String = ""
    var email: String = ""
    var id: Int64 = 0
    var name: String = ""
    var role: String = ""
    var score: Double = 0
}

struct TypedBenchProfile {
    var level: Int64 = 0
    var title: String = ""
}

struct TypedBenchComplex {
    var flags: [Bool] = []
    var id: Int64 = 0
    var profile: TypedBenchProfile = .init()
    var scores: [Double] = []
    var tags: [String] = []
    var backup: TypedBenchProfile? = nil
}

struct BenchResult {
    let name: String
    let jsonSerMs: Double
    let asunSerMs: Double
    let binSerMs: Double
    let jsonDeMs: Double
    let asunDeMs: Double
    let binDeMs: Double
    let jsonBytes: Int
    let asunBytes: Int
    let binBytes: Int

    func print_() {
        print("  \(name)")
        print(String(format: "    Serialize:   JSON %.2fms/%dB | ASUN %.2fms(%@)/%dB(%@) | BIN %.2fms(%@)/%dB(%@)",
                     jsonSerMs, jsonBytes,
                     asunSerMs, formatRatio(jsonSerMs, asunSerMs), asunBytes, formatPercent(asunBytes, jsonBytes),
                     binSerMs, formatRatio(jsonSerMs, binSerMs), binBytes, formatPercent(binBytes, jsonBytes)))
        print(String(format: "    Deserialize: JSON %8.2fms | ASUN %8.2fms(%@) | BIN %8.2fms(%@)",
                     jsonDeMs, asunDeMs, formatRatio(jsonDeMs, asunDeMs), binDeMs, formatRatio(jsonDeMs, binDeMs)))
    }
}

func generateUsers(_ n: Int) -> AsunValue {
    let names = ["Alice", "Bob", "Carol", "David", "Eve", "Frank", "Grace", "Hank"]
    let roles = ["engineer", "designer", "manager", "analyst"]
    let cities = ["NYC", "LA", "Chicago", "Houston", "Phoenix"]
    var rows: [AsunValue] = []
    rows.reserveCapacity(n)
    for i in 0..<n {
        rows.append(obj([
            "id": .int(Int64(i)),
            "name": .string(names[i % names.count]),
            "email": .string("\(names[i % names.count].lowercased())@example.com"),
            "age": .int(Int64(25 + i % 40)),
            "score": .float(50.0 + Double(i % 50) + 0.5),
            "active": .bool(i % 3 != 0),
            "role": .string(roles[i % roles.count]),
            "city": .string(cities[i % cities.count])
        ]))
    }
    return arr(rows)
}

func generateAllTypes(_ n: Int) -> AsunValue {
    var rows: [AsunValue] = []
    rows.reserveCapacity(n)
    for i in 0..<n {
        rows.append(obj([
            "b": .bool(i % 2 == 0),
            "i8v": .int(Int64(Int8(i % 128))),
            "i16v": .int(Int64(-Int16(i))),
            "i32v": .int(Int64(Int32(i) * 1000)),
            "i64v": .int(Int64(i) * 100_000),
            "u8v": .int(Int64(i % 255)),
            "u16v": .int(Int64(i % 65_535)),
            "u32v": .int(Int64(i) * 7_919),
            "u64v": .int(Int64(i) * 1_000_000_007),
            "f32v": .float(Double(Float(i) * 1.5)),
            "f64v": .float(Double(i) * 0.25 + 0.5),
            "s": .string("item_\(i)"),
            "opt_some": i % 2 == 0 ? .int(Int64(i)) : .null,
            "opt_none": .null,
            "vec_int": arr([.int(Int64(i)), .int(Int64(i + 1)), .int(Int64(i + 2))]),
            "vec_str": arr([.string("tag\(i % 5)"), .string("cat\(i % 3)")])
        ]))
    }
    return arr(rows)
}

func generateCompanies(_ n: Int) -> AsunValue {
    let locs = ["NYC", "London", "Tokyo", "Berlin"]
    let leads = ["Alice", "Bob", "Carol", "David"]
    var companies: [AsunValue] = []
    companies.reserveCapacity(n)
    for i in 0..<n {
        var divisions: [AsunValue] = []
        for d in 0..<2 {
            var teams: [AsunValue] = []
            for t in 0..<2 {
                var projects: [AsunValue] = []
                for p in 0..<3 {
                    var tasks: [AsunValue] = []
                    for tk in 0..<4 {
                        tasks.append(obj([
                            "id": .int(Int64(i * 100 + d * 10 + t * 5 + tk)),
                            "title": .string("Task_\(tk)"),
                            "priority": .int(Int64(tk % 3 + 1)),
                            "done": .bool(tk % 2 == 0),
                            "hours": .float(2.0 + Double(tk) * 1.5)
                        ]))
                    }
                    projects.append(obj([
                        "name": .string("Proj_\(t)_\(p)"),
                        "budget": .float(100.0 + Double(p) * 50.5),
                        "active": .bool(p % 2 == 0),
                        "tasks": arr(tasks)
                    ]))
                }
                teams.append(obj([
                    "name": .string("Team_\(i)_\(d)_\(t)"),
                    "lead": .string(leads[t % leads.count]),
                    "size": .int(Int64(5 + t * 2)),
                    "projects": arr(projects)
                ]))
            }
            divisions.append(obj([
                "name": .string("Div_\(i)_\(d)"),
                "location": .string(locs[d % locs.count]),
                "headcount": .int(Int64(50 + d * 20)),
                "teams": arr(teams)
            ]))
        }
        companies.append(obj([
            "name": .string("Corp_\(i)"),
            "founded": .int(Int64(1990 + i % 35)),
            "revenue_m": .float(10.0 + Double(i) * 5.5),
            "public": .bool(i % 2 == 0),
            "divisions": arr(divisions),
            "tags": arr([.string("enterprise"), .string("tech"), .string("sector_\(i % 5)")])
        ]))
    }
    return arr(companies)
}

func benchValue(_ name: String, _ value: AsunValue, _ iterations: Int) throws -> BenchResult {
    var jsonData = Data()
    let jsonSerMs = elapsedMs {
        for _ in 0..<iterations { jsonData = jsonEncode(value) }
    }

    var asunData = ""
    let asunSerMs = try elapsedMs {
        for _ in 0..<iterations { asunData = try encode(value) }
    }

    var binData = Data()
    let binSerMs = try elapsedMs {
        for _ in 0..<iterations { binData = try encodeBinary(value) }
    }

    let jsonDeMs = elapsedMs {
        for _ in 0..<iterations { _ = jsonDecode(jsonData) }
    }

    let asunDeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try decode(asunData) }
    }

    let binDeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try decodeBinary(binData) }
    }

    return BenchResult(
        name: name,
        jsonSerMs: jsonSerMs,
        asunSerMs: asunSerMs,
        binSerMs: binSerMs,
        jsonDeMs: jsonDeMs,
        asunDeMs: asunDeMs,
        binDeMs: binDeMs,
        jsonBytes: jsonData.count,
        asunBytes: asunData.utf8.count,
        binBytes: binData.count
    )
}

func benchFlat(_ count: Int, _ iterations: Int) throws -> BenchResult {
    try benchValue("Flat struct × \(count) (8 fields, vec)", generateUsers(count), iterations)
}

func benchAllTypes(_ count: Int, _ iterations: Int) throws -> BenchResult {
    try benchValue("All-types struct × \(count) (16 fields, vec)", generateAllTypes(count), iterations)
}

func benchDeep(_ count: Int, _ iterations: Int) throws -> BenchResult {
    try benchValue("5-level deep × \(count) (Company>Division>Team>Project>Task)", generateCompanies(count), iterations)
}

func benchSingleRoundtrip(_ iterations: Int) throws -> (Double, Double) {
    let user = obj([
        "id": .int(1), "name": .string("Alice"),
        "email": .string("alice@example.com"),
        "age": .int(30), "score": .float(95.5),
        "active": .bool(true), "role": .string("engineer"),
        "city": .string("NYC")
    ])

    let asunMs = try elapsedMs {
        for _ in 0..<iterations {
            let s = try encode(user)
            _ = try decode(s)
        }
    }

    let jsonMs = elapsedMs {
        for _ in 0..<iterations {
            let s = jsonEncode(user)
            _ = jsonDecode(s)
        }
    }

    return (asunMs, jsonMs)
}

func benchDeepSingleRoundtrip(_ iterations: Int) throws -> (Double, Double) {
    let company = generateCompanies(1)

    let asunMs = try elapsedMs {
        for _ in 0..<iterations {
            let s = try encode(company)
            _ = try decode(s)
        }
    }

    let jsonMs = elapsedMs {
        for _ in 0..<iterations {
            let s = jsonEncode(company)
            _ = jsonDecode(s)
        }
    }

    return (asunMs, jsonMs)
}

func benchPreparedEncoder(_ value: AsunValue, _ iterations: Int) throws -> (Double, Double, Double, Int, Int) {
    let prepared = try PreparedAsunEncoder(sample: value)
    let preparedTyped = try PreparedAsunEncoder(sample: value, typed: true)

    var normalBytes = 0
    let normalMs = try elapsedMs {
        for _ in 0..<iterations { normalBytes = try encode(value).utf8.count }
    }

    var preparedOut = ""
    let preparedMs = try elapsedMs {
        for _ in 0..<iterations { preparedOut = try prepared.encode(value) }
    }

    var preparedBin = Data()
    let preparedBinMs = try elapsedMs {
        for _ in 0..<iterations { preparedBin = try preparedTyped.encodeBinary(value) }
    }

    _ = normalBytes
    return (normalMs, preparedMs, preparedBinMs, preparedOut.utf8.count, preparedBin.count)
}

func extractBody(_ text: String) -> String {
    var depthBrace = 0
    var depthBracket = 0
    var inQuote = false
    var escaped = false
    let bytes = Array(text.utf8)
    for (i, c) in bytes.enumerated() {
        if inQuote {
            if escaped { escaped = false; continue }
            if c == 0x5C { escaped = true; continue }
            if c == 0x22 { inQuote = false }
            continue
        }
        switch c {
        case 0x22: inQuote = true
        case 0x7B: depthBrace += 1
        case 0x7D: depthBrace -= 1
        case 0x5B: depthBracket += 1
        case 0x5D: depthBracket -= 1
        case 0x3A where depthBrace == 0 && depthBracket == 0:
            return String(decoding: bytes[(i + 1)...], as: UTF8.self)
        default: break
        }
    }
    return text
}

func benchPreparedDecoder(_ value: AsunValue, _ iterations: Int) throws -> (Double, Double, Double, Double) {
    let typedText = try encodeTyped(value)
    let body = extractBody(typedText)
    let prepared = try PreparedAsunDecoder(sample: value, typed: true)
    let preparedBin = try PreparedAsunEncoder(sample: value, typed: true).encodeBinary(value)

    let standardMs = try elapsedMs {
        for _ in 0..<iterations { _ = try decode(typedText) }
    }
    let preparedMs = try elapsedMs {
        for _ in 0..<iterations { _ = try prepared.decode(typedText) }
    }
    let bodyOnlyMs = try elapsedMs {
        for _ in 0..<iterations { _ = try prepared.decodeBody(body) }
    }
    let preparedBinMs = try elapsedMs {
        for _ in 0..<iterations { _ = try prepared.decodeBinary(preparedBin) }
    }

    return (standardMs, preparedMs, bodyOnlyMs, preparedBinMs)
}

func makeTypedBenchUsers(_ n: Int) -> [TypedBenchUser] {
    let names = ["Alice", "Bob", "Carol", "David", "Eve", "Frank", "Grace", "Hank"]
    let roles = ["engineer", "designer", "manager", "analyst"]
    let cities = ["NYC", "LA", "Chicago", "Houston", "Phoenix"]
    var rows: [TypedBenchUser] = []
    rows.reserveCapacity(n)
    for i in 0..<n {
        rows.append(TypedBenchUser(
            active: i % 3 != 0,
            age: Int64(25 + i % 40),
            city: cities[i % cities.count],
            email: "\(names[i % names.count].lowercased())@example.com",
            id: Int64(i),
            name: names[i % names.count],
            role: roles[i % roles.count],
            score: 50.0 + Double(i % 50) + 0.5
        ))
    }
    return rows
}

func makeTypedBenchComplex(_ n: Int) -> [TypedBenchComplex] {
    let titles = ["Lead", "Senior", "Staff", "Principal"]
    let tags = [["core", "swift"], ["api", "backend"], ["bench", "perf"], ["ios", "mobile"]]
    var rows: [TypedBenchComplex] = []
    rows.reserveCapacity(n)
    for i in 0..<n {
        rows.append(TypedBenchComplex(
            flags: [i % 2 == 0, i % 3 == 0, true],
            id: Int64(i),
            profile: TypedBenchProfile(level: Int64((i % 5) + 1), title: titles[i % titles.count]),
            scores: [Double(i % 100) + 0.5, Double((i + 7) % 100) + 0.25],
            tags: tags[i % tags.count],
            backup: i % 2 == 0 ? TypedBenchProfile(level: Int64((i % 3) + 1), title: "Backup_\(i % 4)") : nil
        ))
    }
    return rows
}

func generateComplexTypedValue(_ n: Int) -> AsunValue {
    let rows = makeTypedBenchComplex(n)
    return .array(rows.map { row in
        .object([
            "flags": .array(row.flags.map { .bool($0) }),
            "id": .int(row.id),
            "profile": .object([
                "level": .int(row.profile.level),
                "title": .string(row.profile.title)
            ]),
            "scores": .array(row.scores.map { .float($0) }),
            "tags": .array(row.tags.map { .string($0) }),
            "backup": row.backup.map {
                .object([
                    "level": .int($0.level),
                    "title": .string($0.title)
                ])
            } ?? .null
        ])
    })
}

func benchTypedStructCodec(_ count: Int, _ iterations: Int) throws -> (Double, Double, Double, Double) {
    let codec = AsunStructArrayCodec<TypedBenchUser>(fields: [
        .bool("active", \.active),
        .int("age", \.age),
        .string("city", \.city),
        .string("email", \.email),
        .int("id", \.id),
        .string("name", \.name),
        .string("role", \.role),
        .float("score", \.score)
    ], make: TypedBenchUser.init)
    let rows = makeTypedBenchUsers(count)
    let dynamicValue = generateUsers(count)
    let text = try codec.encode(rows)
    let bin = try codec.encodeBinary(rows)

    let typedEncodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try codec.encode(rows) }
    }
    let typedDecodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try codec.decode(text) }
    }
    let typedBinEncodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try codec.encodeBinary(rows) }
    }
    let typedBinDecodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try codec.decodeBinary(bin) }
    }

    let dynamicEncodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try encodeTyped(dynamicValue) }
    }
    let dynamicDecodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try decode(text) }
    }

    print("  Flat struct x \(count) (\(iterations) iters, typed struct codec)")
    print(String(format: "    Text encode:   dynamic %8.2fms | typed %8.2fms | speedup %.3fx",
                 dynamicEncodeMs, typedEncodeMs, dynamicEncodeMs / typedEncodeMs))
    print(String(format: "    Text decode:   dynamic %8.2fms | typed %8.2fms | speedup %.3fx",
                 dynamicDecodeMs, typedDecodeMs, dynamicDecodeMs / typedDecodeMs))
    print(String(format: "    Binary encode: typed   %8.2fms", typedBinEncodeMs))
    print(String(format: "    Binary decode: typed   %8.2fms", typedBinDecodeMs))

    return (typedEncodeMs, typedDecodeMs, typedBinEncodeMs, typedBinDecodeMs)
}

func benchTypedComplexCodec(_ count: Int, _ iterations: Int) throws {
    let profileCodec = AsunStructCodec<TypedBenchProfile>(fields: [
        .int("level", \.level),
        .string("title", \.title)
    ], make: TypedBenchProfile.init)
    let codec = AsunStructArrayCodec<TypedBenchComplex>(fields: [
        .boolArray("flags", \.flags),
        .int("id", \.id),
        .nested("profile", \.profile, codec: profileCodec),
        .floatArray("scores", \.scores),
        .stringArray("tags", \.tags),
        .optionalNested("backup", \.backup, codec: profileCodec)
    ], make: TypedBenchComplex.init)

    let rows = makeTypedBenchComplex(count)
    let text = try codec.encode(rows)
    let bin = try codec.encodeBinary(rows)

    let typedEncodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try codec.encode(rows) }
    }
    let typedDecodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try codec.decode(text) }
    }
    let typedBinEncodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try codec.encodeBinary(rows) }
    }
    let typedBinDecodeMs = try elapsedMs {
        for _ in 0..<iterations { _ = try codec.decodeBinary(bin) }
    }

    print("  Complex struct x \(count) (\(iterations) iters, nested+arrays+optional)")
    print(String(format: "    Text encode:   typed   %8.2fms", typedEncodeMs))
    print(String(format: "    Text decode:   typed   %8.2fms", typedDecodeMs))
    print(String(format: "    Binary encode: typed   %8.2fms", typedBinEncodeMs))
    print(String(format: "    Binary decode: typed   %8.2fms", typedBinDecodeMs))
}

do {
    print("╔══════════════════════════════════════════════════════════════╗")
    print("║            ASUN vs JSON Comprehensive Benchmark              ║")
    print("╚══════════════════════════════════════════════════════════════╝")
    print("\nSystem: macOS")
    print("Iterations per test: 100")

    print()
    printSection("Section 1: Flat Struct (schema-driven vec)", 47)
    print()
    for count in [100, 500, 1000, 5000] {
        try benchFlat(count, 100).print_()
        print()
    }

    printSection("Section 2: All-Types Struct (16 fields)", 48)
    print()
    for count in [100, 500] {
        try benchAllTypes(count, 100).print_()
        print()
    }

    printSection("Section 3: 5-Level Deep Nesting (Company hierarchy)", 60)
    print()
    for count in [10, 50, 100] {
        try benchDeep(count, 50).print_()
        print()
    }

    printSection("Section 4: Single Struct Roundtrip (10000x)", 48)
    print()
    let (asunFlat, jsonFlat) = try benchSingleRoundtrip(10_000)
    print(String(format: "  Flat:  ASUN %8.2fms | JSON %8.2fms | ratio %.2fx", asunFlat, jsonFlat, jsonFlat / asunFlat))
    let (asunDeep, jsonDeep) = try benchDeepSingleRoundtrip(10_000)
    print(String(format: "  Deep:  ASUN %8.2fms | JSON %8.2fms | ratio %.2fx", asunDeep, jsonDeep, jsonDeep / asunDeep))

    print()
    printSection("Section 5: Large Payload (10k records)", 48)
    print()
    let large = try benchFlat(10_000, 10)
    print("  (10 iterations for large payload)")
    large.print_()

    print()
    printSection("Section 6: Annotated vs Unannotated Schema (deserialize)", 64)
    print()
    let users = generateUsers(1000)
    let untyped = try encode(users)
    let typed = try encodeTyped(users)
    let deIters = 200
    let untypedDeMs = try elapsedMs {
        for _ in 0..<deIters { _ = try decode(untyped) }
    }
    let typedDeMs = try elapsedMs {
        for _ in 0..<deIters { _ = try decode(typed) }
    }
    print("  Flat struct x 1000 (\(deIters) iters, deserialize only)")
    print(String(format: "    Unannotated: %8.2fms  (%d B)", untypedDeMs, untyped.utf8.count))
    print(String(format: "    Annotated:   %8.2fms  (%d B)", typedDeMs, typed.utf8.count))
    print(String(format: "    Ratio: %.3fx (unannotated / annotated)", untypedDeMs / typedDeMs))

    print()
    printSection("Section 7: Annotated vs Unannotated Schema (serialize)", 62)
    print()
    let serIters = 200
    var untypedOut = ""
    let untypedSerMs = try elapsedMs {
        for _ in 0..<serIters { untypedOut = try encode(users) }
    }
    var typedOut = ""
    let typedSerMs = try elapsedMs {
        for _ in 0..<serIters { typedOut = try encodeTyped(users) }
    }
    print("  Flat struct x 1000 (\(serIters) iters, serialize only)")
    print(String(format: "    Unannotated: %8.2fms  (%d B)", untypedSerMs, untypedOut.utf8.count))
    print(String(format: "    Annotated:   %8.2fms  (%d B)", typedSerMs, typedOut.utf8.count))
    print(String(format: "    Ratio: %.3fx (unannotated / annotated)", untypedSerMs / typedSerMs))

    print()
    printSection("Section 8: Throughput Summary", 48)
    print()
    let jsonData = jsonEncode(users)
    let asunData = try encode(users)
    let iters = 100
    let jsonSerDur = elapsedMs {
        for _ in 0..<iters { _ = jsonEncode(users) }
    }
    let asunSerDur = try elapsedMs {
        for _ in 0..<iters { _ = try encode(users) }
    }
    let jsonDeDur = elapsedMs {
        for _ in 0..<iters { _ = jsonDecode(jsonData) }
    }
    let asunDeDur = try elapsedMs {
        for _ in 0..<iters { _ = try decode(asunData) }
    }
    let totalRecords = 1000.0 * Double(iters)
    print("  Serialize throughput (1000 records x \(iters) iters):")
    print(String(format: "    JSON: %.0f records/s", totalRecords / (jsonSerDur / 1000.0)))
    print(String(format: "    ASUN: %.0f records/s", totalRecords / (asunSerDur / 1000.0)))
    print(String(format: "    Speed: %.2fx", jsonSerDur / asunSerDur))
    print("  Deserialize throughput:")
    print(String(format: "    JSON: %.0f records/s", totalRecords / (jsonDeDur / 1000.0)))
    print(String(format: "    ASUN: %.0f records/s", totalRecords / (asunDeDur / 1000.0)))
    print(String(format: "    Speed: %.2fx", jsonDeDur / asunDeDur))

    print()
    printSection("Section 9: Prepared Encoder Appendix", 50)
    print()
    let preparedIters = 200
    let (normalMs, preparedMs, preparedBinMs, preparedBytes, preparedBinBytes) = try benchPreparedEncoder(users, preparedIters)
    print("  Flat struct x 1000 (\(preparedIters) iters, serialize only)")
    print(String(format: "    Standard encode: %8.2fms", normalMs))
    print(String(format: "    Prepared encode: %8.2fms  (%d B)", preparedMs, preparedBytes))
    print(String(format: "    Prepared binary: %8.2fms  (%d B)", preparedBinMs, preparedBinBytes))
    print(String(format: "    Encode speedup: %.3fx", normalMs / preparedMs))

    print()
    printSection("Section 10: Prepared Decoder Appendix", 50)
    print()
    let decoderIters = 200
    let (standardDeMs, preparedDeMs, bodyOnlyDeMs, preparedBinDeMs) = try benchPreparedDecoder(users, decoderIters)
    print("  Flat struct x 1000 (\(decoderIters) iters, decode only)")
    print(String(format: "    Standard decode: %8.2fms", standardDeMs))
    print(String(format: "    Prepared decode: %8.2fms", preparedDeMs))
    print(String(format: "    Body-only decode: %8.2fms", bodyOnlyDeMs))
    print(String(format: "    Prepared binary: %8.2fms", preparedBinDeMs))
    print(String(format: "    Decode speedup: %.3fx", standardDeMs / preparedDeMs))

    print()
    printSection("Section 11: Typed Struct Codec Appendix", 54)
    print()
    _ = try benchTypedStructCodec(1000, 200)

    print()
    printSection("Section 12: Typed Complex Codec Appendix", 55)
    print()
    try benchTypedComplexCodec(1000, 120)

    print("\n╔══════════════════════════════════════════════════════════════╗")
    print("║                    Benchmark Complete                        ║")
    print("╚══════════════════════════════════════════════════════════════╝")
} catch {
    print("error: \(error)")
    exit(1)
}
