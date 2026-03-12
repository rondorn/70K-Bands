//
//  ScheduleBinaryQRScannerView.swift
//  70K Bands
//
//  Uses BinaryQRScanner to read raw binary schedule QR(s). Returns 1 payload (full) or 2 (chunk1, chunk2) for LZMA decode.
//

import SwiftUI
import BinaryQRScanner

/// SwiftUI view that presents BinaryQRScanner in binary mode and collects 1 or 2 schedule payloads (type byte + LZMA).
struct ScheduleBinaryQRScannerView: View {
    let onScan: ([Data]) -> Bool
    let onCancel: () -> Void

    @State private var chunk1: Data?
    @State private var chunk2: Data?
    @State private var hintText = NSLocalizedString("Scan schedule QR code", comment: "Binary QR scanner hint")
    /// Delay before showing camera so the sheet is fully presented; avoids first-present dismiss when camera starts.
    @State private var cameraReady = false

    private static var scannerPresentCount = 0

    var body: some View {
        let _ = { Self.scannerPresentCount += 1; print("[QRScanner] View body evaluated (present #\(Self.scannerPresentCount))") }()
        NavigationStack {
            VStack(spacing: 16) {
                Text(hintText)
                    .multilineTextAlignment(.center)
                    .padding()
                if cameraReady {
                    BinaryQRScanner.View(
                        mode: .binary,
                        completion: handleScan,
                        dismiss: {
                            print("[QRScanner] dismiss closure called (BinaryQRScanner requested dismiss)")
                            onCancel()
                        },
                        subview: (UILabel(), BinaryQRScanner.View.SubviewPosition.top, 20)
                    )
                } else {
                    ProgressView(NSLocalizedString("Preparing camera…", comment: "QR scanner loading"))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .onAppear {
                print("[QRScanner] onAppear")
                // Present camera only after sheet is stable to avoid first-time immediate dismiss (camera start failure on first layout).
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    print("[QRScanner] setting cameraReady = true")
                    cameraReady = true
                }
            }
            .onDisappear {
                print("[QRScanner] onDisappear")
            }
            .navigationTitle(NSLocalizedString("Scan QR Code Schedule", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(NSLocalizedString("Cancel", comment: "")) {
                        print("[QRScanner] Cancel button tapped")
                        onCancel()
                    }
                }
            }
        }
    }

    private func handleScan(
        result: Result<BinaryQRScanner.ScanResult, BinaryQRScanner.ScanError>,
        dismissScanner: @escaping () -> Void,
        continueScanning: @escaping () -> Void
    ) {
        switch result {
        case .success(let scanResult):
            print("[QRScanner] handleScan called: success \(scanResult)")
            let data: Data?
            if case .binary(let d) = scanResult {
                data = d
            } else if case .text(let s) = scanResult, let d = s.data(using: .utf8) {
                data = d
            } else {
                data = nil
            }
            guard let payload = data, payload.count > 5 else {
                continueScanning()
                return
            }
            guard let (type, _) = scheduleQRBinaryPayloadType(payload) else {
                continueScanning()
                return
            }
            if type == scheduleQRTypeFull {
                let done = onScan([payload])
                if done { dismissScanner() }
                else { continueScanning() }
                return
            }
            if type == scheduleQRTypeChunk1 {
                chunk1 = payload
                hintText = NSLocalizedString("Scan second QR code", comment: "Binary QR scanner second")
                if let c2 = chunk2 {
                    let done = onScan([payload, c2])
                    if done { dismissScanner() }
                    else { continueScanning() }
                } else {
                    continueScanning()
                }
                return
            }
            if type == scheduleQRTypeChunk2 {
                chunk2 = payload
                if let c1 = chunk1 {
                    let done = onScan([c1, payload])
                    if done { dismissScanner() }
                    else { continueScanning() }
                } else {
                    hintText = NSLocalizedString("Scan first QR code", comment: "Binary QR scanner first")
                    continueScanning()
                }
                return
            }
            continueScanning()
        case .failure(let error):
            print("[QRScanner] handleScan called: failure \(error) (type: \(type(of: error)))")
            continueScanning()
        }
    }
}
