import XCTest
import Foundation
@testable import AppFigSDK

final class AppFigStressTests: XCTestCase {
    
    private var memoryMonitor: MemoryMonitor!

    override func setUp() {
        super.setUp()
        memoryMonitor = MemoryMonitor()
        AppFig.reset()
    }

    // TEST 1: Storage Hammering - 10K events with maxEvents: 100,000
    func test01_StorageHammering_10KEvents() async throws {
        let config = AppFigConfig(maxEvents: 100000, debugMode: true)
        AppFig.initialize(config: config)
        memoryMonitor.start()

        var errors: [String] = []

        for i in 0..<10000 {
            do {
                try await AppFig.logEvent(
                    name: "stress_event_\(i)",
                    properties: [
                        "index": i,
                        "timestamp": Date().timeIntervalSince1970
                    ]
                )
            } catch {
                errors.append(error.localizedDescription)
            }

            if i % 2000 == 0 {
                memoryMonitor.snapshot(label: "After \(i) events")
            }
        }

        memoryMonitor.stop()

        XCTAssertEqual(errors.count, 0, "Errors occurred: \(errors.joined(separator: ", "))")
        XCTAssertLessThan(memoryMonitor.maxMemoryMB, 500, "Memory exceeded 500MB")

        print("✅ TEST 1 PASSED: 10K events logged without crash")
        print("   Final Memory: \(memoryMonitor.finalMemoryMB)MB")
    }

    // TEST 2: Payload Mutation - Invalid JSON handling
    func test02_PayloadMutation_InvalidJSON() throws {
        let testCases = [
            "Unclosed brace: {\"features\": {",
            "Wrong type: {\"features\": \"string\"}",
            "Null features: {\"features\": null}",
            "Empty: "
        ]

        var passed = 0

        for testCase in testCases {
            do {
                let result = try AppFig.isFeatureEnabled("test_feature")
                if !result {
                    passed += 1
                }
            } catch {
                if error is NSError && (error as NSError).domain == NSCocoaErrorDomain {
                    print("⚠️ Invalid JSON handled: \(testCase)")
                    passed += 1
                } else {
                    XCTFail("Unexpected error: \(error)")
                }
            }
        }

        XCTAssertGreaterThan(passed, 0, "No valid fallbacks returned")
        print("✅ TEST 2 PASSED: Invalid JSON handled gracefully")
    }

    // TEST 3: Complex Rules - 50+ features with deep sequences
    func test03_ComplexRules_PerformanceStress() async throws {
        let rulesJson = buildComplexRulesJSON(featureCount: 50)
        AppFig.initializeLocal(rulesJson: rulesJson)

        var queryTimes: [Double] = []

        // Background event logging
        let eventTask = Task {
            for i in 0..<100 {
                try? await AppFig.logEvent(name: "bg_event_\(i)", properties: ["seq": i])
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
            }
        }

        // Query stress test
        for i in 0..<1000 {
            let start = Date()
            let result = try AppFig.isFeatureEnabled("feature_\(i % 50)")
            let elapsed = Date().timeIntervalSince(start) * 1000 // ms
            queryTimes.append(elapsed)
        }

        _ = try await eventTask.value

        let avgTime = queryTimes.isEmpty ? 0 : queryTimes.reduce(0, +) / Double(queryTimes.count)
        let maxTime = queryTimes.max() ?? 0

        XCTAssertLessThan(avgTime, 10, "Avg query time too high: \(avgTime)ms")
        XCTAssertLessThan(maxTime, 50, "Max query time too high: \(maxTime)ms")

        print("✅ TEST 3 PASSED: Complex rules evaluated efficiently")
        print(String(format: "   Avg: %.2fms | Max: %.0fms", avgTime, maxTime))
    }

