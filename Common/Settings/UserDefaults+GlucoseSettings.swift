//
//  Userdefaults+Alarmsettings.swift
//  MiaomiaoClient
//
//  Created by LoopKit Authors on 20/04/2019.
//  Copyright © 2019 LoopKit Authors. All rights reserved.
//

import Foundation
import HealthKit

public enum GlucoseSmoothingAlgorithm: String, CaseIterable, Identifiable {
    case none
    case boxcar5
    case kalman

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .none: return LocalizedString("None", comment: "Glucose smoothing algorithm: none")
        case .boxcar5: return LocalizedString("5-point average", comment: "Glucose smoothing algorithm: 5-point moving average")
        case .kalman: return LocalizedString("Kalman filter", comment: "Glucose smoothing algorithm: Kalman filter")
        }
    }
}

extension UserDefaults {
    private enum Key: String {
        case mmSyncToNS = "com.loopkit.libreSyncToNs"
        case mmBackfillFromHistory = "com.loopkit.libreBackfillFromHistory"
        case glucoseSmoothingAlgorithm = "com.loopkit.libreGlucoseSmoothingAlgorithm"

    }

    var mmSyncToNs: Bool {
        get {
             optionalBool(forKey: Key.mmSyncToNS.rawValue) ?? true
        }
        set {
            set(newValue, forKey: Key.mmSyncToNS.rawValue)
        }
    }

    var mmBackfillFromHistory: Bool {
        get {
             optionalBool(forKey: Key.mmBackfillFromHistory.rawValue) ?? true
        }
        set {
            set(newValue, forKey: Key.mmBackfillFromHistory.rawValue)
        }
    }

    var glucoseSmoothingAlgorithm: GlucoseSmoothingAlgorithm {
        get {
            (string(forKey: Key.glucoseSmoothingAlgorithm.rawValue)).flatMap(GlucoseSmoothingAlgorithm.init(rawValue:)) ?? .kalman
        }
        set {
            set(newValue.rawValue, forKey: Key.glucoseSmoothingAlgorithm.rawValue)
        }
    }

}
