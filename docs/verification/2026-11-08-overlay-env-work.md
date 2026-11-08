# Overlay: can the work machine build and run a native Swift app?

- **Date:** 2026-11-08
- **Question:** does a locally built Swift/AppKit binary build and run here, and what policy (Gatekeeper, Santa, MDM) applies?
- **Machine / keyboard:** work machine, macOS 26.7.1, arm64

## Command

```sh
overlay/probes/env-check.sh
```

## Output

```
== system
$ sw_vers
ProductName:		macOS
ProductVersion:		26.7.1
BuildVersion:		25G241
[exit 0]

$ uname -m
arm64
[exit 0]

== toolchain
$ xcode-select -p
/Library/Developer/CommandLineTools
[exit 0]

$ pkgutil --pkg-info=com.apple.pkg.CLTools_Executables
package-id: com.apple.pkg.CLTools_Executables
version: 26.3.0.0.1.1771626560
volume: /
location: /
install-time: 1773317501
[exit 0]

$ ls /Library/Developer/CommandLineTools/SDKs
MacOSX.sdk
MacOSX15.4.sdk
MacOSX15.sdk
MacOSX26.2.sdk
MacOSX26.sdk
[exit 0]

$ swift --version
swift-driver version: 1.127.15 Apple Swift version 6.2.4 (swiftlang-6.2.4.1.4 clang-1700.6.4.2)
Target: arm64-apple-macosx26.0
[exit 0]

$ xcrun --show-sdk-version
26.2
[exit 0]

== policy
$ spctl --status
assessments enabled
[exit 0]

santactl: not installed

$ profiles status -type enrollment
Enrolled via DEP: Yes
MDM enrollment: Yes (User Approved)
MDM server: https://casper-jss.accenture.com/mdm/ServerURL
[exit 0]

== hammerspoon
$ defaults read /Applications/Hammerspoon.app/Contents/Info.plist CFBundleShortVersionString
1.1.1
[exit 0]

== swift build smoke test
$ swift build --package-path /var/folders/d4/bx8scqcx2ggcq703cjrh32t40000gn/T/tmp.7S3PsU5Ho3 -c release
Building for production...
[0/4] Write sources
[1/4] Write swift-version--1AB21518FC5DEDBE.txt
[3/5] Compiling smoke main.swift
[3/5] Write Objects.LinkFileList
[4/5] Linking smoke
Build complete! (59.59s)
[exit 0]

$ codesign -dv /var/folders/d4/bx8scqcx2ggcq703cjrh32t40000gn/T/tmp.7S3PsU5Ho3/.build/release/smoke
Executable=/private/var/folders/d4/bx8scqcx2ggcq703cjrh32t40000gn/T/tmp.7S3PsU5Ho3/.build/arm64-apple-macosx/release/smoke
Identifier=smoke
Format=Mach-O thin (arm64)
CodeDirectory v=20400 size=510 flags=0x20002(adhoc,linker-signed) hashes=13+0 location=embedded
Signature=adhoc
Info.plist=not bound
TeamIdentifier=not set
Sealed Resources=none
Internal requirements=none
[exit 0]

$ /var/folders/d4/bx8scqcx2ggcq703cjrh32t40000gn/T/tmp.7S3PsU5Ho3/.build/release/smoke
smoke ok, AppKit loaded: true
[exit 0]
```

## Conclusion

**Building and running locally works.** A plain `swift build` binary (ad-hoc,
linker-signed, no quarantine) runs and loads AppKit. No Santa, so there is no
binary allowlisting.

- **Toolchain:** CLT 26.3, Swift 6.2.4, SDK 26.2. This is the floor the overlay
  code must compile against: no APIs newer than the 26.2 SDK, Swift 6.2
  language features at most. Deployment target macOS 26.
- **Policy:** Gatekeeper on (`assessments enabled`), which only matters for
  quarantined downloads, so build on the machine rather than copying an app in.
  Enrolled in Jamf MDM (DEP, user approved). Jamf can block apps by name or
  bundle id and can manage login items and privacy grants; none of that shows
  from here.

Still open, for the spike itself: launching a `.app` bundle (not a bare
binary), the global hotkey (including while Citrix Viewer has focus), the
non-activating panel and focus return, registering as a login item, and the
URL scheme from Hammerspoon.
