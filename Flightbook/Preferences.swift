import Foundation

enum Preferences {
    static let testSuite = "com.baiweicheng.flightbook.uat-preferences"
    static var defaults: UserDefaults {
        ProcessInfo.processInfo.arguments.contains("-uitesting") ? UserDefaults(suiteName: testSuite)! : .standard
    }
    static func prepareTestSession() {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-uitesting") && args.contains("-reset-test-data") {
            defaults.removePersistentDomain(forName: testSuite)
        }
    }
}
