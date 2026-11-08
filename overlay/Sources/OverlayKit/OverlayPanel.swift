import AppKit

/// A Spotlight-style panel. It floats above everything, full-screen apps
/// included, and takes the keyboard without activating this app: the app you
/// were in stays frontmost, menu bar and all. It hides on Escape and when it
/// loses key status, e.g. on a click elsewhere.
public final class OverlayPanel: NSPanel {
  public var onShow: (() -> Void)?
  public var onHide: (() -> Void)?

  private var hiding = false
  private let glass = NSGlassEffectView()

  /// .regular is frosted (Spotlight), .clear lets far more of the background
  /// through, at a cost in text contrast.
  public var glassStyle: NSGlassEffectView.Style {
    get { glass.style }
    set { glass.style = newValue }
  }

  public init(content: NSView, size: NSSize, cornerRadius: CGFloat = 24) {
    super.init(
      contentRect: NSRect(origin: .zero, size: size),
      styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
      backing: .buffered, defer: true)
    isFloatingPanel = true
    level = .floating
    collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
    hidesOnDeactivate = false  // this app is never active, so this would never fire anyway
    isMovable = false
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true

    // Real blur of what is behind the panel, without Screen Recording.
    glass.cornerRadius = cornerRadius
    glass.contentView = content
    contentView = glass
  }

  override public var canBecomeKey: Bool { true }
  override public var canBecomeMain: Bool { false }

  public func toggle() { isVisible ? hide() : show() }

  /// Centred horizontally on the screen with the mouse, upper third, like Spotlight.
  public func show() {
    let mouse = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
    if let f = screen?.visibleFrame {
      setFrameOrigin(NSPoint(x: f.midX - frame.width / 2, y: f.minY + f.height * 0.70 - frame.height / 2))
    }
    onShow?()
    makeKeyAndOrderFront(nil)
  }

  public func hide() {
    guard isVisible, !hiding else { return }
    hiding = true
    orderOut(nil)  // calls resignKey, hence the guard
    hiding = false
    onHide?()
  }

  override public func resignKey() {
    super.resignKey()
    hide()
  }

  override public func cancelOperation(_ sender: Any?) { hide() }
}
