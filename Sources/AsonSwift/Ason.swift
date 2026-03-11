import Foundation

// ===========================================================================
// Fast formatting primitives — write directly to [UInt8] buffer
// ===========================================================================

/// Two-digit lookup table for fast integer formatting (itoa-style).
private let DEC_DIGITS: [UInt8] = Array("00010203040506070809101112131415161718192021222324252627282930313233343536373839404142434445464748495051525354555657585960616263646566676869707172737475767778798081828384858687888990919293949596979899".utf8)

@inline(__always)
private func writeU64(_ buf: inout [UInt8], _ v: UInt64) {
    if v < 10 {
        buf.append(UInt8(v) + 0x30)
        return
    }
    if v < 100 {
        let i = Int(v) * 2
        buf.append(DEC_DIGITS[i])
        buf.append(DEC_DIGITS[i + 1])
        return
    }
    // Write digits in reverse to a small stack buffer, then copy
    var n = v
    var digits: (UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8, UInt8,
                 UInt8, UInt8, UInt8, UInt8) =
        (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pos = 19
    while n >= 100 {
        let rem = Int(n % 100)
        n /= 100
        let i = rem * 2
        withUnsafeMutablePointer(to: &digits) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 20) { p in
                p[pos] = DEC_DIGITS[i + 1]
                p[pos - 1] = DEC_DIGITS[i]
            }
        }
        pos -= 2
    }
    if n >= 10 {
        let i = Int(n) * 2
        withUnsafeMutablePointer(to: &digits) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 20) { p in
                p[pos] = DEC_DIGITS[i + 1]
                p[pos - 1] = DEC_DIGITS[i]
            }
        }
        pos -= 2
    } else {
        withUnsafeMutablePointer(to: &digits) {
            $0.withMemoryRebound(to: UInt8.self, capacity: 20) { p in
                p[pos] = UInt8(n) + 0x30
            }
        }
        pos -= 1
    }
    let start = pos + 1
    withUnsafePointer(to: &digits) {
        $0.withMemoryRebound(to: UInt8.self, capacity: 20) { p in
            buf.append(contentsOf: UnsafeBufferPointer(start: p + start, count: 20 - start))
        }
    }
}

@inline(__always)
private func writeI64(_ buf: inout [UInt8], _ v: Int64) {
    if v < 0 {
        buf.append(0x2D) // '-'
        writeU64(&buf, UInt64(~v) &+ 1)
    } else {
        writeU64(&buf, UInt64(v))
    }
}

/// Fast float formatting with fast paths for common cases.
@inline(__always)
private func writeF64(_ buf: inout [UInt8], _ v: Double) {
    if !v.isFinite || v == 0 {
        buf.append(contentsOf: [0x30]) // "0"
        return
    }
    // Integer-valued float: write as int + ".0"
    if v.rounded() == v, v >= -9.0e18, v <= 9.0e18 {
        writeI64(&buf, Int64(v))
        buf.append(0x2E) // '.'
        buf.append(0x30) // '0'
        return
    }
    // One decimal place fast path
    let v10 = v * 10.0
    if v10.rounded() == v10, Swift.abs(v10) < 1e18 {
        let vi = Int64(v10)
        if vi < 0 {
            buf.append(0x2D) // '-'
            let pos = UInt64(~vi &+ 1)
            writeU64(&buf, pos / 10)
            buf.append(0x2E) // '.'
            buf.append(UInt8(pos % 10) + 0x30)
        } else {
            writeU64(&buf, UInt64(vi) / 10)
            buf.append(0x2E) // '.'
            buf.append(UInt8(UInt64(vi) % 10) + 0x30)
        }
        return
    }
    // Two decimal places fast path
    let v100 = v * 100.0
    if v100.rounded() == v100, Swift.abs(v100) < 1e18 {
        let vi = Int64(v100)
        if vi < 0 {
            buf.append(0x2D) // '-'
            let pos = UInt64(~vi &+ 1)
            writeU64(&buf, pos / 100)
            buf.append(0x2E) // '.'
            let frac = Int(pos % 100)
            buf.append(DEC_DIGITS[frac * 2])
            let d2 = DEC_DIGITS[frac * 2 + 1]
            if d2 != 0x30 { buf.append(d2) }
        } else {
            let pos = UInt64(vi)
            writeU64(&buf, pos / 100)
            buf.append(0x2E) // '.'
            let frac = Int(pos % 100)
            buf.append(DEC_DIGITS[frac * 2])
            let d2 = DEC_DIGITS[frac * 2 + 1]
            if d2 != 0x30 { buf.append(d2) }
        }
        return
    }
    // General: use String(v) which uses grisu/dragonbox algorithm
    var s = "\(v)"
    if !s.contains(".") && !s.contains("e") && !s.contains("E") {
        s += ".0"
    }
    buf.append(contentsOf: Array(s.utf8))
}

/// 256-byte lookup table: stopSet[c] == true if c is a stop character.
private struct StopSet {
    var table: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)

    init(_ chars: UInt8...) {
        for c in chars {
            let word = Int(c >> 6)
            let bit = UInt64(1) << (c & 63)
            withUnsafeMutablePointer(to: &table) {
                $0.withMemoryRebound(to: UInt64.self, capacity: 4) { p in
                    p[word] |= bit
                }
            }
        }
    }

    @inline(__always)
    func contains(_ c: UInt8) -> Bool {
        let word = Int(c >> 6)
        let bit = UInt64(1) << (c & 63)
        return withUnsafePointer(to: table) {
            $0.withMemoryRebound(to: UInt64.self, capacity: 4) { p in
                (p[word] & bit) != 0
            }
        }
    }
}

/// Pre-built stop sets for common parsing contexts
private let stopAtValueEnd = StopSet(
    UInt8(ascii: ","), UInt8(ascii: ")"), UInt8(ascii: "]")
)
private let stopAtSchemaEnd = StopSet(
    UInt8(ascii: ":"), UInt8(ascii: ","), UInt8(ascii: "}")
)
private let stopAtTypeEnd = StopSet(
    UInt8(ascii: ","), UInt8(ascii: "}"), UInt8(ascii: "]"), UInt8(ascii: "?")
)

public enum AsonError: Error, CustomStringConvertible {
    case invalidRoot(String)
    case invalidSchema(String)
    case invalidData(String)
    case unexpectedEOF

