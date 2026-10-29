import AppKit
import SwiftUI

/// Article routes replace their views. Keep shortcuts on the window so they
/// still work while SwiftUI moves focus away from the outgoing article.
struct ArticleKeyboardShortcuts: NSViewRepresentable {
    let model: ReadAppModel

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak view] event in
            guard let window = view?.window,
                  event.window === window,
                  window.isKeyWindow,
                  window.attachedSheet == nil,
                  !model.isShowingSettings,
                  !model.isLockedByInactivity,
                  !(model.isRefreshing && !model.hasSkippedRefreshScreen),
                  event.modifierFlags.intersection([.command, .control, .option, .shift]).isEmpty,
                  case .story(let id) = model.path.last,
                  let story = model.story(withID: id) else {
                return event
            }
            if let textView = window.firstResponder as? NSTextView, textView.isEditable {
                return event
            }

            switch event.characters {
            case "j": model.showAdjacentStory(from: story, offset: 1)
            case "k": model.showAdjacentStory(from: story, offset: -1)
            case "x": model.toggleRating(story)
            case "r": model.toggleRead(story)
            case "\u{1B}", "\u{8}", "\u{7F}": model.goBack()
            default: return event
            }
            return nil
        }
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    static func dismantleNSView(_ view: NSView, coordinator: Coordinator) {
        if let monitor = coordinator.monitor {
            NSEvent.removeMonitor(monitor)
            coordinator.monitor = nil
        }
    }

    final class Coordinator {
        var monitor: Any?
    }
}
