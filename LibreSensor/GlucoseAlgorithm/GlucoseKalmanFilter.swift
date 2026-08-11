//
//  GlucoseKalmanFilter.swift
//  LibreTransmitter
//

import Foundation

/// A 2-state (level, trend) linear Kalman filter for smoothing irregularly-sampled
/// glucose trend measurements.
///
/// State: x = [level (mg/dL), trend (mg/dL per minute)].
/// Constant-velocity model over an interval dt (minutes):
///   level' = level + trend * dt
///   trend' = trend
/// Observation model: z = level (H = [1, 0]) -- we only ever observe glucose level directly.
///
/// Defaults follow Bequette (2010), "Continuous glucose monitoring: Real-time
/// algorithms for calibration, filtering, and alarms," J Diabetes Sci Technol
/// 4(2):404-418 -- the best-validated published Q/R starting point for this exact
/// 2-state CGM model -- adapted for Libre's higher noise floor and irregular
/// sampling (Bequette assumes fixed 5-minute Dexcom sampling; a continuous
/// white-noise-acceleration process-noise form is used here instead so Q scales
/// correctly with dt, per Bequette's own note that "if you change dt, Q must
/// scale").
final class GlucoseKalmanFilter {

    struct Output {
        let level: Double
        let trend: Double // mg/dL per minute
    }

    // Tunable noise parameters.
    private let measurementNoise: Double        // R, (mg/dL)^2
    private let processNoisePower: Double       // q, continuous white-noise-acceleration PSD, (mg/dL/min)^2 per min

    // Persistent filter state (uninitialized until first sample of a session).
    private var level: Double = 0
    private var trend: Double = 0
    private var lastDate: Date?

    // 2x2 covariance, stored as 3 independent terms (symmetric).
    private var p11: Double = 0 // Var(level)
    private var p12: Double = 0 // Cov(level, trend)
    private var p22: Double = 0 // Var(trend)

    // Guardrails
    private let maxDtMinutes: Double = 20   // beyond this, treat as a gap and clamp rather than extrapolate
    private let minDtMinutes: Double = 0.25 // guard against duplicate/near-duplicate timestamps

    /// - Parameters:
    ///   - measurementNoise: R, in (mg/dL)^2. Bequette's baseline is R = 4 (SD ~2
    ///     mg/dL) for well-calibrated Dexcom data; measured/simulated Dexcom G6
    ///     noise is closer to ~8 mg/dL RMSE (Camerlingo et al. 2023), and Libre is
    ///     noisier still (~9-16 mg/dL^2 is the literature's estimate). Default here
    ///     is 9 (SD 3 mg/dL) -- the low/more-responsive end of the Libre range --
    ///     since the motivating complaint is excess lag, not excess noise.
    ///   - processNoisePower: q, the process-noise spectral density feeding the
    ///     continuous white-noise-acceleration discretization (Q = q * [[dt^3/3,
    ///     dt^2/2], [dt^2/2, dt]]). Calibrated so the (2,2) term equals Bequette's
    ///     Q = 0.01 at dt = 5 minutes, i.e. q = 0.01 / 5 = 0.002. The literature's
    ///     suggested tuning sweep at dt = 5 is q22 in {0.003 (heavier smoothing,
    ///     Facchinetti-like), 0.01 (Bequette default), 0.03 (more responsive)},
    ///     i.e. q in {0.0006, 0.002, 0.006}.
    init(measurementNoise: Double = 9.0, processNoisePower: Double = 0.002) {
        self.measurementNoise = measurementNoise
        self.processNoisePower = processNoisePower
    }

    /// Resets the filter to an uninitialized state. Call on sensor change / disconnect.
    func reset() {
        lastDate = nil
        level = 0
        trend = 0
        p11 = 0
        p12 = 0
        p22 = 0
    }

    /// Feed one new (already-calibrated) glucose observation, in chronological order.
    /// Returns the filtered (level, trend) estimate after incorporating this sample.
    @discardableResult
    func update(measurement: Double, at date: Date) -> Output {
        guard let last = lastDate else {
            // First sample: seed level from the raw measurement, trend unknown (0),
            // with generous initial trend uncertainty so it converges quickly.
            level = measurement
            trend = 0
            p11 = measurementNoise
            p12 = 0
            p22 = 4.0 // (mg/dL/min)^2
            lastDate = date
            return Output(level: level, trend: trend)
        }

        var dt = date.timeIntervalSince(last) / 60.0 // minutes
        guard dt > minDtMinutes else {
            // Duplicate or out-of-order sample -- ignore rather than corrupt state.
            return Output(level: level, trend: trend)
        }
        if dt > maxDtMinutes {
            // Large gap (sensor dropout, app restart): don't extrapolate blindly,
            // clamp dt for the predict step instead.
            dt = maxDtMinutes
        }

        // --- Predict ---
        let predictedLevel = level + trend * dt
        let predictedTrend = trend

        // Continuous white-noise-acceleration process noise (Q), the standard form
        // for a 2-state constant-velocity model sampled at irregular intervals:
        // Q = q * [[dt^3/3, dt^2/2], [dt^2/2, dt]]. (Not the discrete-impulse
        // dt^4/dt^3/dt^2 form -- that assumes noise is injected once per fixed-size
        // step rather than continuously, and scales very differently for the
        // irregular multi-minute gaps seen on the BLE Direct path.)
        let dt2 = dt * dt
        let dt3 = dt2 * dt
        let q11 = processNoisePower * dt3 / 3.0
        let q12 = processNoisePower * dt2 / 2.0
        let q22 = processNoisePower * dt

        let predP11 = p11 + 2 * dt * p12 + dt2 * p22 + q11
        let predP12 = p12 + dt * p22 + q12
        let predP22 = p22 + q22

        // --- Update (H = [1, 0], so the innovation is scalar) ---
        let innovation = measurement - predictedLevel
        let s = predP11 + measurementNoise
        let k1 = predP11 / s
        let k2 = predP12 / s

        level = predictedLevel + k1 * innovation
        trend = predictedTrend + k2 * innovation

        p11 = (1 - k1) * predP11
        p12 = (1 - k1) * predP12
        p22 = predP22 - k2 * predP12

        lastDate = date
        return Output(level: level, trend: trend)
    }
}