    public var description: String {
        switch self {
        case .invalidRoot(let s): return "invalid root: \(s)"
        case .invalidSchema(let s): return "invalid schema: \(s)"
        case .invalidData(let s): return "invalid data: \(s)"
        case .unexpectedEOF: return "unexpected eof"
        }
    }
}

public enum AsonValue: Equatable {
    case int(Int64)
    case uint(UInt64)
    case float(Double)
    case bool(Bool)
    case string(String)
    case array([AsonValue])
    case object([String: AsonValue])
    case null
}

private indirect enum SchemaType: Equatable {
    case dynamic
    case int
    case uint
    case float
    case bool
    case str
    case optional(SchemaType)
    case array(SchemaType)
    case object([SchemaField])

    var isOptional: Bool {
        if case .optional = self { return true }
        return false
    }

    var unwrapped: SchemaType {
        if case .optional(let inner) = self { return inner }
        return self
    }
}

private struct SchemaField: Equatable {
    let name: String
    let type: SchemaType
}

private struct RootSchema: Equatable {
    let isSlice: Bool
    let fields: [SchemaField]
}

public func encode(_ value: AsonValue) throws -> String {
    let inferred = try inferRootSchema(from: value, typed: false)
    return try encodeWithSchema(value, schema: inferred, typed: false)
}

public func encodeTyped(_ value: AsonValue) throws -> String {
    let inferred = try inferRootSchema(from: value, typed: true)
    return try encodeWithSchema(value, schema: inferred, typed: true)
}

public func encodePretty(_ value: AsonValue) throws -> String {
    try prettyFormat(encode(value))
}

public func encodePrettyTyped(_ value: AsonValue) throws -> String {
    try prettyFormat(encodeTyped(value))
}

public func decode(_ text: String) throws -> AsonValue {
    var p = TextParser(text)
    let schema = try p.parseRootSchema()
    p.skipNoise()
    try p.expect(byte: 0x3A) // ':'
    p.skipNoise()

    if schema.isSlice {
        var rows: [AsonValue] = []
        while true {
            p.skipNoise()
            if p.isAtEnd { break }
            let obj = try p.parseTuple(fields: schema.fields)
            rows.append(.object(obj))
            p.skipNoise()
            if p.peek() == 0x2C { // ','
                p.advance()
                continue
            }
            break
        }
        p.skipNoise()
        return .array(rows)
    }

    let obj = try p.parseTuple(fields: schema.fields)
    p.skipNoise()
    return .object(obj)
}

public func encodeBinary(_ value: AsonValue) throws -> Data {
    let schema = try inferRootSchema(from: value, typed: true)
    let textSchema = buildSchemaHeader(schema, typed: true)

    var writer = BinaryWriter()
    writer.writeStaticBytes([0x41, 0x53, 0x4F, 0x4E, 0x42, 0x49, 0x4E, 0x31]) // "ASONBIN1"
    try writer.writeString32(textSchema)

    let rows: [[String: AsonValue]]
    if schema.isSlice {
        guard case .array(let arr) = value else {
            throw AsonError.invalidRoot("slice root must be array")
        }
        rows = try arr.map { row in
            guard case .object(let obj) = row else {
                throw AsonError.invalidRoot("array root requires object rows")
            }
            return obj
        }
    } else {
        guard case .object(let obj) = value else {
            throw AsonError.invalidRoot("root must be object")
        }
        rows = [obj]
    }

    writer.writeUInt32(UInt32(rows.count))
    for row in rows {
        for f in schema.fields {
            let v = row[f.name] ?? .null
            try writer.writeValue(v, as: f.type)
        }
    }

    return writer.data
}

public func decodeBinary(_ data: Data) throws -> AsonValue {
    var reader = BinaryReader(data)
    let magic = try reader.readBytes(8)
    if String(decoding: magic, as: UTF8.self) != "ASONBIN1" {
        throw AsonError.invalidData("invalid binary magic")
    }

    let schemaText = try reader.readString32()
    var sp = TextParser(schemaText)
    let schema = try sp.parseRootSchema()

    let rowCount = Int(try reader.readUInt32())
    if schema.isSlice {
        var rows: [AsonValue] = []
        rows.reserveCapacity(rowCount)
        for _ in 0..<rowCount {
            var obj: [String: AsonValue] = [:]
            obj.reserveCapacity(schema.fields.count)
            for f in schema.fields {
                obj[f.name] = try reader.readValue(as: f.type)
            }
            rows.append(.object(obj))
        }
        return .array(rows)
    }

    if rowCount != 1 {
        throw AsonError.invalidData("single root expects rowCount=1")
    }

    var obj: [String: AsonValue] = [:]
    obj.reserveCapacity(schema.fields.count)
    for f in schema.fields {
        obj[f.name] = try reader.readValue(as: f.type)
    }
    return .object(obj)
}

private func inferRootSchema(from value: AsonValue, typed: Bool) throws -> RootSchema {
    switch value {
    case .object(let obj):
        return RootSchema(isSlice: false, fields: inferObjectFields(obj, typed: typed))
    case .array(let arr):
        guard !arr.isEmpty else { return RootSchema(isSlice: true, fields: []) }
        return RootSchema(isSlice: true, fields: try inferSliceFields(arr, typed: typed))
    default:
        throw AsonError.invalidRoot("root must be object or array<object>")
    }
}

private func inferSliceFields(_ rows: [AsonValue], typed: Bool) throws -> [SchemaField] {
    var objects: [[String: AsonValue]] = []
    objects.reserveCapacity(rows.count)
    var keySet = Set<String>()

    for row in rows {
        guard case .object(let obj) = row else {
            throw AsonError.invalidRoot("array root must contain objects")
        }
        objects.append(obj)
        keySet.formUnion(obj.keys)
    }

    let keys = keySet.sorted()
    var out: [SchemaField] = []
    out.reserveCapacity(keys.count)

    for key in keys {
        var merged: SchemaType?
        for obj in objects {
            let inferred = inferType(from: obj[key] ?? .null, typed: typed)
            if let current = merged {
                merged = try mergeSchemaTypes(current, inferred)
            } else {
                merged = inferred
            }
        }
        out.append(SchemaField(name: key, type: merged ?? .dynamic))
    }

    return out
}

