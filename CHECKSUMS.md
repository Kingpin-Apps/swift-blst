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
9aeac0b3c84d930eb9e89cfe33cf1d91dc3c26dcf800887176ad7578364c6391  CBlst.xcframework/ios-arm64/libblst.a
92466ea074029f6ee26e76adf0bd04dba7bfe36ce10b0caa439a771ac2d3e737  CBlst.xcframework/ios-arm64_x86_64-simulator/libblst.a
5788909668f97095a08c67e815c5bde99d7e6747fab87d18baee4a1a57f9ccd1  CBlst.xcframework/macos-arm64_x86_64/libblst.a
93eed0af0361cad4b7af750508f38f00c8ce915ee10e8583fa5a6c1bd2a4168d  CBlst.xcframework/tvos-arm64/libblst.a
996417a65b0cbf560f990f273a9ff4ca2b46e8d76b1017b15cf040eb9d809436  CBlst.xcframework/tvos-arm64_x86_64-simulator/libblst.a
d7d71b3e47e8eddeffb96dca01c616b62bce73ce45c3f3590b60f5f69200f42d  CBlst.xcframework/watchos-arm64_arm64_32/libblst.a
6f2f5f7348bbb7e89ec1e2c5a50632bfb672c15b3a5fea71c55731a5477a2c6a  CBlst.xcframework/watchos-arm64_x86_64-simulator/libblst.a
373bdd64cda7ee50dde5d5c9d0fb16756b6c0471a2a910f25046b081caa3e9e7  CBlst.xcframework/xros-arm64/libblst.a
c4a1877fb6130c73f7082e067046e7fc8279c2141e77bf39133bb70bd6d8ee6f  CBlst.xcframework/xros-arm64-simulator/libblst.a
```

## Verification

```bash
find CBlst.xcframework -name 'libblst.a' | sort | xargs shasum -a 256
```

Expected output matches the hashes above.
