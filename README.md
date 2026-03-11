# ason-swift

Swift implementation for [ASON](https://github.com/ason-lab/ason), focused on low-allocation encoding/decoding, schema-first data layout, and high-throughput binary pipelines.

[中文文档](README_CN.md)

## Highlights

- UTF-8 byte-buffer parser with explicit cursor-based scanning
- SIMD fast-path for special-character detection during string quoting
- No JSON bridge in hot paths (`encode`/`decode`/`encodeBinary`/`decodeBinary`)
- Schema-first tuple encoding to reduce repeated field-name overhead
- Typed and untyped text modes + pretty format
- Binary codec with typed schema header for direct roundtrip

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
import AsonSwift

let user: AsonValue = .object([
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
- Mirrors the same functional coverage style used by other ASON language ports.
- Suitable as baseline for cross-language compatibility extension tests.

## License

MIT. See [LICENSE](LICENSE).