private func inferObjectFields(_ obj: [String: AsonValue], typed: Bool) -> [SchemaField] {
    let keys = obj.keys.sorted()
    var out: [SchemaField] = []
    out.reserveCapacity(keys.count)
    for k in keys {
        out.append(SchemaField(name: k, type: inferType(from: obj[k] ?? .null, typed: typed)))
    }
    return out
}

private func inferType(from value: AsonValue, typed: Bool) -> SchemaType {
    if !typed {
        switch value {
        case .object(let obj):
            return .object(inferObjectFields(obj, typed: false))
        case .array(let arr):
            if let first = arr.first {
                return .array(inferType(from: first, typed: false))
            }
            return .array(.dynamic)
        case .null:
            return .dynamic
        default:
            return .dynamic
        }
    }

    switch value {
    case .int: return .int
    case .uint: return .uint
    case .float: return .float
    case .bool: return .bool
    case .string: return .str
    case .null: return .optional(.str)
    case .array(let arr):
        if let first = arr.first {
            return .array(inferType(from: first, typed: true))
        }
        return .array(.str)
    case .object(let obj):
        return .object(inferObjectFields(obj, typed: true))
    }
}

private func mergeSchemaTypes(_ lhs: SchemaType, _ rhs: SchemaType) throws -> SchemaType {
    if lhs == rhs { return lhs }

    switch (lhs, rhs) {
    case (.dynamic, .dynamic):
        return .dynamic
    case (.dynamic, .array), (.array, .dynamic), (.dynamic, .object), (.object, .dynamic):
        throw AsonError.invalidRoot("array root rows must share compatible field types")
    case (.dynamic, _), (_, .dynamic):
        return .dynamic
    case (.optional(let l), .optional(let r)):
        return .optional(try mergeSchemaTypes(l, r))
    case (.optional(let inner), _):
        return .optional(try mergeOptionalInner(inner, rhs))
    case (_, .optional(let inner)):
        return .optional(try mergeOptionalInner(inner, lhs))
    case (.array(let l), .array(let r)):
        return .array(try mergeSchemaTypes(l, r))
    case (.object(let l), .object(let r)):
        return .object(try mergeObjectFields(l, r))
    default:
        throw AsonError.invalidRoot("array root rows must share compatible field types")
    }
}

private func mergeOptionalInner(_ optionalInner: SchemaType, _ other: SchemaType) throws -> SchemaType {
    if optionalInner == .str {
        return other
    }
    return try mergeSchemaTypes(optionalInner, other)
}

private func mergeObjectFields(_ lhs: [SchemaField], _ rhs: [SchemaField]) throws -> [SchemaField] {
    let leftNames = lhs.map(\.name)
    let rightNames = rhs.map(\.name)
    if leftNames != rightNames {
        throw AsonError.invalidRoot("array root rows must share compatible nested object schemas")
    }

    var merged: [SchemaField] = []
    merged.reserveCapacity(lhs.count)
    for i in lhs.indices {
        merged.append(SchemaField(name: lhs[i].name, type: try mergeSchemaTypes(lhs[i].type, rhs[i].type)))
    }
    return merged
}

private func encodeWithSchema(_ value: AsonValue, schema: RootSchema, typed: Bool) throws -> String {
    var buf: [UInt8] = []
    buf.reserveCapacity(256)
    buildSchemaHeaderBuf(&buf, schema, typed: typed)
    buf.append(0x3A) // ':'

    if schema.isSlice {
        guard case .array(let rows) = value else {
            throw AsonError.invalidRoot("slice root must be array")
        }
        var first = true
        for row in rows {
            guard case .object(let obj) = row else {
                throw AsonError.invalidRoot("slice root rows must be object")
            }
            if !first { buf.append(0x2C) } // ','
            first = false
            try encodeTupleBuf(&buf, obj, fields: schema.fields)
        }
        return String(decoding: buf, as: UTF8.self)
    }

    guard case .object(let obj) = value else {
        throw AsonError.invalidRoot("root must be object")
    }
    try encodeTupleBuf(&buf, obj, fields: schema.fields)
    return String(decoding: buf, as: UTF8.self)
}

private func buildSchemaHeader(_ schema: RootSchema, typed: Bool) -> String {
    var buf: [UInt8] = []
    buildSchemaHeaderBuf(&buf, schema, typed: typed)
    return String(decoding: buf, as: UTF8.self)
}

private func buildSchemaHeaderBuf(_ buf: inout [UInt8], _ schema: RootSchema, typed: Bool) {
    if schema.isSlice {
        buf.append(0x5B) // '['
    }
    buildObjectSchemaBuf(&buf, schema.fields, typed: typed)
    if schema.isSlice {
        buf.append(0x5D) // ']'
    }
}

private func buildObjectSchemaBuf(_ buf: inout [UInt8], _ fields: [SchemaField], typed: Bool) {
    buf.append(0x7B) // '{'
    for i in fields.indices {
        if i > 0 { buf.append(0x2C) } // ','
        let f = fields[i]
        var name = f.name
        name.withUTF8 { buf.append(contentsOf: $0) }
        if typed || requiresNestedTypeForUntyped(f.type) {
            buf.append(0x3A) // ':'
            buildTypeNameBuf(&buf, f.type, typed: typed)
        }
    }
    buf.append(0x7D) // '}'
}

private func requiresNestedTypeForUntyped(_ t: SchemaType) -> Bool {
    switch t {
    case .object, .array:
        return true
    case .optional(let inner):
        return requiresNestedTypeForUntyped(inner)
    default:
        return false
    }
}

private func buildTypeName(_ t: SchemaType, typed: Bool) -> String {
    var buf: [UInt8] = []
    buildTypeNameBuf(&buf, t, typed: typed)
    return String(decoding: buf, as: UTF8.self)
}

private func buildTypeNameBuf(_ buf: inout [UInt8], _ t: SchemaType, typed: Bool) {
    switch t {
    case .dynamic: buf.append(contentsOf: [0x73, 0x74, 0x72]) // "str"
    case .int: buf.append(contentsOf: [0x69, 0x6E, 0x74]) // "int"
    case .uint: buf.append(contentsOf: [0x75, 0x69, 0x6E, 0x74]) // "uint"
    case .float: buf.append(contentsOf: [0x66, 0x6C, 0x6F, 0x61, 0x74]) // "float"
    case .bool: buf.append(contentsOf: [0x62, 0x6F, 0x6F, 0x6C]) // "bool"
    case .str: buf.append(contentsOf: [0x73, 0x74, 0x72]) // "str"
    case .optional(let inner):
        buildTypeNameBuf(&buf, inner, typed: typed)
        buf.append(0x3F) // '?'
    case .array(let inner):
        buf.append(0x5B) // '['
        buildTypeNameBuf(&buf, inner, typed: typed)
        buf.append(0x5D) // ']'
    case .object(let fields):
        buildObjectSchemaBuf(&buf, fields, typed: typed)
    }
}

