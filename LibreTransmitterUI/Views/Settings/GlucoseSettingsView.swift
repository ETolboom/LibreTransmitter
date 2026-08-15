//
//  GlucoseSettingsView.swift
//  LibreTransmitterUI
//
//  Created by LoopKit Authors on 26/05/2021.
//  Copyright © 2021 LoopKit Authors. All rights reserved.
//

import SwiftUI
import Combine
import LibreTransmitter
import HealthKit

struct GlucoseSettingsView: View {

    @State private var presentableStatus: StatusMessage?

    @AppStorage("com.loopkit.libreSyncToNs") var mmSyncToNS: Bool = true
    @AppStorage("com.loopkit.libreBackfillFromHistory") var mmBackfillFromHistory: Bool = true
    @AppStorage("com.loopkit.libreshouldPersistSensorData") var shouldPersistSensorData: Bool = false
    @AppStorage("com.loopkit.libreGlucoseSmoothingAlgorithm") var glucoseSmoothingAlgorithm: GlucoseSmoothingAlgorithm = .kalman
    @AppStorage("com.loopkit.libreLogSmoothingComparison") var logSmoothingComparison: Bool = false

    @State private var showSmoothingLogShareSheet = false

    @State private var authSuccess = false
    
    // Set this to true to require system authentication
    // for accessing the glucose section
    @State private var requiresAuthentication = Features.glucoseSettingsRequireAuthentication
    
    var body: some View {
        List {

            Section(header: Text(LocalizedString("Backfill options", comment: "Text describing header for backfill options in glucosesettingsview"))) {
                Toggle("Backfill from history", isOn: $mmBackfillFromHistory)
            }
            Section(header: Text(LocalizedString("Smoothing", comment: "Text describing header for smoothing options in glucosesettingsview")), footer: Text(LocalizedString("Smooths glucose trend values to reduce sensor noise. \"None\" is most responsive to rapid changes but noisiest; \"Kalman filter\" aims to be responsive with less noise than a plain average.", comment: "Text describing the glucose smoothing algorithm options"))) {
                Picker(LocalizedString("Glucose Smoothing", comment: "Label for glucose smoothing algorithm picker"), selection: $glucoseSmoothingAlgorithm) {
                    ForEach(GlucoseSmoothingAlgorithm.allCases) { algorithm in
                        Text(algorithm.displayName).tag(algorithm)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section(header: Text(LocalizedString("Remote data storage", comment: "Text describing header for remote data storage"))) {
                Toggle("Upload to remote data service", isOn: $mmSyncToNS)

            }
            Section(header: Text(LocalizedString("Debug options", comment: "Text describing header for debug options in glucosesettingsview")), footer: Text(LocalizedString("Adds a lot of data to the Issue Report ", comment: "Text informing user of potentially large reports"))) {
                Toggle("Persist sensordata", isOn: $shouldPersistSensorData)
                    .onChange(of: shouldPersistSensorData) {newValue in
                        if !newValue {
                            UserDefaults.standard.queuedSensorData = nil
                        }
                    }
            }
            Section(header: Text(LocalizedString("Smoothing comparison log", comment: "Text describing header for smoothing comparison log options in glucosesettingsview")), footer: Text(LocalizedString("Logs what each smoothing option (None, 5-point average, Kalman filter) would have produced for every reading, as a CSV, regardless of which one is selected above. Useful for comparing algorithms; has no effect on the value actually used for dosing.", comment: "Text describing the smoothing comparison CSV log"))) {
                Toggle(LocalizedString("Log smoothing comparison", comment: "Toggle to enable/disable the smoothing comparison CSV log"), isOn: $logSmoothingComparison)
                Button(LocalizedString("Share smoothing log", comment: "Button to share the smoothing comparison CSV log")) {
                    showSmoothingLogShareSheet = true
                }
                .disabled(!FileManager.default.fileExists(atPath: GlucoseSmoothingCSVLogger.fileURL.path))
                Button(LocalizedString("Clear smoothing log", comment: "Button to delete the smoothing comparison CSV log"), role: .destructive) {
                    GlucoseSmoothingCSVLogger.shared.clearLog()
                }
                .disabled(!FileManager.default.fileExists(atPath: GlucoseSmoothingCSVLogger.fileURL.path))
            }

        }
        .onAppear {
            if requiresAuthentication && !authSuccess {
                self.authenticate { success in
                    print("got authentication response: \(success)")
                    authSuccess = success
                }
            }
        }
        .disabled(requiresAuthentication ? !authSuccess : false)
        .listStyle(InsetGroupedListStyle())
        .alert(item: $presentableStatus) { status in
            Alert(title: Text(status.title), message: Text(status.message), dismissButton: .default(Text("Got it!")))
        }
        .navigationBarTitle("Glucose Settings")
        .sheet(isPresented: $showSmoothingLogShareSheet) {
            SmoothingLogShareSheet(activityItems: [GlucoseSmoothingCSVLogger.fileURL])
        }

    }

}

private struct SmoothingLogShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context _: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_: UIActivityViewController, context _: Context) {}
}

struct GlucoseSettingsView_Previews: PreviewProvider {
    static var previews: some View {
        GlucoseSettingsView()
    }
}
