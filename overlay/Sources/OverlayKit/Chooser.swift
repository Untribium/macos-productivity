import SwiftUI

// Plain data: opt out of the package's default main-actor isolation.
nonisolated public struct ChooserItem: Identifiable, Sendable {
  public let id: String
  public let title: String
  public let subtitle: String?

  public init(id: String, title: String, subtitle: String? = nil) {
    self.id = id
    self.title = title
    self.subtitle = subtitle
  }
}

/// State for a ChooserView. Owned by the app so it can be reset on every show.
@Observable
public final class ChooserModel {
  public var items: [ChooserItem] = []
  var query = ""
  var selected = 0
  var showCount = 0  // bumped on every show; the view refocuses the field on change

  public init() {}

  var filtered: [ChooserItem] {
    query.isEmpty ? items : items.filter { $0.title.localizedCaseInsensitiveContains(query) }
  }

  /// Call when the panel is about to show.
  public func reset(items: [ChooserItem]) {
    self.items = items
    query = ""
    selected = 0
    showCount += 1
  }

  func move(_ delta: Int) {
    let n = filtered.count
    guard n > 0 else { return }
    selected = (selected + delta + n) % n
  }
}

/// A search field over a filtered list: type to filter, arrows or ctrl+n/p to
/// move, Return to choose, Escape to cancel.
public struct ChooserView: View {
  @Bindable var model: ChooserModel
  let onChoose: (ChooserItem) -> Void
  let onCancel: () -> Void
  @FocusState private var focused: Bool

  public init(model: ChooserModel, onChoose: @escaping (ChooserItem) -> Void, onCancel: @escaping () -> Void) {
    self.model = model
    self.onChoose = onChoose
    self.onCancel = onCancel
  }

  public var body: some View {
    VStack(spacing: 0) {
      TextField("Search", text: $model.query)
        .textFieldStyle(.plain)
        .font(.system(size: 22, weight: .regular))
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .focused($focused)
        .onKeyPress(.downArrow) { model.move(1); return .handled }
        .onKeyPress(.upArrow) { model.move(-1); return .handled }
        .onKeyPress(keys: ["n", "p"]) { press in
          guard press.modifiers == .control else { return .ignored }
          model.move(press.key == "n" ? 1 : -1)
          return .handled
        }
        .onSubmit(choose)
        .onExitCommand(perform: onCancel)
        .onChange(of: model.query) { model.selected = 0 }

      Divider().opacity(0.5)

      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 2) {
            ForEach(Array(model.filtered.enumerated()), id: \.element.id) { i, item in
              row(item, isSelected: i == model.selected)
                .id(item.id)
                .contentShape(Rectangle())
                .onTapGesture {
                  model.selected = i
                  choose()
                }
            }
          }
          .padding(8)
        }
        .onChange(of: model.selected) {
          let items = model.filtered
          if items.indices.contains(model.selected) { proxy.scrollTo(items[model.selected].id) }
        }
      }
    }
    .onAppear { focused = true }
    .onChange(of: model.showCount) { focused = true }
  }

  private func row(_ item: ChooserItem, isSelected: Bool) -> some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(item.title).font(.system(size: 15, weight: .medium))
      if let sub = item.subtitle {
        Text(sub).font(.system(size: 11)).opacity(0.7)
      }
    }
    .foregroundStyle(isSelected ? Color.white : Color.primary)
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 10).fill(isSelected ? Color.accentColor : Color.clear))
  }

  private func choose() {
    let items = model.filtered
    guard items.indices.contains(model.selected) else { return }
    onChoose(items[model.selected])
  }
}
