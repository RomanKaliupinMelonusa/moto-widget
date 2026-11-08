import AppIntents
import SwiftUI
import WidgetKit

struct NextTextControl: ControlWidget {
    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: "MotoNextTextControl") {
            ControlWidgetButton(action: NextTextIntent()) {
                Label("Next Text", systemImage: "text.badge.plus")
            }
        }
        .displayName("Next Text")
        .description("Switch to the next saved text.")
    }
}
