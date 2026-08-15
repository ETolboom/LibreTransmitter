//
//  GlucoseSmoothingCSVLogger.swift
//  LibreTransmitter
//

import Foundation
import os.log

/// Debug utility that logs what glucose values *would* be under each smoothing
/// strategy side by side (none, 5-point boxcar, Kalman), independent of whichever
/// strategy is actually active for dosing. Lets a user compare algorithms directly
/// against the same real BLE trend data without switching settings mid-session.
public final class GlucoseSmoothingCSVLogger {
    public static let shared = GlucoseSmoothingCSVLogger()

    private let logger = Logger(forType: "GlucoseSmoothingCSVLogger")
    private let queue = DispatchQueue(label: "no.nightscout.libretransmitter.smoothingcsvlogger")

    // Independent shadow Kalman state, separate from whatever filter (if any) is
    // actually driving dosing, so this comparison log always reflects "what if
    // Kalman had been selected the whole time" regardless of the real setting.
    private let shadowKalmanFilter = GlucoseKalmanFilter()
    private var lastLoggedDate: Date?

    public static var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("glucose_smoothing_comparison.csv")
    }

    private init() {}

    func reset() {
        queue.async {
            self.shadowKalmanFilter.reset()
            self.lastLoggedDate = nil
        }
    }

    public func clearLog() {
        queue.async {
            try? FileManager.default.removeItem(at: Self.fileURL)
        }
    }

    /// `sortedTrends` should be the same newest-first trend batch passed to
    /// `LibreGlucose.fromTrendMeasurements` at the production call site, so the
    /// logged comparison matches exactly what each strategy would have produced.
    func log(sortedTrends: [Measurement], calibrationData: SensorData.CalibrationInfo) {
        queue.async { [self] in
            guard !sortedTrends.isEmpty else { return }

            let none = LibreGlucose.fromTrendMeasurements(sortedTrends, nativeCalibrationData: calibrationData, smoothing: .off)
            let boxcar5 = LibreGlucose.fromTrendMeasurements(sortedTrends, nativeCalibrationData: calibrationData, smoothing: .boxcar5)
            let kalman = LibreGlucose.fromTrendMeasurements(
                sortedTrends,
                nativeCalibrationData: calibrationData,
                smoothing: .kalman(filter: shadowKalmanFilter, sinceDate: lastLoggedDate)
            )
            lastLoggedDate = sortedTrends.map(\.date).max() ?? lastLoggedDate

            // All three calls filter the same input measurements identically and
            // preserve input order, so they line up index-for-index.
            guard none.count == boxcar5.count, none.count == kalman.count else {
                logger.error("Smoothing comparison arrays mismatched in length, skipping this batch")
                return
            }

            var rows = ""
            for i in 0 ..< none.count {
                rows += "\(Self.dateFormatter.string(from: none[i].timestamp)),\(none[i].glucoseDouble),\(boxcar5[i].glucoseDouble),\(kalman[i].glucoseDouble)\n"
            }
            append(rows)
        }
    }

    private static let dateFormatter = ISO8601DateFormatter()

    private func append(_ rows: String) {
        guard !rows.isEmpty else { return }
        let url = Self.fileURL

        guard FileManager.default.fileExists(atPath: url.path) else {
            let header = "timestamp,none,boxcar5,kalman\n"
            try? (header + rows).write(to: url, atomically: true, encoding: .utf8)
            return
        }

        guard let data = rows.data(using: .utf8), let handle = try? FileHandle(forWritingTo: url) else {
            logger.error("Failed to open smoothing comparison CSV for appending")
            return
        }
        defer { try? handle.close() }
        handle.seekToEndOfFile()
        handle.write(data)
    }
}
