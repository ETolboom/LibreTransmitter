//
//  GlucoseKalmanFilterTests.swift
//  LibreTransmitterTests
//

import XCTest
@testable import LibreTransmitter

final class GlucoseKalmanFilterTests: XCTestCase {

    func testFirstSampleSeedsLevelWithZeroTrend() {
        let filter = GlucoseKalmanFilter()
        let now = Date()
        let output = filter.update(measurement: 120, at: now)
        XCTAssertEqual(output.level, 120, accuracy: 0.0001)
        XCTAssertEqual(output.trend, 0, accuracy: 0.0001)
    }

    func testRampConvergesTowardsTrueSlopeAndReducesTrackingError() {
        let filter = GlucoseKalmanFilter()
        let start = Date()
        let slope = 2.0 // mg/dL per minute
        let level0 = 100.0

        // Irregular spacing mirroring real BLE trend sample ages.
        let minuteOffsets = [0, 2, 4, 6, 7, 12, 15, 17, 19, 21, 22, 27, 30, 32, 34, 36, 37, 42, 45]

        var earlyError: Double?
        var lastError: Double = .infinity
        for minutes in minuteOffsets {
            let t = start.addingTimeInterval(Double(minutes) * 60)
            let trueValue = level0 + slope * Double(minutes)
            let output = filter.update(measurement: trueValue, at: t)
            let error = abs(output.level - trueValue)
            if earlyError == nil, minutes >= minuteOffsets[3] {
                earlyError = error
            }
            lastError = error
        }

        guard let earlyError else {
            XCTFail("expected to have recorded an early error sample")
            return
        }

        // Tracking error should shrink (or stay small) as the filter converges,
        // rather than growing or staying persistently large.
        XCTAssertLessThanOrEqual(lastError, earlyError + 1.0)

        let finalOutput = filter.update(measurement: level0 + slope * 45, at: start.addingTimeInterval(45 * 60))
        XCTAssertEqual(finalOutput.trend, slope, accuracy: 1.0)
    }

    func testNoisyPlateauOutputVarianceIsReducedVsRawInput() {
        let filter = GlucoseKalmanFilter()
        let start = Date()
        let trueValue = 140.0

        // Fixed-seed deterministic pseudo-noise so the test is reproducible.
        var generator = SplitMix64(seed: 42)
        let noisySamples: [Double] = (0 ..< 40).map { _ in
            trueValue + Double.random(in: -15 ... 15, using: &generator)
        }

        var outputs: [Double] = []
        for (i, sample) in noisySamples.enumerated() {
            let t = start.addingTimeInterval(Double(i) * 60)
            outputs.append(filter.update(measurement: sample, at: t).level)
        }

        // Discard the initial transient (filter still converging from its seed).
        let warmedUpOutputs = Array(outputs.dropFirst(10))
        let warmedUpInputs = Array(noisySamples.dropFirst(10))

        XCTAssertLessThan(stddev(warmedUpOutputs), stddev(warmedUpInputs))
    }

    func testDuplicateTimestampIsANoOp() {
        let filter = GlucoseKalmanFilter()
        let start = Date()
        filter.update(measurement: 100, at: start)
        let first = filter.update(measurement: 150, at: start.addingTimeInterval(60))

        // Re-delivering the same (measurement, timestamp) -- as the BLE path's
        // bufferedTrends re-merge can do across calls -- must not change state.
        let second = filter.update(measurement: 150, at: start.addingTimeInterval(60))
        XCTAssertEqual(first.level, second.level, accuracy: 0.0001)
        XCTAssertEqual(first.trend, second.trend, accuracy: 0.0001)

        // A near-duplicate timestamp (within minDtMinutes) should likewise be ignored.
        let third = filter.update(measurement: 500, at: start.addingTimeInterval(60 + 5))
        XCTAssertEqual(first.level, third.level, accuracy: 0.0001)
    }

    func testResetProducesFreshFilterBehavior() {
        let filter = GlucoseKalmanFilter()
        let start = Date()
        filter.update(measurement: 90, at: start)
        filter.update(measurement: 200, at: start.addingTimeInterval(120))

        filter.reset()

        let fresh = GlucoseKalmanFilter()
        let afterReset = filter.update(measurement: 130, at: start.addingTimeInterval(600))
        let freshOutput = fresh.update(measurement: 130, at: start.addingTimeInterval(600))

        XCTAssertEqual(afterReset.level, freshOutput.level, accuracy: 0.0001)
        XCTAssertEqual(afterReset.trend, freshOutput.trend, accuracy: 0.0001)
    }

    func testLargeGapIsClampedRatherThanExtrapolated() {
        let start = Date()

        let filterA = GlucoseKalmanFilter()
        filterA.update(measurement: 100, at: start)
        let outputA = filterA.update(measurement: 120, at: start.addingTimeInterval(20 * 60))

        let filterB = GlucoseKalmanFilter()
        filterB.update(measurement: 100, at: start)
        // A much larger gap should be clamped to the same effective dt as a 20-minute
        // gap, producing an identical result rather than extrapolating further.
        let outputB = filterB.update(measurement: 120, at: start.addingTimeInterval(90 * 60))

        XCTAssertEqual(outputA.level, outputB.level, accuracy: 0.0001)
        XCTAssertEqual(outputA.trend, outputB.trend, accuracy: 0.0001)
    }
}

private func stddev(_ values: [Double]) -> Double {
    guard values.count > 1 else { return 0 }
    let mean = values.reduce(0, +) / Double(values.count)
    let variance = values.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(values.count - 1)
    return variance.squareRoot()
}

/// Minimal deterministic RNG so noise-based tests are reproducible across runs.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { self.state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
