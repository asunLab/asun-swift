# asun-swift

Swift implementation for [ASUN](https://github.com/asunLab/asun), focused on low-allocation encoding/decoding, schema-first data layout, and high-throughput binary pipelines.

[中文文档](https://github.com/asunLab/asun-swift/blob/main/README_CN.md)

## Why ASUN?

**json**

Standard JSON repeats every field name in every record. When you send structured data to an LLM, over an API, or across services, that repetition wastes tokens, bytes, and attention:

```json
[
  { "id": 1, "name": "Alice", "active": true },
  { "id": 2, "name": "Bob", "active": false },
  { "id": 3, "name": "Carol", "active": true }
]
```

**asun**

ASUN declares the schema **once** and streams data as compact tuples:

```asun
[{id, name, active}]:
  (1,Alice,true),
  (2,Bob,false),
  (3,Carol,true)
```

**Fewer tokens. Smaller payloads. Clearer structure.**

---

## Highlights

- UTF-8 byte-buffer parser with explicit cursor-based scanning
- SIMD fast-path for special-character detection during string quoting
- No JSON bridge in hot paths (`encode`/`decode`/`encodeBinary`/`decodeBinary`)
- Schema-first tuple encoding to reduce repeated field-name overhead
- Typed and untyped text modes + pretty format
- Binary codec with scalar-hint schema header for direct roundtrip
- Follows the latest ASUN spec: `@` is the field binding marker, scalar hints are optional, and complex fields keep the required `@{}` / `@[]` structural bindings
- No standalone `map` type; dictionary-like data should be modeled as arrays of key-value tuples such as `attrs@[{key@str,value@int}]`

## API

- `encode(_:)`
- `decode(_:)`
- `encodeBinary(_:)`
- `decodeBinary(_:)`
- `encodePrettyTyped(_:)`
- `encodePretty(_:)`
- `encodeTyped(_:)`

## Quick Start

```swift
import AsunSwift

let user: AsunValue = .object([
  "id": .int(1),
  "name": .string("Alice"),
  "active": .bool(true)
])

let text = try encode(user)
let typed = try encodeTyped(user)
let parsed = try decode(typed)
let bin = try encodeBinary(user)
let back = try decodeBinary(bin)
```

```swift
let team = try decode("""
{name@str,members@[{id@int,name@str}],attrs@[{key@str,value@str}]}:
  (core, [(1,Alice),(2,Bob)], [(region,apac),(tier,gold)])
""")
```

## Examples

```bash
swift run basic
swift run complex
swift run cross_compat
swift run bench -c release
```

## Testing

```bash
swift run run_tests
```

## Performance Advantages

- Fewer transient allocations by parsing directly on byte buffers.
- SIMD branch reduces delimiter scanning cost for ASCII-heavy payloads.
- Tuple-style data rows avoid repeated key serialization compared to JSON objects.
- Binary mode avoids text parse overhead and provides stable, compact IO framing.

## Test Advantages

- Covers text encode/decode and binary roundtrip.
- Includes escaping, multiline input, comments, and array/object schemas.
- Mirrors the same functional coverage style used by other ASUN language ports.
- Suitable as baseline for cross-language compatibility extension tests.

## License

MIT. See [LICENSE](LICENSE).
