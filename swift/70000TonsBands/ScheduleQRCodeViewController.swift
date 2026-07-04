//
//  ScheduleQRCodeViewController.swift
//  70K Bands
//
//  Displays schedule QR codes for share. Supports 1, 3, 8, 16, or 24 QRs. 24-QR: 4×6 grid, ~800 bytes per QR; scrollable.
//

import UIKit
import CoreImage.CIFilterBuiltins

/// Horizontal spacing between QR cells in a grid row.
private let scheduleQRSpacing: CGFloat = 16
/// White border (quiet zone) around single QR image in points. Smaller = larger QR on screen for easier Android scan.
private let scheduleQRImageWhiteBorder: CGFloat = 16
/// Horizontal inset for scroll content (both sides). On 320pt SE: 320 − 2×16 = 288pt max QR width.
private let scheduleQRHorizontalInset: CGFloat = 16
/// On-screen size for the text/URL guide QR (camera app); schedule QRs stay full width.
private let scheduleQRGuideDisplaySize: CGFloat = 88

/// Localized instructions for the schedule QR share screen.
private func qrShareInstructionsText() -> String {
    NSLocalizedString("QRShareInstructions", comment: "QR share screen: how to share offline")
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

        var scrollSections: [UIView] = [instructionsLabel]
        let showsGuideQR = ScheduleQRGuideLink.configuredGuideURLString != nil

        if let guideURL = ScheduleQRGuideLink.configuredGuideURLString {
            scrollSections.append(makeGuideSection(guideURL: guideURL))
        }

        if showsGuideQR {
            scrollSections.append(makeSectionLabel(
                text: NSLocalizedString("QRShareScheduleLabel", comment: "Label above schedule QR code(s)")
            ))
        }

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
        stack.alignment = .fill
        stack.distribution = isGrid ? .fillEqually : .fill

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

        scrollSections.append(qrContainer)

        let scrollStack = UIStackView(arrangedSubviews: scrollSections)
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
            scrollStack.leadingAnchor.constraint(equalTo: mainScroll.frameLayoutGuide.leadingAnchor, constant: scheduleQRHorizontalInset),
            scrollStack.trailingAnchor.constraint(equalTo: mainScroll.frameLayoutGuide.trailingAnchor, constant: -scheduleQRHorizontalInset),
            scrollStack.bottomAnchor.constraint(equalTo: mainScroll.contentLayoutGuide.bottomAnchor, constant: -8),
            scrollStack.widthAnchor.constraint(equalTo: mainScroll.frameLayoutGuide.widthAnchor, constant: -2 * scheduleQRHorizontalInset),

            qrContainer.widthAnchor.constraint(equalTo: scrollStack.widthAnchor),
        ]

        if isGrid {
            for case let row as UIStackView in stack.arrangedSubviews {
                for case let imageView as UIImageView in row.arrangedSubviews {
                    imageView.widthAnchor.constraint(equalTo: imageView.heightAnchor).isActive = true
                    imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
                    imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
                }
            }
        } else {
            bindSquareQRViews(in: stack, toContainerWidth: qrContainer)
        }

        constraints += [
            stack.topAnchor.constraint(equalTo: qrContainer.topAnchor),
            stack.bottomAnchor.constraint(equalTo: qrContainer.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: qrContainer.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: qrContainer.trailingAnchor),
        ]

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

    /// Guide QR block: short label + small text QR for the system Camera app.
    private func makeGuideSection(guideURL: String) -> UIView {
        let section = UIStackView()
        section.translatesAutoresizingMaskIntoConstraints = false
        section.axis = .vertical
        section.spacing = 6
        section.alignment = .center

        section.addArrangedSubview(makeSectionLabel(
            text: NSLocalizedString("QRShareGuideLabel", comment: "Label above guide QR for camera app")
        ))

        let guideQR = guideQRImageView(for: guideURL)
        guideQR.isAccessibilityElement = true
        guideQR.accessibilityLabel = NSLocalizedString("QRShareGuideAccessibility", comment: "VoiceOver label for guide QR")
        section.addArrangedSubview(guideQR)

        return section
    }

    private func makeSectionLabel(text: String) -> UILabel {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.text = text
        label.textColor = .white
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.textAlignment = .center
        label.numberOfLines = 0
        label.setContentCompressionResistancePriority(.required, for: .vertical)
        return label
    }

    /// Pins 1–3 full-width schedule QRs to the container so they never overflow on 320pt phones.
    private func bindSquareQRViews(in stack: UIStackView, toContainerWidth container: UIView) {
        for case let imageView as UIImageView in stack.arrangedSubviews {
            imageView.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
            imageView.heightAnchor.constraint(equalTo: imageView.widthAnchor).isActive = true
            imageView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
            imageView.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
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
            row.addArrangedSubview(iv)
        }
        return row
    }

    private func guideQRImageView(for urlString: String) -> UIImageView {
        let imageView = UIImageView()
        imageView.translatesAutoresizingMaskIntoConstraints = false
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .white
        if let img = generateTextQRImage(from: urlString) {
            imageView.image = img
        }
        let size = scheduleQRGuideDisplaySize
        imageView.widthAnchor.constraint(equalToConstant: size).isActive = true
        imageView.heightAnchor.constraint(equalToConstant: size).isActive = true
        return imageView
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

    private func generateTextQRImage(from string: String) -> UIImage? {
        guard let data = string.data(using: .utf8) else { return nil }
        return generateQRImage(from: data, renderSize: 200, whiteBorder: 6)
    }

    /// Generate QR from raw binary payload with white border (quiet zone). Use EC "L" so symbol is less dense and Android (ZXing) can recognize it; larger render size improves scan reliability.
    private func generateQRImage(from data: Data, renderSize: CGFloat = 640, whiteBorder: CGFloat = scheduleQRImageWhiteBorder) -> UIImage? {
        guard !data.isEmpty else { return nil }
        let filter = CIFilter.qrCodeGenerator()
        filter.setValue(data, forKey: "inputMessage")
        filter.setValue("L", forKey: "inputCorrectionLevel")
        guard let output = filter.outputImage,
              output.extent.width > 0, output.extent.height > 0 else { return nil }
        let scale = renderSize / min(output.extent.width, output.extent.height)
        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let bounds = scaled.extent.integral
        guard bounds.width > 0, bounds.height > 0 else { return nil }
        let context = CIContext(options: [.useSoftwareRenderer: true])
        guard let cgImage = context.createCGImage(scaled, from: bounds) else { return nil }
        let totalSize = renderSize + 2 * whiteBorder
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: totalSize, height: totalSize))
        let imageWithBorder = renderer.image { ctx in
            UIColor.white.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: totalSize, height: totalSize)))
            UIImage(cgImage: cgImage).draw(in: CGRect(x: whiteBorder, y: whiteBorder, width: renderSize, height: renderSize))
        }
        return imageWithBorder
    }
}
