// OverlaySpike — a running-apps launcher on OverlayKit. Exists to test, on
// each machine: the hotkey (also under Citrix), the non-activating panel and
// focus return, the URL scheme, and registering as a login item.
//
//   hyper+Return (caps+Return via the fn layer)  toggle
//   open -g overlay-spike://toggle               toggle (also: show, hide)
//
// Logs go to the unified log: log stream --predicate 'subsystem == "overlay-spike"'

import AppKit
import Carbon.HIToolbox
import OverlayKit
import ServiceManagement
import SwiftUI
import os

let log = Logger(subsystem: "overlay-spike", category: "app")

final class AppDelegate: NSObject, NSApplicationDelegate {
  private let model = ChooserModel()
  private var panel: OverlayPanel!
  private var hotKey: HotKey?
  private var statusItem: NSStatusItem!

  func applicationDidFinishLaunching(_ note: Notification) {
    let view = ChooserView(
      model: model,
      onChoose: { [weak self] in self?.launch($0) },
      onCancel: { [weak self] in self?.panel.hide() })
    panel = OverlayPanel(content: NSHostingView(rootView: view), size: NSSize(width: 640, height: 380))
    panel.onShow = { [weak self] in
      log.info("show; frontmost: \(Self.frontmost(), privacy: .public)")
      self?.model.reset(items: Self.runningApps())
    }
    panel.onHide = {
      // Focus return check: this should still name the app you were in.
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
        log.info("hidden; frontmost: \(Self.frontmost(), privacy: .public)")
      }
    }

    hotKey = HotKey(keyCode: kVK_Return, modifiers: HotKey.hyper) { [weak self] in
      log.info("hotkey")
      self?.panel.toggle()
    }
    if hotKey == nil { log.error("hyper+Return is taken; hotkey not registered") }

    setUpStatusItem()
    log.info("launched; hotkey \(self.hotKey == nil ? "FAILED" : "ok", privacy: .public)")
  }

  // overlay-spike://toggle | show | hide
  func application(_ app: NSApplication, open urls: [URL]) {
    for url in urls {
      log.info("url \(url.absoluteString, privacy: .public)")
      switch url.host {
      case "show": panel.show()
      case "hide": panel.hide()
      default: panel.toggle()
      }
    }
  }

  // MARK: - Launcher

  private static func runningApps() -> [ChooserItem] {
    NSWorkspace.shared.runningApplications
      .filter { $0.activationPolicy == .regular }
      .compactMap { app in
        guard let name = app.localizedName, let url = app.bundleURL else { return nil }
        return ChooserItem(id: url.path, title: name, subtitle: app.bundleIdentifier)
      }
      .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
  }

  private func launch(_ item: ChooserItem) {
    panel.hide()
    // openApplication rather than NSRunningApplication.activate: under
    // cooperative activation an app that is not active itself cannot hand
    // activation to another.
    let config = NSWorkspace.OpenConfiguration()
    config.activates = true
    NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: item.id), configuration: config) { _, error in
      if let error { log.error("open \(item.title, privacy: .public): \(error.localizedDescription, privacy: .public)") }
    }
  }

  private static func frontmost() -> String {
    NSWorkspace.shared.frontmostApplication?.localizedName ?? "none"
  }

  // MARK: - Menu bar: the only way to quit an accessory app

  private func setUpStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    statusItem.button?.image = NSImage(systemSymbolName: "rectangle.and.text.magnifyingglass", accessibilityDescription: "Overlay")
    statusItem.menu = makeMenu()
  }

  private func makeMenu() -> NSMenu {
    let menu = NSMenu()
    menu.addItem(withTitle: "Show Overlay", action: #selector(showPanel), keyEquivalent: "").target = self
    menu.addItem(.separator())

    let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
    login.target = self
    let status = SMAppService.mainApp.status
    login.state = status == .enabled ? .on : .off
    menu.addItem(login)
    menu.addItem(withTitle: "Login item: \(Self.describe(status))", action: nil, keyEquivalent: "")
    menu.addItem(withTitle: "Hotkey: \(hotKey == nil ? "not registered" : "hyper+Return")", action: nil, keyEquivalent: "")

    menu.addItem(.separator())
    menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    return menu
  }

  @objc private func showPanel() { panel.show() }

  @objc private func toggleLogin() {
    let service = SMAppService.mainApp
    do {
      if service.status == .enabled {
        try service.unregister()
      } else {
        try service.register()
      }
    } catch {
      log.error("login item: \(error.localizedDescription, privacy: .public)")
    }
    log.info("login item now \(Self.describe(service.status), privacy: .public)")
    statusItem.menu = makeMenu()
  }

  private static func describe(_ s: SMAppService.Status) -> String {
    switch s {
    case .enabled: "enabled"
    case .notRegistered: "not registered"
    case .requiresApproval: "requires approval (Settings → General → Login Items)"
    case .notFound: "not found"
    @unknown default: "unknown"
    }
  }
}

let delegate = AppDelegate()
NSApplication.shared.delegate = delegate
NSApplication.shared.setActivationPolicy(.accessory)
NSApplication.shared.run()
