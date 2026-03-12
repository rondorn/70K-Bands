//
//  ScheduleQRCodeViewController.swift
//  70K Bands
//
//  Displays schedule QR codes for share. Supports 1, 3, 8, 16, or 24 QRs. 24-QR: 4×6 grid, ~800 bytes per QR; scrollable.
//

import UIKit
import CoreImage.CIFilterBuiltins

/// Grid width for iPhone SE (320pt): 288pt leaves 16pt margin. 16pt spacing for quiet zone.
private let scheduleQRGridWidth: CGFloat = 288
private let scheduleQRSpacing: CGFloat = 16
/// White border (quiet zone) around single QR image in points. Helps Android (ZXing) recognize the symbol.
private let scheduleQRImageWhiteBorder: CGFloat = 24

/// Localized instructions for sharing schedule via QR (conditions + steps). Built from Localizable.strings.
private func qrShareInstructionsText() -> String {
    let intro = NSLocalizedString("QRShareInstructionsIntro", comment: "QR share screen: intro sentence")
    let cond1 = NSLocalizedString("QRShareCondition1", comment: "QR share: user with internet")
    let cond2 = NSLocalizedString("QRShareCondition2", comment: "QR share: user without internet")
    let how = NSLocalizedString("QRShareInstructionsHow", comment: "QR share: how to use intro")
    let step1 = NSLocalizedString("QRShareStep1", comment: "QR share step: go to Preferences")
    let step2 = NSLocalizedString("QRShareStep2", comment: "QR share step: select Scan QR")
    let step3 = NSLocalizedString("QRShareStep3", comment: "QR share step: scan this code")
    let step4 = NSLocalizedString("QRShareStep4", comment: "QR share step: get same schedule")
    return [intro, cond1, cond2, "", how, step1, step2, step3, step4].joined(separator: "\n")
}

/// Presents one, three, eight, or sixteen QR codes for schedule share. 16-QR: 4×4, low density for scannability.
final class ScheduleQRCodeViewController: UIViewController {

    private let payloads: [Data]
    private let closeBlock: (() -> Void)?

    /// Single QR (legacy or small schedule).
    init(payloadData: Data, onClose: (() -> Void)? = nil) {
        self.payloads = [payloadData]
        self.closeBlock = onClose
        super.init(nibName: nil, bundle: nil)
    }

    /// Three QRs: top / middle / bottom (~1/3 of schedule each). Order must match scanner reassembly.
    init(topPayload: Data, middlePayload: Data, bottomPayload: Data, onClose: (() -> Void)? = nil) {
        self.payloads = [topPayload, middlePayload, bottomPayload]
        self.closeBlock = onClose
        super.init(nibName: nil, bundle: nil)
    }

