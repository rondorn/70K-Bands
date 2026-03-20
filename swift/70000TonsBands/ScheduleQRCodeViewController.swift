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
/// White border (quiet zone) around single QR image in points. Smaller = larger QR on screen for easier Android scan.
private let scheduleQRImageWhiteBorder: CGFloat = 16

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
    /// Used so multi-line instructions get correct intrinsic height inside the scroll view.
    private var instructionsLabelForLayout: UILabel?

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
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        view.addSubview(label)

        let instructionsLabel = UILabel()
        instructionsLabel.translatesAutoresizingMaskIntoConstraints = false
        instructionsLabel.text = qrShareInstructionsText()
        instructionsLabel.textColor = .white
        instructionsLabel.font = .systemFont(ofSize: 14, weight: .regular)
        instructionsLabel.textAlignment = .natural
        instructionsLabel.numberOfLines = 0
        instructionsLabel.lineBreakMode = .byWordWrapping
        instructionsLabel.setContentCompressionResistancePriority(.required, for: .vertical)
        instructionsLabel.setContentHuggingPriority(.required, for: .vertical)
        instructionsLabelForLayout = instructionsLabel

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
            stack.addArrangedSubview(qrImageView(for: first, size: nil))
        }

        // Scroll between title and Done so help text is never squeezed out on form sheet (iPad):
        // a full-width square QR plus multi-line instructions exceeds default sheet height.
        let mainScroll = UIScrollView()
        mainScroll.translatesAutoresizingMaskIntoConstraints = false
        mainScroll.alwaysBounceVertical = true
        mainScroll.showsVerticalScrollIndicator = true
        view.insertSubview(mainScroll, at: 0)

        let qrContainer = UIView()
        qrContainer.translatesAutoresizingMaskIntoConstraints = false
        qrContainer.addSubview(stack)

        let scrollStack = UIStackView(arrangedSubviews: [instructionsLabel, qrContainer])
        scrollStack.translatesAutoresizingMaskIntoConstraints = false
        scrollStack.axis = .vertical
        scrollStack.spacing = 12
        scrollStack.alignment = .fill
        mainScroll.addSubview(scrollStack)

        var constraints: [NSLayoutConstraint] = [
            label.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: 12),
            label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 24),
            label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -24),

            doneButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -24),
            doneButton.centerXAnchor.constraint(equalTo: view.centerXAnchor),

            mainScroll.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
            mainScroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            mainScroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            mainScroll.bottomAnchor.constraint(equalTo: doneButton.topAnchor, constant: -16),

            scrollStack.topAnchor.constraint(equalTo: mainScroll.contentLayoutGuide.topAnchor),
            scrollStack.leadingAnchor.constraint(equalTo: mainScroll.frameLayoutGuide.leadingAnchor, constant: 24),
            scrollStack.trailingAnchor.constraint(equalTo: mainScroll.frameLayoutGuide.trailingAnchor, constant: -24),
            scrollStack.bottomAnchor.constraint(equalTo: mainScroll.contentLayoutGuide.bottomAnchor, constant: -8),
        ]

        if payloads.count == 2 || payloads.count == 3 {
            for sub in stack.arrangedSubviews {
                guard let iv = sub as? UIImageView else { continue }
                iv.widthAnchor.constraint(equalTo: iv.heightAnchor).isActive = true
                iv.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                iv.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
            }
        }

        if payloads.count == 8 || payloads.count == 16 || payloads.count == 24 {
            stack.widthAnchor.constraint(equalToConstant: scheduleQRGridWidth).isActive = true
            constraints += [
                stack.topAnchor.constraint(equalTo: qrContainer.topAnchor),
                stack.bottomAnchor.constraint(equalTo: qrContainer.bottomAnchor),
                stack.centerXAnchor.constraint(equalTo: qrContainer.centerXAnchor),
            ]
        } else {
            constraints += [
                stack.topAnchor.constraint(equalTo: qrContainer.topAnchor),
                stack.bottomAnchor.constraint(equalTo: qrContainer.bottomAnchor),
                stack.leadingAnchor.constraint(equalTo: qrContainer.leadingAnchor),
                stack.trailingAnchor.constraint(equalTo: qrContainer.trailingAnchor),
            ]
        }

        if payloads.count == 1, let qrView = stack.arrangedSubviews.first {
            constraints += [
                qrView.widthAnchor.constraint(equalTo: qrContainer.widthAnchor, constant: -32),
                qrView.heightAnchor.constraint(equalTo: qrView.widthAnchor),
            ]
        }

        NSLayoutConstraint.activate(constraints)

    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyPreferredContentSizeForFormSheet()
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        applyPreferredContentSizeForFormSheet()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard let il = instructionsLabelForLayout, il.bounds.width > 1 else { return }
        if abs(il.preferredMaxLayoutWidth - il.bounds.width) > 0.5 {
            il.preferredMaxLayoutWidth = il.bounds.width
            il.invalidateIntrinsicContentSize()
        }
    }

    /// iPad form sheets default to a height that cannot fit help text + a large square QR; prefer a taller sheet.
    private func applyPreferredContentSizeForFormSheet() {
        guard DeviceSizeManager.isLargeDisplay() else { return }
        let screen = view.window?.windowScene?.screen ?? UIScreen.main
        let bounds = screen.bounds
        preferredContentSize = CGSize(
            width: min(540, bounds.width * 0.55),
            height: min(880, bounds.height * 0.92)
        )
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
        /// Render at high resolution so when scaled to fill screen the modules stay sharp for Android scanning.
        let qrSize: CGFloat = 640
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
