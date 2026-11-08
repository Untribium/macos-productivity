import Carbon.HIToolbox

/// A system-wide hotkey via Carbon's RegisterEventHotKey. Unlike an event tap,
/// it needs no Accessibility or Input Monitoring permission.
///
/// Carbon cannot take fn as a modifier, so caps-layer bindings reach this
/// through Hammerspoon's fn layer re-emitting them on hyper (SETUP.md §4).
public final class HotKey {
  public static let hyper = UInt32(controlKey | optionKey | cmdKey | shiftKey)

  private static let signature: OSType = 0x4F56_4C59  // 'OVLY'
  private static var registered: [UInt32: HotKey] = [:]
  private static var nextID: UInt32 = 1
  private static var handlerInstalled = false

  private let handler: () -> Void
  private var ref: EventHotKeyRef?

  /// `keyCode` is a virtual keycode (kVK_*), `modifiers` Carbon flags.
  /// Returns nil if the combination is already taken system-wide.
  public init?(keyCode: Int, modifiers: UInt32, handler: @escaping () -> Void) {
    self.handler = handler
    Self.installHandler()

    let id = Self.nextID
    Self.nextID += 1
    let status = RegisterEventHotKey(
      UInt32(keyCode), modifiers, EventHotKeyID(signature: Self.signature, id: id),
      GetApplicationEventTarget(), 0, &ref)
    guard status == noErr else { return nil }
    Self.registered[id] = self
  }

  public func unregister() {
    guard let ref else { return }
    UnregisterEventHotKey(ref)
    self.ref = nil
    Self.registered = Self.registered.filter { $0.value !== self }
  }

  private static func installHandler() {
    guard !handlerInstalled else { return }
    handlerInstalled = true
    var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
    InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
      var hk = EventHotKeyID()
      GetEventParameter(
        event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID),
        nil, MemoryLayout<EventHotKeyID>.size, nil, &hk)
      // Carbon delivers on the main thread.
      MainActor.assumeIsolated { HotKey.registered[hk.id]?.handler() }
      return noErr
    }, 1, &spec, nil, nil)
  }
}
