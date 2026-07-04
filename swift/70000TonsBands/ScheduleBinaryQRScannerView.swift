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
    @State private var lastPartialHintTime: Date?

    private static let partialHintThrottleSeconds: TimeInterval = 2.5
    private static let defaultHintText = NSLocalizedString("Scan schedule QR code", comment: "Binary QR scanner hint")
    private static var scannerPresentCount = 0

    var body: some View {
        let _ = { Self.scannerPresentCount += 1; print("[QRScanner] View body evaluated (present #\(Self.scannerPresentCount))") }()
        NavigationStack {
            Group {
                if cameraReady {
                    ZStack(alignment: .bottom) {
                        BinaryQRScanner.View(
                            mode: .binary,
                            completion: handleScan,
                            dismiss: {
                                print("[QRScanner] dismiss closure called (BinaryQRScanner requested dismiss)")
                                onCancel()
                            },
                            subview: (UILabel(), BinaryQRScanner.View.SubviewPosition.top, 20)
                        )
                        Text(hintText)
                            .font(.subheadline.weight(.medium))
                            .multilineTextAlignment(.center)
                            .foregroundColor(.white)
                            .padding(12)
                            .frame(maxWidth: .infinity)
                            .background(Color.black.opacity(0.65))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .padding(.horizontal, 24)
                            .padding(.bottom, 32)
                    }
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

    /// Cross-platform scan logging: payload received (length, typeByte, first 30 hex). Grep [QRScan].
    private func logScanPayloadReceived(_ payload: Data) {
        guard !payload.isEmpty else { return }
        let typeByte = payload[0]
        print("[QRScan] payload received length=\(payload.count) typeByte=\(typeByte)")
        print("[QRScan] payload firstBytesHex=\(bytesToHex(payload, 30))")
    }

    private func bytesToHex(_ payload: Data, _ maxLen: Int) -> String {
        let show = min(maxLen, payload.count)
        let hex = payload.prefix(show).map { String(format: "%02X", $0) }.joined(separator: " ")
        return payload.count > show ? hex + " ..." : hex
    }

    private func setHintText(_ text: String) {
        DispatchQueue.main.async {
            hintText = text
        }
    }

    private func showGuideQRHint() {
        DispatchQueue.main.async {
            hintText = NSLocalizedString("QRScanGuideQRHint", comment: "In-app scanner saw guide QR; scan schedule QR")
            print("[QRScanner] showing guide QR hint")
        }
    }

    private func showPartialReadHintIfNeeded() {
        DispatchQueue.main.async {
            let now = Date()
            if let last = lastPartialHintTime, now.timeIntervalSince(last) < Self.partialHintThrottleSeconds { return }
            lastPartialHintTime = now
            hintText = NSLocalizedString("QRScanPartialReadHint", comment: "Scanner got truncated QR payload; reduce glare")
            print("[QRScanner] showing partial read hint")
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
            if case .text(let s) = scanResult, ScheduleQRGuideLink.matchesGuideURLString(s) {
                showGuideQRHint()
                continueScanning()
                return
            }
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
            if ScheduleQRGuideLink.matchesGuidePayloadExact(payload) {
                showGuideQRHint()
                continueScanning()
                return
            }
            if isLikelyPartialScheduleQRScan(payload) {
                print("[QRScan] likely partial read length=\(payload.count) firstBytesHex=\(bytesToHex(payload, 12))")
                showPartialReadHintIfNeeded()
                continueScanning()
                return
            }
            logScanPayloadReceived(payload)
            let normalized: Data
            if let _ = scheduleQRBinaryPayloadType(payload) {
                normalized = payload
            } else if let stripped = normalizedScheduleQRPayload(fromScanned: payload) {
                normalized = stripped
            } else {
                print("[QRScan] payload rejected: typeByte=\(payload[0]) (expected 0/1/2); length=\(payload.count) firstBytesHex=\(bytesToHex(payload, 30))")
                continueScanning()
                return
            }
            guard let (type, _) = scheduleQRBinaryPayloadType(normalized) else {
                continueScanning()
                return
            }
            if isScheduleQRBinaryPayloadIncomplete(normalized) {
                print("[QRScan] partial payload length=\(normalized.count) typeByte=\(type)")
                showPartialReadHintIfNeeded()
                continueScanning()
                return
            }
            if type == scheduleQRTypeFull {
                let done = onScan([normalized])
                if done { dismissScanner() }
                else { continueScanning() }
                return
            }
            if type == scheduleQRTypeChunk1 {
                DispatchQueue.main.async { chunk1 = normalized }
                setHintText(NSLocalizedString("Scan second QR code", comment: "Binary QR scanner second"))
                if let c2 = chunk2 {
                    let done = onScan([normalized, c2])
                    if done { dismissScanner() }
                    else { continueScanning() }
                } else {
                    continueScanning()
                }
                return
            }
            if type == scheduleQRTypeChunk2 {
                DispatchQueue.main.async { chunk2 = normalized }
                if let c1 = chunk1 {
                    let done = onScan([c1, normalized])
                    if done { dismissScanner() }
                    else { continueScanning() }
                } else {
                    setHintText(NSLocalizedString("Scan first QR code", comment: "Binary QR scanner first"))
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
