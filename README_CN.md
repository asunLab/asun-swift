# asun-swift

[ASUN](https://github.com/asunLab/asun) 的 Swift 版本，核心目标是低分配编解码、Schema 优先布局与高吞吐二进制链路。

[English](https://github.com/asunLab/asun-swift/blob/main/README.md)

## 特性

- 基于 UTF-8 字节缓冲区 + 索引游标的解析
- 热路径不走 JSON 中间层（`encode`/`decode`/`encodeBinary`/`decodeBinary`）
- Schema-first 元组编码，减少重复字段名开销
- 支持 typed / untyped 文本输出与 pretty 格式
- 二进制编解码带基本类型提示 schema 头，支持直接 roundtrip
- 遵循最新 ASUN 规范：`@` 是字段绑定符，基本类型提示可选，复杂类型必须保留 `@{}` / `@[]` 结构绑定

## API

- `encode(_:)`
- `decode(_:)`
- `encodeBinary(_:)`
- `decodeBinary(_:)`
- `encodePrettyTyped(_:)`
- `encodePretty(_:)`
- `encodeTyped(_:)`

## 快速开始

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

## 示例

```bash
swift run basic
swift run complex
swift run cross_compat
swift run bench -c release
```

## 测试

```bash
swift run run_tests
```

## 性能优势

- 直接在字节缓冲区上解析，临时对象和中间分配更少。
- SIMD 分支优化 ASCII 数据的分隔符扫描。
- 元组行编码避免 JSON 对象反复写字段名。
- 二进制模式减少文本解析开销，适合高吞吐 IO 场景。

## 测试优势

- 覆盖文本编解码和二进制 roundtrip。
- 包含转义字符串、多行输入、注释、数组/对象 schema 等场景。
- 与其它 ASUN 语言实现保持同风格覆盖方式。
- 可作为跨语言兼容扩展测试的基础用例。

## 许可证

MIT。见 [LICENSE](LICENSE)。