private func encodeTuple(_ obj: [String: AsonValue], fields: [SchemaField]) throws -> String {
    var buf: [UInt8] = []
    try encodeTupleBuf(&buf, obj, fields: fields)
    return String(decoding: buf, as: UTF8.self)
}

private func encodeTupleBuf(_ buf: inout [UInt8], _ obj: [String: AsonValue], fields: [SchemaField]) throws {
    buf.append(0x28) // '('
    for i in fields.indices {
        if i > 0 { buf.append(0x2C) } // ','
        let f = fields[i]
        let v = obj[f.name] ?? .null
        try encodeValueBuf(&buf, v, as: f.type)
    }
    buf.append(0x29) // ')'
}

private func encodeValue(_ value: AsonValue, as type: SchemaType) throws -> String {
    var buf: [UInt8] = []
    try encodeValueBuf(&buf, value, as: type)
    return String(decoding: buf, as: UTF8.self)
}

private func encodeValueBuf(_ buf: inout [UInt8], _ value: AsonValue, as type: SchemaType) throws {
    let base = type.unwrapped
    if type.isOptional, case .null = value {
        return
    }

    switch base {
    case .dynamic:
        try encodeDynamicBuf(&buf, value)
    case .int:
        if case .int(let v) = value { writeI64(&buf, v); return }
        if case .uint(let v) = value { writeU64(&buf, v); return }
        if case .float(let v) = value { writeI64(&buf, Int64(v)); return }
        throw AsonError.invalidData("expected int")
    case .uint:
        if case .uint(let v) = value { writeU64(&buf, v); return }
        if case .int(let v) = value { writeU64(&buf, UInt64(max(0, v))); return }
        throw AsonError.invalidData("expected uint")
    case .float:
        if case .float(let v) = value { writeF64(&buf, v); return }
        if case .int(let v) = value { writeF64(&buf, Double(v)); return }
        if case .uint(let v) = value { writeF64(&buf, Double(v)); return }
        throw AsonError.invalidData("expected float")
    case .bool:
        if case .bool(let b) = value {
            if b { buf.append(contentsOf: [0x74,0x72,0x75,0x65]) } // "true"
            else { buf.append(contentsOf: [0x66,0x61,0x6C,0x73,0x65]) } // "false"
            return
        }
        throw AsonError.invalidData("expected bool")
    case .str:
        if case .string(let str) = value { encodeStringBuf(&buf, str); return }
        if case .null = value { return }
        encodeStringBuf(&buf, try stringify(value))
        return
    case .array(let inner):
        guard case .array(let arr) = value else {
            throw AsonError.invalidData("expected array")
        }
        buf.append(0x5B) // '['
        for i in arr.indices {
            if i > 0 { buf.append(0x2C) } // ','
            try encodeValueBuf(&buf, arr[i], as: inner)
        }
        buf.append(0x5D) // ']'
        return
    case .object(let fields):
        guard case .object(let obj) = value else {
            throw AsonError.invalidData("expected object")
        }
        try encodeTupleBuf(&buf, obj, fields: fields)
        return
    case .optional:
        throw AsonError.invalidData("nested optional not supported")
    }
}

private func encodeDynamic(_ value: AsonValue) throws -> String {
    var buf: [UInt8] = []
    try encodeDynamicBuf(&buf, value)
    return String(decoding: buf, as: UTF8.self)
}

private func encodeDynamicBuf(_ buf: inout [UInt8], _ value: AsonValue) throws {
    switch value {
    case .int(let v): writeI64(&buf, v)
    case .uint(let v): writeU64(&buf, v)
    case .float(let v): writeF64(&buf, v)
    case .bool(let b):
        if b { buf.append(contentsOf: [0x74,0x72,0x75,0x65]) }
        else { buf.append(contentsOf: [0x66,0x61,0x6C,0x73,0x65]) }
    case .string(let s): encodeStringBuf(&buf, s)
    case .array(let arr):
        buf.append(0x5B) // '['
        for i in arr.indices {
            if i > 0 { buf.append(0x2C) } // ','
            try encodeDynamicBuf(&buf, arr[i])
        }
        buf.append(0x5D) // ']'
    case .object(let obj):
        let fields = inferObjectFields(obj, typed: false)
        try encodeTupleBuf(&buf, obj, fields: fields)
    case .null:
        break
    }
}

private func stringify(_ value: AsonValue) throws -> String {
    switch value {
    case .int(let v): return String(v)
    case .uint(let v): return String(v)
    case .float(let v): return formatFloat(v)
    case .bool(let v): return v ? "true" : "false"
    case .string(let s): return s
    case .null: return ""
    default: throw AsonError.invalidData("cannot stringify complex value")
    }
}

private func formatFloat(_ v: Double) -> String {
    var buf: [UInt8] = []
    writeF64(&buf, v)
    return String(decoding: buf, as: UTF8.self)
}

// 256-byte lookup table: true if byte needs quoting in ASON values
private let NEEDS_QUOTE_TABLE: [Bool] = {
    var t = [Bool](repeating: false, count: 256)
    for i in 0..<32 { t[i] = true } // control chars
    t[Int(UInt8(ascii: ","))] = true
    t[Int(UInt8(ascii: "("))] = true
    t[Int(UInt8(ascii: ")"))] = true
    t[Int(UInt8(ascii: "["))] = true
    t[Int(UInt8(ascii: "]"))] = true
    t[Int(UInt8(ascii: "\""))] = true
    t[Int(UInt8(ascii: "\\"))] = true
    return t
}()

/// Load 16 bytes from a pointer into SIMD16 register.
@inline(__always)
private func loadSIMD16(_ p: UnsafePointer<UInt8>) -> SIMD16<UInt8> {
    SIMD16<UInt8>(
        p[0], p[1], p[2], p[3], p[4], p[5], p[6], p[7],
        p[8], p[9], p[10], p[11], p[12], p[13], p[14], p[15]
    )
}

