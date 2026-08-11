//
//  PreLibre2TimestampTests.swift
//  LibreTransmitterTests
//

import XCTest
@testable import LibreTransmitter

final class PreLibre2TimestampTests: XCTestCase {

    // Mirrors the private constants in Libre2.parseBLEData.
    private let ints = [0, 2, 4, 6, 7, 12, 15]
    private let delay = 2

    func testTrendBranchYieldsTrueMinuteAges() {
        let age = 1000
        let now = Date()

        var previousTimestamp: Date?
        for i in 0 ..< 7 {
            let idValue = age - ints[i]
            let minutesAgo = age - idValue
            XCTAssertEqual(minutesAgo, ints[i], "trend sample \(i) should be \(ints[i]) minutes ago")

            let timestamp = Libre2.computeTimestamp(age: age, idValue: idValue, now: now)
            let expected = now.addingTimeInterval(Double(-60 * ints[i]))
            XCTAssertEqual(timestamp.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.001)

            if let previousTimestamp {
                XCTAssertLessThan(timestamp, previousTimestamp, "later trend index should be an older (earlier) timestamp")
            }
            previousTimestamp = timestamp
        }
    }

    func testHistoryBranchYieldsMinutesAgoWithinExpectedSlotRange() {
        let now = Date()

        // Exercise a few different (age - delay) mod 15 remainders, including the
        // boundary cases (remainder 0 and remainder 14).
        for age in [100, 107, 114, 121, 999, 1000, 1001, 2000] {
            for i in 7 ..< 10 {
                let idValue = ((age - delay) / 15) * 15 - 15 * (i - 7)
                let minutesAgo = age - idValue

                let lowerBound = 15 * (i - 7) + delay
                let upperBound = lowerBound + 14
                XCTAssertTrue(
                    (lowerBound ... upperBound).contains(minutesAgo),
                    "age=\(age) i=\(i): minutesAgo=\(minutesAgo) expected in \(lowerBound)...\(upperBound)"
                )

                let timestamp = Libre2.computeTimestamp(age: age, idValue: idValue, now: now)
                let expected = now.addingTimeInterval(Double(-60 * minutesAgo))
                XCTAssertEqual(timestamp.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 0.001)
            }
        }
    }

    func testMostRecentTrendSampleIsApproximatelyNow() {
        let age = 500
        let now = Date()
        let idValue = age - ints[0] // ints[0] == 0
        let timestamp = Libre2.computeTimestamp(age: age, idValue: idValue, now: now)
        XCTAssertEqual(timestamp.timeIntervalSince1970, now.timeIntervalSince1970, accuracy: 0.001)
    }
}
