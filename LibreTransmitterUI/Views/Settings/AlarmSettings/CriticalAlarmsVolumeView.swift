//
//  CriticalAlarmsVolumeView.swift
//  LibreTransmitterUI
//
//  Created by LoopKit Authors on 29/01/2023.
//  Copyright © 2023 LoopKit Authors. All rights reserved.
//

import SwiftUI
import LibreTransmitter

struct CriticalAlertsBannerSection: View {
    @Binding var criticalAlertsEnabled: Bool
    @State private var presentableStatus: StatusMessage?

    var body: some View {
        if NotificationHelperOverride.shouldOverrideRequestCriticalPermissions && !criticalAlertsEnabled {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Label("Critical Alerts", systemImage: "bell.badge")
                        .font(.headline)
                    Text("Enable critical alerts so glucose alarms can sound even when Do Not Disturb or silent mode is on.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Button(action: requestCriticalAlerts) {
                        Text("Enable Critical Alerts")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.orange)
                    .padding(.top, 4)
                }
                .padding(.vertical, 4)
            }
            .alert(item: $presentableStatus) { status in
                Alert(title: Text(status.title), message: Text(status.message), dismissButton: .default(Text("Got it!")))
            }
        }
    }

    private func requestCriticalAlerts() {
        NotificationHelper.requestCriticalAlertPermission { enabled in
            criticalAlertsEnabled = enabled
            if !enabled {
                presentableStatus = StatusMessage(
                    title: "Could Not Enable Critical Alerts",
                    message: "Critical alerts could not be enabled. Make sure your app is built with the critical alerts entitlement and that your provisioning profile supports it."
                )
            }
        }
    }
}

struct CriticalAlarmsVolumeSection: View {
    private enum Key: String {
        case mmCriticalAlarmsVolume = "com.loopkit.libreCriticalAlarmsVolume"
    }

    @AppStorage(Key.mmCriticalAlarmsVolume.rawValue) var mmCriticalAlarmsVolume: Double = 60
    @State private var isEditing = false

    private var intVolume: Int {
        Int(mmCriticalAlarmsVolume)
    }

    var body: some View {
        Section(header: Text("Critical alarm volume"), footer: Text("Critical alarms will always be sent with volume at minimum 60%")) {
            Slider(
                value: $mmCriticalAlarmsVolume,
                in: 60...100,
                step: 5,
                onEditingChanged: { editing in
                    isEditing = editing
                }
            )
            Text("\(intVolume)%")
                .foregroundColor(isEditing ? .red : .blue)
        }
    }
}