/// SIMD-accelerated: find first byte needing escape (\, \", \n, \t, or control char).
/// Returns offset from `base+start`, or `count` if none found.
@inline(__always)
private func simdFindEscape(_ base: UnsafePointer<UInt8>, _ start: Int, _ count: Int) -> Int {
    var i = start
    let v_1f = SIMD16<UInt8>(repeating: 0x1F)
    let v_bs  = SIMD16<UInt8>(repeating: 0x5C)
    let v_qt  = SIMD16<UInt8>(repeating: 0x22)
    while i + 16 <= count {
        let chunk = loadSIMD16(base + i)
        // control chars (<= 0x1F) | backslash | double-quote
        let mask = (chunk .< v_1f .| chunk .== v_1f) .| chunk .== v_bs .| chunk .== v_qt
        if mask != SIMDMask(repeating: false) {
            for lane in 0..<16 { if mask[lane] { return i + lane } }
        }
        i += 16
    }
    while i < count {
        let b = base[i]
        if b < 0x20 || b == 0x5C || b == 0x22 { return i }
        i += 1
    }
    return count
}

/// SIMD-accelerated: check if bytes contain any ASON special char requiring quoting.
@inline(__always)
private func simdHasSpecialChars(_ base: UnsafePointer<UInt8>, _ count: Int) -> Bool {
    var i = 0
    let v_1f = SIMD16<UInt8>(repeating: 0x1F)
    let v_comma = SIMD16<UInt8>(repeating: 0x2C)
    let v_lp = SIMD16<UInt8>(repeating: 0x28)
    let v_rp = SIMD16<UInt8>(repeating: 0x29)
    let v_lb = SIMD16<UInt8>(repeating: 0x5B)
    let v_rb = SIMD16<UInt8>(repeating: 0x5D)
    let v_qt = SIMD16<UInt8>(repeating: 0x22)
    let v_bs = SIMD16<UInt8>(repeating: 0x5C)
    while i + 16 <= count {
        let chunk = loadSIMD16(base + i)
        let mask = (chunk .< v_1f .| chunk .== v_1f)
            .| chunk .== v_comma .| chunk .== v_lp .| chunk .== v_rp
            .| chunk .== v_lb .| chunk .== v_rb
            .| chunk .== v_qt .| chunk .== v_bs
        if mask != SIMDMask(repeating: false) { return true }
        i += 16
    }
    while i < count {
        if NEEDS_QUOTE_TABLE[Int(base[i])] { return true }
        i += 1
    }
    return false
}

private func encodeString(_ s: String) -> String {
    var buf: [UInt8] = []
    encodeStringBuf(&buf, s)
    return String(decoding: buf, as: UTF8.self)
}

/// Zero-copy string encoding: uses withUTF8 to avoid Array(s.utf8) copy.
private func encodeStringBuf(_ buf: inout [UInt8], _ s: String) {
    var str = s
    str.withUTF8 { utf8 in
        guard let base = utf8.baseAddress else {
            buf.append(0x22); buf.append(0x22) // empty → \"\"
            return
        }
        let count = utf8.count
        if count == 0 {
            buf.append(0x22); buf.append(0x22)
            return
        }
        if needsQuoteRaw(base, count) {
            buf.append(0x22) // '"'
            // SIMD-accelerated: bulk-copy safe runs, escape only special bytes
            var start = 0
            while start < count {
                let next = simdFindEscape(base, start, count)
                if next > start {
                    buf.append(contentsOf: UnsafeBufferPointer(start: base + start, count: next - start))
                }
                if next >= count { break }
                let b = base[next]
                switch b {
                case 0x5C: buf.append(0x5C); buf.append(0x5C)
                case 0x22: buf.append(0x5C); buf.append(0x22)
                case 0x0A: buf.append(0x5C); buf.append(0x6E)
                case 0x09: buf.append(0x5C); buf.append(0x74)
                default:   buf.append(b) // other control chars pass through
                }
                start = next + 1
            }
            buf.append(0x22) // '"'
        } else {
            buf.append(contentsOf: UnsafeBufferPointer(start: base, count: count))
        }
    }
}

/// Check if string bytes need quoting. Takes raw pointer — zero-copy.
@inline(__always)
private func needsQuoteRaw(_ ptr: UnsafePointer<UInt8>, _ count: Int) -> Bool {
    if count == 0 { return true }
    if ptr[0] == 0x20 || ptr[count - 1] == 0x20 { return true }
    if count == 4 && ptr[0] == 0x74 && ptr[1] == 0x72 && ptr[2] == 0x75 && ptr[3] == 0x65 { return true }
    if count == 5 && ptr[0] == 0x66 && ptr[1] == 0x61 && ptr[2] == 0x6C && ptr[3] == 0x73 && ptr[4] == 0x65 { return true }
    if simdHasSpecialChars(ptr, count) { return true }
    // Check if looks like a number
    var s = 0
    if ptr[0] == 0x2D { s = 1 }
    if s >= count { return false }
    var allDigitDot = true
    for i in s..<count {
        let c = ptr[i]
        if !((c >= 0x30 && c <= 0x39) || c == 0x2E) { allDigitDot = false; break }
    }
    return allDigitDot
}

private struct TextParser {
    let storage: [UInt8]
    var idx: Int = 0

    init(_ text: String) {
        self.storage = Array(text.utf8)
    }

    var isAtEnd: Bool { idx >= storage.count }

    @inline(__always)
    mutating func skipNoise() {
        while idx < storage.count {
            let c = storage[idx]
            if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D { // space, tab, \n, \r
                idx += 1
                continue
            }
            if c == 0x2F, idx + 1 < storage.count { // '/'
                let n = storage[idx + 1]
                if n == 0x2F { // '//'
                    idx += 2
                    while idx < storage.count, storage[idx] != 0x0A { idx += 1 }
                    continue
                }
                if n == 0x2A { // '/*'
                    idx += 2
                    while idx + 1 < storage.count {
                        if storage[idx] == 0x2A, storage[idx + 1] == 0x2F { // '*/'
                            idx += 2
                            break
                        }
                        idx += 1
                    }
                    continue
                }
            }
            break
        }
    }

    @inline(__always)
    func peek() -> UInt8? {
        idx < storage.count ? storage[idx] : nil
    }

    @inline(__always)
    mutating func advance() {
        idx += 1
    }

