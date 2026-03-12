//
//  ScheduleQRScannerViewController.swift
//  70K Bands
//
//  Camera preview; auto-detects QR codes at full resolution. Throttled to one Vision request at a time to avoid memory growth.
//

import UIKit
import AVFoundation
import Vision

/// Presents camera preview; continuously scans for QR at full res (throttled). Accumulates schedule chunks (70K,i,8) until all 8 are collected; scan a few at a time—no need to fit all 8 in one frame.
final class ScheduleQRScannerViewController: UIViewController {

    private var captureSession: AVCaptureSession?
    private var previewLayer: AVCaptureVideoPreviewLayer?
    private let completion: ([Data]) -> Bool
    private let onCancel: (() -> Void)?
    /// Only one Vision request in flight; skip frames while processing to avoid filling memory.
    private var isProcessing = false
    private let processingLock = NSLock()
    private var didSucceed = false
    /// Throttle: run Vision at most every N frames to limit CPU/memory.
    private var frameCounter: Int = 0
    private static let framesBetweenScans = 10
    /// Hint label updated with progress (e.g. "5 of 8 scanned").
    private weak var scanHintLabel: UILabel?
    /// Accumulated schedule chunks by index (1...total). Access on main.
    private var collectedChunks: [Int: Data] = [:]
    /// Expected total chunks (8, 16, or 24) from first scanned QR.
    private var expectedChunkTotal: Int = 24

