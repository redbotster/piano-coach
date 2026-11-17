import SwiftUI

struct ProgressDashboard: View {
    @EnvironmentObject var app: AppModel
    var body: some View { Text("Progress").frame(maxWidth: .infinity, maxHeight: .infinity) }
}
