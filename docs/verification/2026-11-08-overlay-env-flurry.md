# Overlay: can flurry build and run a native Swift app?

- **Date:** 2026-11-08
- **Question:** does a locally built Swift/AppKit binary build and run here, and what policy (Gatekeeper, Santa, MDM) applies?
- **Machine / keyboard:** flurry (Mac14,9), macOS 27.0.1, arm64

## Command

```sh
overlay/probes/env-check.sh
```

## Output

```
== system
$ sw_vers
ProductName:		macOS
ProductVersion:		27.0.1
BuildVersion:		26A434
[exit 0]

$ uname -m
arm64
[exit 0]

$ sysctl -n hw.model
Mac14,9
[exit 0]

== toolchain
$ xcode-select -p
/Library/Developer/CommandLineTools
[exit 0]

$ pkgutil --pkg-info=com.apple.pkg.CLTools_Executables
package-id: com.apple.pkg.CLTools_Executables
version: 27.2.0.0.1792721180
volume: /
location: /
install-time: 1794135370
[exit 0]

$ ls /Library/Developer/CommandLineTools/SDKs
MacOSX.sdk
MacOSX26.5.sdk
MacOSX26.sdk
MacOSX27.2.sdk
MacOSX27.sdk
[exit 0]

$ swift --version
swift-driver version: 1.168.6 Apple Swift version 6.4.2 (swiftlang-6.4.2.1.9 clang-2100.4.1.1)
Target: arm64-apple-macosx27.0.0
[exit 0]

$ xcrun --show-sdk-version
27.2
[exit 0]

== policy
$ spctl --status
assessments enabled
[exit 0]

santactl: not installed

$ profiles status -type enrollment
Enrolled via DEP: No
MDM enrollment: No
[exit 0]

== hammerspoon
$ defaults read /Applications/Hammerspoon.app/Contents/Info.plist CFBundleShortVersionString
1.1.1
[exit 0]

== swift build smoke test
$ swift build --package-path /var/folders/cr/xmdzg3qj6tbf2rd0kqc2t28c0000gn/T/tmp.9YutRO4phM -c release
Building for production...
[Planning deferred tasks]
[16 / 21]
[17 / 22] smoke-product
[28 / 123]
[32 / 123]
[40 / 123]
[42 / 123]
[43 / 123]
[49 / 123]
[51 / 123]
[54 / 123]
[59 / 123]
[62 / 123]
[64 / 123]
[65 / 123]
[76 / 123]
[79 / 123]
[81 / 123]
[87 / 123]
[88 / 123]
[94 / 123]
[95 / 123]
[98 / 123]
[100 / 123]
[108 / 123]
[109 / 123]
[113 / 123]
[117 / 123]
[118 / 123]
[119 / 123] smoke-product
/private/var/folders/cr/xmdzg3qj6tbf2rd0kqc2t28c0000gn/T/tmp.9YutRO4phM/Package.swift: smoke-product: ld: warning: search path '/Library/Developer/CommandLineTools/Developer/usr/lib' not found
/private/var/folders/cr/xmdzg3qj6tbf2rd0kqc2t28c0000gn/T/tmp.9YutRO4phM/Package.swift: smoke-product: ld: warning: search path '/Library/Developer/CommandLineTools/Developer/Library/Frameworks' not found
[121 / 123] smoke-product
[122 / 123] smoke-product
Build complete! (24.23 sec)
[exit 0]

$ codesign -dv /var/folders/cr/xmdzg3qj6tbf2rd0kqc2t28c0000gn/T/tmp.9YutRO4phM/.build/release/smoke
Executable=/private/var/folders/cr/xmdzg3qj6tbf2rd0kqc2t28c0000gn/T/tmp.9YutRO4phM/.build/out/Products/Release/smoke
Identifier=smoke
Format=Mach-O thin (arm64)
CodeDirectory v=20400 size=542 flags=0x20002(adhoc,linker-signed) hashes=14+0 location=embedded
Signature=adhoc
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
Internal requirements=none
[exit 0]

$ /var/folders/cr/xmdzg3qj6tbf2rd0kqc2t28c0000gn/T/tmp.9YutRO4phM/.build/release/smoke
smoke ok, AppKit loaded: true
[exit 0]
```

## Conclusion

Home dev machine after the CLT 27.2 upgrade: Swift 6.4.2, SDK 27.2 (also ships
26.5). Builds and runs; no MDM, no Santa.

It is ahead of the work machine (Swift 6.2.4, SDK 26.2; see
`2026-11-08-overlay-env-work-old.md`), so compiling here proves nothing about
there. The overlay package pins Swift 6.2 language mode and a macOS 26
deployment target, and must avoid APIs newer than the 26.2 SDK.
