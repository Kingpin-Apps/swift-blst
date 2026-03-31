# CBlst.xcframework Binary Checksums

These SHA-256 checksums cover the prebuilt `libblst.a` static libraries committed in
`CBlst.xcframework/`. Verify them before trusting a checkout, and regenerate them any
time the framework is rebuilt.

## blst upstream source

| Field   | Value |
|---------|-------|
| Repo    | https://github.com/supranational/blst |
| Commit  | `f262a6e9985f84e1d2842960a158dc768b217884` |
| Date    | 2026-03-16 |

## SHA-256 hashes

```
9ff836516d2ce26d62f0adc5605a5c24a7d93e4b3aadced6cad2563636c168be  CBlst.xcframework/macos-arm64_x86_64/libblst.a
0bc9885ea8e167f59424717488bfa4feb19c53cd456c26c9bf5b3e728824e5ef  CBlst.xcframework/ios-arm64/libblst.a
161edfc043661d8efac08059f6157e81dcc8a961bdb4d815e2f2f3e49113c597  CBlst.xcframework/ios-arm64_x86_64-simulator/libblst.a
```

## Verification

```bash
shasum -a 256 \
  CBlst.xcframework/macos-arm64_x86_64/libblst.a \
  CBlst.xcframework/ios-arm64/libblst.a \
  CBlst.xcframework/ios-arm64_x86_64-simulator/libblst.a
```

Expected output matches the hashes above.
