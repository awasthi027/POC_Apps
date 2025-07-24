


import SwiftUI

public struct AutomationLoggerView: View {

    @ObservedObject var logger = LoggingViewModel.shared
    public init(logger: LoggingViewModel = LoggingViewModel.shared) {
        self.logger = logger
    }

    public var body: some View {
#if AutomationSupports
        Text(logger.logMessages)
            .frame(width: 1, height: 1) // Minimal visible space
            .accessibilityIdentifier(logger.accessibilityIdentifier)
            .foregroundColor(.clear)
#endif

    }
}
