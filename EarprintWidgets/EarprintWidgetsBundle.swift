import SwiftUI
import WidgetKit

@main
struct EarprintWidgetsBundle: WidgetBundle {
    var body: some Widget {
        TodayWidget()
        CardShelfWidget()
        EarprintRingWidget()
        BudgetWidget()
        ListeningLiveActivity()
    }
}
