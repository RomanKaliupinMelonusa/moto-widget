import SwiftUI
import WidgetKit

@main
struct MotoWidgetBundle: WidgetBundle {
    var body: some Widget {
        MotoTextWidget()
        MotoTextLeftWidget()
        MotoTextRightWidget()
        NextTextControl()
    }
}
