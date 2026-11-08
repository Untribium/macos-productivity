# Overlay: can work-new build and run a native Swift app?

- **Date:** 2026-11-08
- **Question:** does a locally built Swift/AppKit binary build and run here, and what policy (Gatekeeper, Santa, MDM) applies?
- **Machine / keyboard:** work-new (Mac17,9), macOS 26.7.2, arm64

## Command

```sh
overlay/probes/env-check.sh work-new
```

## Output

```
== system
$ sw_vers
ProductName:		macOS
ProductVersion:		26.7.2
BuildVersion:		25G332
[exit 0]

$ uname -m
arm64
[exit 0]

$ sysctl -n hw.model
Mac17,9
[exit 0]

== toolchain
$ xcode-select -p
/Library/Developer/CommandLineTools
[exit 0]

$ pkgutil --pkg-info=com.apple.pkg.CLTools_Executables
package-id: com.apple.pkg.CLTools_Executables
version: 26.6.0.0.1781586589
volume: /
location: /
install-time: 1794135504
[exit 0]

$ ls /Library/Developer/CommandLineTools/SDKs
MacOSX.sdk
MacOSX15.4.sdk
MacOSX15.sdk
MacOSX26.5.sdk
MacOSX26.sdk
[exit 0]

$ swift --version
swift-driver version: 1.148.6 Apple Swift version 6.3.3 (swiftlang-6.3.3.1.3 clang-2100.1.1.101)
Target: arm64-apple-macosx26.0
[exit 0]

$ xcrun --show-sdk-version
26.5
[exit 0]

== policy
$ spctl --status
assessments enabled
[exit 0]

santactl: not installed

$ profiles status -type enrollment
Enrolled via DEP: Yes
MDM enrollment: Yes (User Approved)
MDM server: https://i.manage.microsoft.com/DeviceGatewayProxy/ioshandler.ashx?Platform=MacMDM
[exit 0]

== hammerspoon
$ defaults read /Applications/Hammerspoon.app/Contents/Info.plist CFBundleShortVersionString
1.1.1
[exit 0]

== swift build smoke test
$ swift build --package-path /var/folders/bs/y04dw29n2b51kb1vgc65rvlc0000gp/T/tmp.hIaexGruug -c release
Building for production...
[0/4] Write sources
[1/4] Write swift-version--1AB21518FC5DEDBE.txt
[3/5] Compiling smoke main.swift
[3/5] Write Objects.LinkFileList
[4/5] Linking smoke
Build complete! (25.17s)
[exit 0]

$ codesign -dv /var/folders/bs/y04dw29n2b51kb1vgc65rvlc0000gp/T/tmp.hIaexGruug/.build/release/smoke
Executable=/private/var/folders/bs/y04dw29n2b51kb1vgc65rvlc0000gp/T/tmp.hIaexGruug/.build/arm64-apple-macosx/release/smoke
Identifier=smoke
Format=Mach-O thin (arm64)
CodeDirectory v=20400 size=542 flags=0x20002(adhoc,linker-signed) hashes=14+0 location=embedded
Signature=adhoc
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
Internal requirements=none
[exit 0]

$ /var/folders/bs/y04dw29n2b51kb1vgc65rvlc0000gp/T/tmp.hIaexGruug/.build/release/smoke
smoke ok, AppKit loaded: true
[exit 0]
```

## Conclusion

*(to fill in)*