    @inline(__always)
    mutating func expect(byte: UInt8) throws {
        guard idx < storage.count, storage[idx] == byte else {
            throw AsonError.invalidData("expected char \(UnicodeScalar(byte))")
        }
        idx += 1
    }

    mutating func parseRootSchema() throws -> RootSchema {
        skipNoise()
        var isSlice = false
        if peek() == 0x5B { // '['
            isSlice = true
            advance()
            skipNoise()
        }

        let fields = try parseObjectSchema()

        if isSlice {
            skipNoise()
            try expect(byte: 0x5D) // ']'
        }
        return RootSchema(isSlice: isSlice, fields: fields)
    }

    mutating func parseObjectSchema() throws -> [SchemaField] {
        skipNoise()
        try expect(byte: 0x7B) // '{'
        skipNoise()

        var out: [SchemaField] = []
        while true {
            skipNoise()
            if peek() == 0x7D { // '}'
                advance()
                break
            }

            let name = try parseBareTokenFast(stopAtSchemaEnd)
            skipNoise()

            var t: SchemaType = .dynamic
            if peek() == 0x3A { // ':'
                advance()
                skipNoise()
                t = try parseType()
            }

            out.append(SchemaField(name: name, type: t))
            skipNoise()

            if peek() == 0x2C { // ','
                advance()
                continue
            }
            if peek() == 0x7D { // '}'
                advance()
                break
            }
            throw AsonError.invalidSchema("expected ',' or '}'")
        }

        return out
    }

    mutating func parseType() throws -> SchemaType {
        skipNoise()
        guard let c = peek() else { throw AsonError.unexpectedEOF }

        if c == 0x7B { // '{'
            let fields = try parseObjectSchema()
            var t: SchemaType = .object(fields)
            if peek() == 0x3F { advance(); t = .optional(t) } // '?'
            return t
        }

        if c == 0x5B { // '['
            advance()
            let inner = try parseType()
            skipNoise()
            try expect(byte: 0x5D) // ']'
            var t: SchemaType = .array(inner)
            if peek() == 0x3F { advance(); t = .optional(t) } // '?'
            return t
        }

        let name = try parseBareTokenFast(stopAtTypeEnd)
        var t: SchemaType
        switch name {
        case "int": t = .int
        case "uint": t = .uint
        case "float": t = .float
        case "bool": t = .bool
        case "str": t = .str
        default: throw AsonError.invalidSchema("unknown type '\(name)'")
        }
        if peek() == 0x3F { advance(); t = .optional(t) } // '?'
        return t
    }

    mutating func parseTuple(fields: [SchemaField]) throws -> [String: AsonValue] {
        skipNoise()
        try expect(byte: 0x28) // '('
        var out: [String: AsonValue] = [:]
        out.reserveCapacity(fields.count)
        for i in fields.indices {
            skipNoise()
            let f = fields[i]
            out[f.name] = try parseValue(as: f.type)
            skipNoise()
            if i + 1 < fields.count {
                try expect(byte: 0x2C) // ','
            }
        }
        skipNoise()
        try expect(byte: 0x29) // ')'
        return out
    }

    mutating func parseValue(as type: SchemaType) throws -> AsonValue {
        skipNoise()

        if type.isOptional {
            if let c = peek(), c == 0x2C || c == 0x29 || c == 0x5D { // ',', ')', ']'
                return .null
            }
        }

        switch type.unwrapped {
        case .dynamic:
            return try parseDynamicValue()
        case .int:
            return .int(try parseInt64())
        case .uint:
            return .uint(try parseUInt64())
        case .float:
            return .float(try parseDouble())
        case .bool:
            return .bool(try parseBool())
        case .str:
            return .string(try parseStringToken())
        case .array(let inner):
            try expect(byte: 0x5B) // '['
            var arr: [AsonValue] = []
            while true {
                skipNoise()
                if peek() == 0x5D { advance(); break } // ']'
                arr.append(try parseValue(as: inner))
                skipNoise()
                if peek() == 0x2C { advance(); continue } // ','
                if peek() == 0x5D { advance(); break } // ']'
                throw AsonError.invalidData("array expected ',' or ']'")
            }
            return .array(arr)
        case .object(let fields):
            return .object(try parseTuple(fields: fields))
        case .optional:
            throw AsonError.invalidData("nested optional unsupported")
        }
    }

    mutating func parseDynamicValue() throws -> AsonValue {
        skipNoise()
        guard let c = peek() else { return .null }
        if c == 0x22 { // '"'
            return .string(try parseQuotedString())
        }
        if c == 0x5B { // '['
            advance()
            var arr: [AsonValue] = []
            while true {
                skipNoise()
                if peek() == 0x5D { advance(); break } // ']'
                arr.append(try parseDynamicValue())
                skipNoise()
                if peek() == 0x2C { advance(); continue } // ','
                if peek() == 0x5D { advance(); break } // ']'
                throw AsonError.invalidData("bad array value")
            }
            return .array(arr)
        }

        let token = try parseBareTokenFast(stopAtValueEnd)
        if token.isEmpty { return .null }
        if token == "true" { return .bool(true) }
        if token == "false" { return .bool(false) }
        if let i = Int64(token) { return .int(i) }
        if let d = Double(token) { return .float(d) }
        return .string(token)
    }

    mutating func parseStringToken() throws -> String {
        skipNoise()
        if peek() == 0x22 { return try parseQuotedString() }
        return try parseBareTokenFast(stopAtValueEnd)
    }