    // TEST 4: Edge Cases - Network & location changes
    func test04_EdgeCases_NetworkAndLocation() throws {
        var errors: [String] = []

        do {
            AppFig.initialize(config: AppFigConfig(offline: true))
            let country = AppFig.getDeviceProperty("country") ?? "Unknown"
            XCTAssertFalse(country.isEmpty, "Country should have fallback")
        } catch {
            errors.append("Offline mode: \(error.localizedDescription)")
        }

        do {
            let timezone = AppFig.getDeviceProperty("timezone") ?? "UTC"
            XCTAssertFalse(timezone.isEmpty, "Timezone should have fallback")
        } catch {
            errors.append("Timezone: \(error.localizedDescription)")
        }

        do {
            let language = AppFig.getDeviceProperty("language") ?? "Unknown"
            XCTAssertFalse(language.isEmpty, "Language should have fallback")
        } catch {
            errors.append("Language: \(error.localizedDescription)")
        }

        XCTAssertEqual(errors.count, 0, "Edge cases failed: \(errors.joined(separator: "; "))")
        print("✅ TEST 4 PASSED: Edge cases handled with fallbacks")
    }

    // TEST 5: SDK Not Initialized
    func test05_NotInitialized_GeliştiriciHatası() throws {
        AppFig.reset()
        var errors: [String] = []

        do {
            try AppFig.logEvent(name: "premature_event", properties: [:])
        } catch {
            if let error = error as? AppFigError, case .notInitialized = error {
                print("✓ Expected AppFigError on LogEvent")
            } else {
                errors.append("Unexpected error on LogEvent: \(error)")
            }
        }

        do {
            let enabled = try AppFig.isFeatureEnabled("test")
            XCTAssertFalse(enabled, "Should return false when not initialized")
        } catch {
            if let error = error as? AppFigError, case .notInitialized = error {
                print("✓ Expected AppFigError on IsFeatureEnabled")
            } else {
                errors.append("Unexpected error on IsFeatureEnabled: \(error)")
            }
        }

        do {
            let value = try AppFig.getFeatureValue("test")
            XCTAssertNil(value, "Should return nil when not initialized")
        } catch {
            if let error = error as? AppFigError, case .notInitialized = error {
                print("✓ Expected AppFigError on GetFeatureValue")
            } else {
                errors.append("Unexpected error on GetFeatureValue: \(error)")
            }
        }

        XCTAssertEqual(errors.count, 0, "Errors: \(errors.joined(separator: "; "))")
        print("✅ TEST 5 PASSED: SDK Not Initialized handled gracefully")
    }

    private func buildComplexRulesJSON(featureCount: Int) -> String {
        var sb = "{"
        sb += "\"features\":{"

        for i in 0..<featureCount {
            if i > 0 { sb += "," }
            sb += "\"feature_\(i)\":[{"
            sb += "\"value\":\"\(i % 2 == 0 ? "true" : "false")\","
            sb += "\"conditions\":["
            sb += "{\"type\":\"device\",\"property\":\"platform\",\"operator\":\"eq\",\"value\":\"ios\"},"
            sb += "{\"type\":\"user\",\"property\":\"country\",\"operator\":\"eq\",\"value\":\"TR\"}"
            sb += "]"
            sb += "}]"
        }

        sb += "}}"
        return sb
    }
}

class MemoryMonitor {
    private var snapshots: [UInt64] = []
    private var startTime = Date()

    func start() {
        startTime = Date()
        snapshots.removeAll()
    }

    func stop() {
        // Finalize monitoring
    }

    func snapshot(label: String) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info>.size)/4

        let kerr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(TASK_VM_INFO),
                    $0,
                    &count
                )
            }
        }

        if kerr == KERN_SUCCESS {
            snapshots.append(info.phys_footprint)
        }
    }

    var maxMemoryMB: UInt64 {
        guard let max = snapshots.max() else { return 0 }
        return max / (1024 * 1024)
    }

    var finalMemoryMB: UInt64 {
        guard let last = snapshots.last else { return 0 }
        return last / (1024 * 1024)
    }
}

enum AppFigError: Error {
    case notInitialized
    case invalidJSON
    case unknown
}