    init(onScan: @escaping ([Data]) -> Bool, onCancel: (() -> Void)? = nil) {
        self.completion = onScan
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let cancelButton = UIBarButtonItem(barButtonSystemItem: .cancel, target: self, action: #selector(cancelTapped))
        navigationItem.leftBarButtonItem = cancelButton
        navigationItem.title = NSLocalizedString("Scan QR Code Schedule", comment: "Scanner title")

        AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.setupCapture()
                } else {
                    self?.showCameraDenied()
                }
            }
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        collectedChunks = [:]
        expectedChunkTotal = 24
        updateCollectedHint()
        if let session = captureSession {
            Self.sessionQueue.async { session.startRunning() }
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if let session = captureSession {
            Self.sessionQueue.async { session.stopRunning() }
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        previewLayer?.frame = view.bounds
    }

    @objc private func cancelTapped() {
        onCancel?()
        dismiss(animated: true)
    }

    private static let sessionQueue = DispatchQueue(label: "qr.capture.session")

    private func setupCapture() {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input) else {
            showCameraUnavailable()
            return
        }
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: DispatchQueue(label: "qr.capture.queue"))
        guard session.canAddOutput(output) else {
            showCameraUnavailable()
            return
        }
        Self.sessionQueue.async { [weak self] in
            session.beginConfiguration()
            session.addInput(input)
            session.addOutput(output)
            session.commitConfiguration()
            self?.captureSession = session
            session.startRunning()
            DispatchQueue.main.async {
                self?.addPreviewAndUI(session: session)
            }
        }
    }

    private func addPreviewAndUI(session: AVCaptureSession) {
        let layer = AVCaptureVideoPreviewLayer(session: session)
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        view.layer.insertSublayer(layer, at: 0)
        previewLayer = layer

        let hint = UILabel()
        hint.translatesAutoresizingMaskIntoConstraints = false
        hint.text = NSLocalizedString("Scan each schedule QR — 0 of 24", comment: "QR scanner hint")
        hint.textColor = .white
        hint.font = .systemFont(ofSize: 15, weight: .medium)
        hint.textAlignment = .center
        hint.numberOfLines = 0
        hint.backgroundColor = UIColor.black.withAlphaComponent(0.5)
        hint.layer.cornerRadius = 8
        hint.clipsToBounds = true
        view.addSubview(hint)
        scanHintLabel = hint

        NSLayoutConstraint.activate([
            hint.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            hint.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            hint.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
        ])
    }

    /// Run Vision on full-resolution buffer only (no downscale) to maximize QR read success. Called from capture queue.
    private func processFrame(_ pixelBuffer: CVPixelBuffer) {
        runVisionOnBuffer(pixelBuffer) { [weak self] request, error in
            DispatchQueue.main.async {
                self?.handleBarcodeResults(request: request, error: error)
            }
        }
    }

    private func runVisionOnBuffer(_ pixelBuffer: CVPixelBuffer, completion: @escaping (VNRequest, Error?) -> Void) {
        let request = VNDetectBarcodesRequest { req, error in
            completion(req, error)
        }
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
        do {
            try handler.perform([request])
        } catch {
            completion(request, error)
        }
    }

    private func handleBarcodeResults(request: VNRequest, error: Error?) {
        defer {
            processingLock.lock()
            isProcessing = false
            processingLock.unlock()
        }
        if let error = error {
            print("[QRScan] Vision request error: \(error.localizedDescription)")
            showNoQRError(message: error.localizedDescription)
            return
        }
        let results = request.results as? [VNBarcodeObservation] ?? []
        let qrWithPayload: [(VNBarcodeObservation, Data)] = results.compactMap { obs in
            guard obs.symbology == .qr else { return nil }
            let data: Data?
            if #available(iOS 17.0, *), let raw = obs.payloadData, !raw.isEmpty {
                data = raw
            } else if let str = obs.payloadStringValue, !str.isEmpty, let encoded = str.data(using: .utf8) {
                data = encoded
            } else {
                data = nil
            }
            guard let payload = data else { return nil }
            return (obs, payload)
        }
        for (_, data) in qrWithPayload {
            guard let (index, total) = scheduleQRChunkIndex(from: data), (1...24).contains(index), (total == 8 || total == 16 || total == 24) else { continue }
            if expectedChunkTotal < total { expectedChunkTotal = total }
            if collectedChunks[index] == nil {
                collectedChunks[index] = data
                updateCollectedHint()
            }
        }
        guard collectedChunks.count == expectedChunkTotal else { return }
        processingLock.lock()
        let alreadySucceeded = didSucceed
        if !alreadySucceeded { didSucceed = true }
        processingLock.unlock()
        guard !alreadySucceeded else { return }
        let payloads = (1...expectedChunkTotal).compactMap { collectedChunks[$0] }
        print("[QRScan] Success: \(expectedChunkTotal) chunks accumulated, bytes: \(payloads.map { $0.count })")
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)
        let shouldDismiss = completion(payloads)
        if shouldDismiss {
            if let session = captureSession {
                Self.sessionQueue.async { session.stopRunning() }
            }
            dismiss(animated: true)
        }
    }

    private func updateCollectedHint() {
        let count = collectedChunks.count
        let total = expectedChunkTotal
        let message = String(format: NSLocalizedString("Scan each schedule QR — %d of %d", comment: "QR scanner progress"), count, total)
        scanHintLabel?.text = message
        scanHintLabel?.isHidden = false
    }

    /// Transient hint (e.g. "1 of 2") without blocking; avoid alert spam by throttling.
    private static var lastHintTime: Date?
    private func showScanHint(_ message: String) {
        let now = Date()
        guard ScheduleQRScannerViewController.lastHintTime.map({ now.timeIntervalSince($0) > 2 }) ?? true else { return }
        ScheduleQRScannerViewController.lastHintTime = now
        DispatchQueue.main.async { [weak self] in
            self?.scanHintLabel?.text = message
            self?.scanHintLabel?.isHidden = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
                self?.scanHintLabel?.isHidden = true
            }
        }
    }

    private func showNoQRError(message: String?) {
        guard presentedViewController == nil else { return }
        let text = message ?? NSLocalizedString("No valid schedule QR code found. Position the QR code in frame and try again.", comment: "QR scan failure")
        let alert = UIAlertController(
            title: NSLocalizedString("No QR Code", comment: "QR scan error title"),
            message: text,
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default))
        present(alert, animated: true)
    }

    private func showCameraDenied() {
        let alert = UIAlertController(
            title: NSLocalizedString("Camera Access", comment: ""),
            message: NSLocalizedString("Camera access is required to scan the schedule QR code. Enable it in Settings.", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }

    private func showCameraUnavailable() {
        let alert = UIAlertController(
            title: NSLocalizedString("Camera Unavailable", comment: ""),
            message: NSLocalizedString("Could not access the camera.", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment: ""), style: .default) { [weak self] _ in
            self?.dismiss(animated: true)
        })
        present(alert, animated: true)
    }
}

extension ScheduleQRScannerViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        processingLock.lock()
        if didSucceed {
            processingLock.unlock()
            return
        }
        if isProcessing {
            processingLock.unlock()
            return
        }
        frameCounter += 1
        if frameCounter % Self.framesBetweenScans != 0 {
            processingLock.unlock()
            return
        }
        isProcessing = true
        processingLock.unlock()

        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            processingLock.lock()
            isProcessing = false
            processingLock.unlock()
            return
        }
        processFrame(pixelBuffer)
    }
}

// MARK: - SwiftUI wrapper for use in Preferences

import SwiftUI

struct ScheduleQRScannerRepresentable: UIViewControllerRepresentable {
    let onScan: ([Data]) -> Bool
    let onCancel: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let vc = ScheduleQRScannerViewController(onScan: onScan, onCancel: onCancel)
        return UINavigationController(rootViewController: vc)
    }

    func updateUIViewController(_ uiViewController: UINavigationController, context: Context) {}
}