    mutating func parseQuotedString() throws -> String {
        try expect(byte: 0x22) // '"'
        let start = idx
        // SIMD-accelerated fast scan: find first quote or backslash
        storage.withUnsafeBufferPointer { bufPtr in
            guard let base = bufPtr.baseAddress else { return }
            var i = idx
            let end = bufPtr.count
            let v_qt = SIMD16<UInt8>(repeating: 0x22)
            let v_bs = SIMD16<UInt8>(repeating: 0x5C)
            while i + 16 <= end {
                let chunk = loadSIMD16(base + i)
                let mask = chunk .== v_qt .| chunk .== v_bs
                if mask != SIMDMask(repeating: false) {
                    for lane in 0..<16 {
                        if mask[lane] { idx = i + lane; return }
                    }
                }
                i += 16
            }
            // Scalar tail
            while i < end {
                let c = base[i]
                if c == 0x22 || c == 0x5C { idx = i; return }
                i += 1
            }
            idx = end
        }
        // If we found a plain quote (no backslash), fast zero-copy return
        if idx < storage.count && storage[idx] == 0x22 {
            let result = String(decoding: storage[start..<idx], as: UTF8.self)
            idx += 1
            return result
        }
        // Slow path: has escapes — build byte buffer
        idx = start
        var buf: [UInt8] = []
        while true {
            guard idx < storage.count else { throw AsonError.unexpectedEOF }
            let c = storage[idx]
            idx += 1
            if c == 0x22 { break }
            if c == 0x5C {
                guard idx < storage.count else { throw AsonError.unexpectedEOF }
                let n = storage[idx]; idx += 1
                switch n {
                case 0x6E: buf.append(0x0A)
                case 0x74: buf.append(0x09)
                case 0x5C: buf.append(0x5C)
                case 0x22: buf.append(0x22)
                default: buf.append(n)
                }
            } else {
                buf.append(c)
            }
        }
        return String(decoding: buf, as: UTF8.self)
    }

    @inline(__always)
    mutating func parseBool() throws -> Bool {
        skipNoise()
        // Fast check: 't' for true, 'f' for false
        guard idx < storage.count else { throw AsonError.invalidData("invalid bool") }
        if storage[idx] == 0x74 && idx + 4 <= storage.count { // 't'
            if storage[idx+1] == 0x72 && storage[idx+2] == 0x75 && storage[idx+3] == 0x65 {
                idx += 4; return true
            }
        }
        if storage[idx] == 0x66 && idx + 5 <= storage.count { // 'f'
            if storage[idx+1] == 0x61 && storage[idx+2] == 0x6C && storage[idx+3] == 0x73 && storage[idx+4] == 0x65 {
                idx += 5; return false
            }
        }
        throw AsonError.invalidData("invalid bool")
    }

    @inline(__always)
    mutating func parseInt64() throws -> Int64 {
        skipNoise()
        var neg = false
        if idx < storage.count && storage[idx] == 0x2D { neg = true; idx += 1 } // '-'
        var val: UInt64 = 0
        let start = idx
        let maxValue = neg ? UInt64(Int64.max) + 1 : UInt64(Int64.max)
        while idx < storage.count {
            let c = storage[idx]
            if c >= 0x30 && c <= 0x39 { // '0'-'9'
                let digit = UInt64(c - 0x30)
                if val > maxValue / 10 || (val == maxValue / 10 && digit > maxValue % 10) {
                    throw AsonError.invalidData("int overflow")
                }
                val = val * 10 + digit
                idx += 1
            } else { break }
        }
        if idx == start { throw AsonError.invalidData("invalid int") }
        if neg {
            // Handle Int64.min: val == 9223372036854775808 which can't fit in Int64
            if val > UInt64(Int64.max) + 1 { throw AsonError.invalidData("int overflow") }
            return val == UInt64(Int64.max) + 1 ? Int64.min : -Int64(val)
        }
        return Int64(val)
    }

    @inline(__always)
    mutating func parseUInt64() throws -> UInt64 {
        skipNoise()
        var val: UInt64 = 0
        let start = idx
        while idx < storage.count {
            let c = storage[idx]
            if c >= 0x30 && c <= 0x39 {
                let digit = UInt64(c - 0x30)
                if val > UInt64.max / 10 || (val == UInt64.max / 10 && digit > UInt64.max % 10) {
                    throw AsonError.invalidData("uint overflow")
                }
                val = val * 10 + digit
                idx += 1
            } else { break }
        }
        if idx == start { throw AsonError.invalidData("invalid uint") }
        return val
    }

    @inline(__always)
    mutating func parseDouble() throws -> Double {
        skipNoise()
        let start = idx
        // Scan digits, sign, dot, e/E
        if idx < storage.count && (storage[idx] == 0x2D || storage[idx] == 0x2B) { idx += 1 } // sign
        while idx < storage.count && storage[idx] >= 0x30 && storage[idx] <= 0x39 { idx += 1 }
        if idx < storage.count && storage[idx] == 0x2E { // '.'
            idx += 1
            while idx < storage.count && storage[idx] >= 0x30 && storage[idx] <= 0x39 { idx += 1 }
        }
        if idx < storage.count && (storage[idx] == 0x65 || storage[idx] == 0x45) { // 'e'/'E'
            idx += 1
            if idx < storage.count && (storage[idx] == 0x2D || storage[idx] == 0x2B) { idx += 1 }
            while idx < storage.count && storage[idx] >= 0x30 && storage[idx] <= 0x39 { idx += 1 }
        }
        if idx == start { throw AsonError.invalidData("invalid float") }
        let s = String(decoding: storage[start..<idx], as: UTF8.self)
        guard let v = Double(s) else { throw AsonError.invalidData("invalid float") }
        return v
    }

    @inline(__always)
    mutating func parseBareTokenFast(_ stopSet: StopSet) throws -> String {
        skipNoise()
        let start = idx
        while idx < storage.count {
            let c = storage[idx]
            if stopSet.contains(c) { break }
            idx += 1
        }
        // Trim trailing whitespace
        var end = idx
        while end > start {
            let c = storage[end - 1]
            if c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D { end -= 1 }
            else { break }
        }
        return String(decoding: storage[start..<end], as: UTF8.self)
    }
}

private struct BinaryWriter {
    var data = Data()

    init() {
        data.reserveCapacity(256)
    }

    mutating func writeBytes(_ bytes: [UInt8]) {
        data.append(contentsOf: bytes)
    }

    mutating func writeStaticBytes(_ bytes: [UInt8]) {
        data.append(contentsOf: bytes)
    }