    /// 8, 16, or 24 schedule chunks (plain UTF-8). 8 → 2×4; 16 → 4×4; 24 → 4×6 (scrollable). Scan a few at a time.
    init(schedulePayloads: [Data], onClose: (() -> Void)? = nil) {
        self.payloads = Array(schedulePayloads.prefix(24))
        self.closeBlock = onClose
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .black

        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = NSLocalizedString("Share Schedule via QR Code", comment: "Title above QR for schedule share")
        label.textColor = .white
        label.font = .systemFont(ofSize: 18, weight: .medium)
        label.textAlignment = .center
        label.numberOfLines = 0
        view.addSubview(label)

        let instructionsLabel = UILabel()
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionsLabel.text = qrShareInstructionsText()
        instructionsLabel.textColor = .white
        instructionsLabel.font = .systemFont(ofSize: 14, weight: .regular)
        instructionsLabel.textAlignment = .natural
        instructionsLabel.numberOfLines = 0
        instructionsLabel.lineBreakMode = .byWordWrapping
        view.addSubview(instructionsLabel)

        let doneButton = UIButton(type: .system)
        doneButton.translatesAutoresizingMaskIntoConstraints = false
        doneButton.setTitle(NSLocalizedString("Done", comment: ""), for: .normal)
        doneButton.setTitleColor(.white, for: .normal)
        doneButton.addTarget(self, action: #selector(doneTapped), for: .touchUpInside)
        view.addSubview(doneButton)

        let stack = UIStackView()
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.axis = .vertical
        let isGrid = payloads.count == 8 || payloads.count == 16 || payloads.count == 24
        stack.spacing = isGrid ? scheduleQRSpacing : 12
        stack.alignment = .center
        stack.distribution = (payloads.count == 2 || payloads.count == 3 || isGrid) ? .fillEqually : .fill

        if payloads.count == 24 {
            let cols = 4
            for r in 0..<6 {
                let start = r * cols
                let end = min(start + cols, payloads.count)
                stack.addArrangedSubview(rowStack(for: Array(payloads[start..<end]), columns: cols))
            }
        } else if payloads.count == 16 {
            let cols = 4
            for r in 0..<4 {
                let start = r * cols
                let end = min(start + cols, payloads.count)
                stack.addArrangedSubview(rowStack(for: Array(payloads[start..<end]), columns: cols))
            }
        } else if payloads.count == 8 {
            for r in 0..<4 {
                let start = r * 2
                let end = start + 2
                stack.addArrangedSubview(rowStack(for: Array(payloads[start..<end]), columns: 2))
            }
        } else if payloads.count == 2 || payloads.count == 3 {
            for payload in payloads {
                let iv = qrImageView(for: payload, size: nil)
                iv.contentMode = .scaleAspectFit
                stack.addArrangedSubview(iv)
            }
        } else if let first = payloads.first {
            stack.addArrangedSubview(qrImageView(for: first, size: 320))
        }

        let stackContainer = UIView()
        stackContainer.translatesAutoresizingMaskIntoConstraints = false
        view.insertSubview(stackContainer, at: 0)
        if payloads.count == 24 {
            let scrollView = UIScrollView()
            scrollView.translatesAutoresizingMaskIntoConstraints = false
            scrollView.showsVerticalScrollIndicator = true
            scrollView.alwaysBounceVertical = true
            stackContainer.addSubview(scrollView)
            scrollView.addSubview(stack)
            NSLayoutConstraint.activate([
                scrollView.topAnchor.constraint(equalTo: stackContainer.topAnchor),
                scrollView.leadingAnchor.constraint(equalTo: stackContainer.leadingAnchor),
                scrollView.trailingAnchor.constraint(equalTo: stackContainer.trailingAnchor),
                scrollView.bottomAnchor.constraint(equalTo: stackContainer.bottomAnchor),
                stack.topAnchor.constraint(equalTo: scrollView.topAnchor),
                stack.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor),
                stack.bottomAnchor.constraint(equalTo: scrollView.bottomAnchor),
                stack.widthAnchor.constraint(equalTo: scrollView.widthAnchor),
            ])
        } else {
            stackContainer.addSubview(stack)
        }

        var constraints: [NSLayoutConstraint] = [
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            instructionsLabel.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            instructionsLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            instructionsLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),
            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stackContainer.topAnchor.constraint(equalTo: instructionsLabel.bottomAnchor, constant: 12),
            stackContainer.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            stackContainer.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            stackContainer.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -16),
        ]
        if payloads.count != 24 {
            constraints += [
                stack.topAnchor.constraint(equalTo: stackContainer.topAnchor),
                stack.bottomAnchor.constraint(equalTo: stackContainer.bottomAnchor),
                stack.centerXAnchor.constraint(equalTo: stackContainer.centerXAnchor),
            ]
        }
        if payloads.count == 2 || payloads.count == 3 {
            for sub in stack.arrangedSubviews {
                guard let iv = sub as? UIImageView else { continue }
                iv.widthAnchor.constraint(equalTo: iv.heightAnchor).isActive = true
                iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            }
        }
        if payloads.count != 8 && payloads.count != 16 && payloads.count != 24 {
            constraints += [
                stack.leadingAnchor.constraint(equalTo: stackContainer.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: stackContainer.trailingAnchor),
            ]
        }
        NSLayoutConstraint.activate(constraints)

        if payloads.count == 8 || payloads.count == 16 || payloads.count == 24 {
            stack.widthAnchor.constraint(equalToConstant: scheduleQRGridWidth).isActive = true
        }
    }

    /// One row of N square QR image views for the schedule grid.
    private func rowStack(for payloads: [Data], columns: Int) -> UIStackView {
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = scheduleQRSpacing
        row.distribution = .fillEqually
        row.alignment = .fill
        for payload in payloads {
            let iv = qrImageView(for: payload, size: nil)
            iv.contentMode = .scaleAspectFit
            iv.widthAnchor.constraint(equalTo: iv.heightAnchor, multiplier: 1).isActive = true
            row.addArrangedSubview(iv)
        }
        return row
    }

    private func qrImageView(for data: Data, size: CGFloat? = 280) -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        if let img = generateQRImage(from: data) {
            imageView.image = img
        }
        if let size = size {
            imageView.widthAnchor.constraint(equalToConstant: size).isActive = true
            imageView.heightAnchor.constraint(equalToConstant: size).isActive = true
        }
        return imageView
    }

    @objc private func doneTapped() {
        closeBlock?()
        dismiss(animated: true)
    }

    /// Generate QR from raw binary payload with white border (quiet zone). Use EC "L" so symbol is less dense and Android (ZXing) can recognize it; larger render size improves scan reliability.
    private func generateQRImage(from data: Data) -> UIImage? {
        guard !data.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("L", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage,
              output.extent.width > 0, output.extent.height > 0 else { return nil }
        let qrSize: CGFloat = 520
        let scale = qrSize / min(output.extent.width, output.extent.height)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let bounds = scaled.extent.integral
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = context.createCGImage(scaled, from: bounds) else { return nil }
        let border = scheduleQRImageWhiteBorder
        let totalSize = qrSize + 2 * border
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))
        let imageWithBorder = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: totalSize, height: totalSize)))
            UIImage(cgImage: cgImage).draw(in: CGRect(x: border, y: border, width: qrSize, height: qrSize))
        }
        return imageWithBorder
    }
}