    mutating func writeUInt32(_ v: UInt32) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
    }

    mutating func writeInt64(_ v: Int64) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
    }

    mutating func writeUInt64(_ v: UInt64) {
        var x = v.littleEndian
        withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
    }

    mutating func writeDouble(_ v: Double) {
        var x = v.bitPattern.littleEndian
        withUnsafeBytes(of: &x) { data.append(contentsOf: $0) }
    }

    mutating func writeString32(_ s: String) throws {
        let count = s.utf8.count
        guard count <= Int(UInt32.max) else {
            throw AsonError.invalidData("string too large")
        }
        writeUInt32(UInt32(count))
        var copy = s
        copy.withUTF8 { data.append(contentsOf: $0) }
    }

    mutating func writeValue(_ value: AsonValue, as type: SchemaType) throws {
        if type.isOptional {
            if case .null = value {
                writeStaticBytes([0])
                return
            }
            writeStaticBytes([1])
        }

        switch type.unwrapped {
        case .dynamic:
            let s = try encodeDynamic(value)
            try writeString32(s)
        case .int:
            if case .int(let v) = value { writeInt64(v); return }
            if case .uint(let v) = value { writeInt64(Int64(v)); return }
            throw AsonError.invalidData("binary int type mismatch")
        case .uint:
            if case .uint(let v) = value { writeUInt64(v); return }
            if case .int(let v) = value { writeUInt64(UInt64(max(0, v))); return }
            throw AsonError.invalidData("binary uint type mismatch")
        case .float:
            if case .float(let v) = value { writeDouble(v); return }
            if case .int(let v) = value { writeDouble(Double(v)); return }
            if case .uint(let v) = value { writeDouble(Double(v)); return }
            throw AsonError.invalidData("binary float type mismatch")
        case .bool:
            if case .bool(let v) = value { writeBytes([v ? 1 : 0]); return }
            throw AsonError.invalidData("binary bool type mismatch")
        case .str:
            if case .string(let s) = value { try writeString32(s); return }
            if case .null = value { writeUInt32(UInt32.max); return }
            throw AsonError.invalidData("binary string type mismatch")
        case .array(let inner):
            guard case .array(let arr) = value else {
                throw AsonError.invalidData("binary array type mismatch")
            }
            writeUInt32(UInt32(arr.count))
            for v in arr {
                try writeValue(v, as: inner)
            }
        case .object(let fields):
            guard case .object(let obj) = value else {
                throw AsonError.invalidData("binary object type mismatch")
            }
            for f in fields {
                try writeValue(obj[f.name] ?? .null, as: f.type)
            }
        case .optional:
            throw AsonError.invalidData("nested optional unsupported")
        }
    }
}

private struct BinaryReader {
    let data: Data
    var idx: Int = 0

    init(_ data: Data) {
        self.data = data
    }

    mutating func readBytes(_ count: Int) throws -> [UInt8] {
        guard idx + count <= data.count else { throw AsonError.unexpectedEOF }
        let out = Array(data[idx..<(idx + count)])
        idx += count
        return out
    }

    mutating func readUInt32() throws -> UInt32 {
        let value: UInt32 = try readFixedWidthInteger()
        return value.littleEndian
    }

    mutating func readInt64() throws -> Int64 {
        let value: Int64 = try readFixedWidthInteger()
        return value.littleEndian
    }

    mutating func readUInt64() throws -> UInt64 {
        let value: UInt64 = try readFixedWidthInteger()
        return value.littleEndian
    }

    mutating func readDouble() throws -> Double {
        let bits = try readUInt64()
        return Double(bitPattern: bits)
    }

    mutating func readString32() throws -> String {
        let len = try readUInt32()
        if len == UInt32.max { return "" }
        let bytes = try readBytes(Int(len))
        return String(decoding: bytes, as: UTF8.self)
    }

    mutating func readValue(as type: SchemaType) throws -> AsonValue {
        if type.isOptional {
            let marker = try readBytes(1)
            switch marker[0] {
            case 0:
                return .null
            case 1:
                break
            default:
                throw AsonError.invalidData("invalid optional marker")
            }
        }

        switch type.unwrapped {
        case .dynamic:
            let t = try readString32()
            return .string(t)
        case .int:
            return .int(try readInt64())
        case .uint:
            return .uint(try readUInt64())
        case .float:
            return .float(try readDouble())
        case .bool:
            let b = try readBytes(1)
            return .bool(b[0] != 0)
        case .str:
            let len = try readUInt32()
            if len == UInt32.max { return .null }
            let bytes = try readBytes(Int(len))
            return .string(String(decoding: bytes, as: UTF8.self))
        case .array(let inner):
            let n = Int(try readUInt32())
            var out: [AsonValue] = []
            out.reserveCapacity(n)
            for _ in 0..<n {
                out.append(try readValue(as: inner))
            }
            return .array(out)
        case .object(let fields):
            var out: [String: AsonValue] = [:]
            out.reserveCapacity(fields.count)
            for f in fields {
                out[f.name] = try readValue(as: f.type)
            }
            return .object(out)
        case .optional:
            throw AsonError.invalidData("nested optional unsupported")
        }
    }

    mutating func readFixedWidthInteger<T: FixedWidthInteger>() throws -> T {
        let size = MemoryLayout<T>.size
        guard idx + size <= data.count else { throw AsonError.unexpectedEOF }
        let value = data.withUnsafeBytes { raw in
            raw.loadUnaligned(fromByteOffset: idx, as: T.self)
        }
        idx += size
        return value
    }
}

public func prettyFormat(_ src: String) throws -> String {
    var buf: [UInt8] = []
    buf.reserveCapacity(src.utf8.count + src.utf8.count / 4)
    var depth = 0
    var inQuote = false
    var escaped = false

    @inline(__always) func appendIndent(_ buf: inout [UInt8], _ d: Int) {
        for _ in 0..<max(0, d) { buf.append(0x20); buf.append(0x20) }
    }

    var s = src
    s.withUTF8 { utf8 in
        guard let base = utf8.baseAddress else { return }
        for i in 0..<utf8.count {
            let c = base[i]
            if inQuote {
                buf.append(c)
                if escaped { escaped = false }
                else if c == 0x5C { escaped = true }
                else if c == 0x22 { inQuote = false }
                continue
            }
            if c == 0x22 { inQuote = true; buf.append(c); continue }
            switch c {
            case 0x3A: // ':'
                buf.append(0x3A); buf.append(0x0A)
            case 0x28: // '('
                buf.append(0x28); depth += 1; buf.append(0x0A); appendIndent(&buf, depth)
            case 0x5B, 0x7B: // '[', '{'
                buf.append(c)
            case 0x29: // ')'
                depth -= 1; buf.append(0x0A); appendIndent(&buf, depth); buf.append(0x29)
            case 0x2C: // ','
                buf.append(0x2C); buf.append(0x0A); appendIndent(&buf, depth)
            default:
                buf.append(c)
            }
        }
    }
    return String(decoding: buf, as: UTF8.self)
}
