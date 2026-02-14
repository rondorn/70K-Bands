//
//  BandSelectionViewController.swift
//  70000TonsBands
//
//  Custom "Select Band" sheet: black background, white text, clearly visible buttons.
//

import UIKit

final class BandSelectionViewController: UIViewController {
    private let titleText: String
    private let messageText: String
    private let band1: String
    private let band2: String
    private let onSelect: (String) -> Void
    private let onCancel: () -> Void

    init(title: String, message: String, band1: String, band2: String, onSelect: @escaping (String) -> Void, onCancel: @escaping () -> Void) {
        self.titleText = title
        self.messageText = message
        self.band1 = band1
        self.band2 = band2
        self.onSelect = onSelect
        self.onCancel = onCancel
        super.init(nibName: nil, bundle: nil)
        modalPresentationStyle = .overFullScreen
        modalTransitionStyle = .crossDissolve
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor.black.withAlphaComponent(0.5)

        let panel = UIView()
        panel.backgroundColor = .black
        panel.layer.cornerRadius = 14
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)

        let titleLabel = UILabel()
        titleLabel.text = titleText
        titleLabel.font = .boldSystemFont(ofSize: 17)
        titleLabel.textColor = .white
        titleLabel.textAlignment = .center
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(titleLabel)

        let messageLabel = UILabel()
        messageLabel.text = messageText
        messageLabel.font = .systemFont(ofSize: 14)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(messageLabel)

        let band1Button = makeButton(title: band1)
        band1Button.addTarget(self, action: #selector(pickBand1), for: .touchUpInside)
        panel.addSubview(band1Button)

        let band2Button = makeButton(title: band2)
        band2Button.addTarget(self, action: #selector(pickBand2), for: .touchUpInside)
        panel.addSubview(band2Button)

        let cancelButton = makeButton(title: NSLocalizedString("Cancel", comment: ""))
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        panel.addSubview(cancelButton)

        NSLayoutConstraint.activate([
            panel.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            panel.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 24),
            panel.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -24),
            panel.centerYAnchor.constraint(equalTo: view.centerYAnchor),

            titleLabel.topAnchor.constraint(equalTo: panel.topAnchor, constant: 20),
            titleLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            titleLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),

            messageLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 8),
            messageLabel.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            messageLabel.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),

            band1Button.topAnchor.constraint(equalTo: messageLabel.bottomAnchor, constant: 20),
            band1Button.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            band1Button.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            band1Button.heightAnchor.constraint(equalToConstant: 48),

            band2Button.topAnchor.constraint(equalTo: band1Button.bottomAnchor, constant: 8),
            band2Button.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            band2Button.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            band2Button.heightAnchor.constraint(equalToConstant: 48),

            cancelButton.topAnchor.constraint(equalTo: band2Button.bottomAnchor, constant: 16),
            cancelButton.leadingAnchor.constraint(equalTo: panel.leadingAnchor, constant: 16),
            cancelButton.trailingAnchor.constraint(equalTo: panel.trailingAnchor, constant: -16),
            cancelButton.heightAnchor.constraint(equalToConstant: 48),
            cancelButton.bottomAnchor.constraint(equalTo: panel.bottomAnchor, constant: -20)
        ])

        let tap = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped(_:)))
        tap.cancelsTouchesInView = false
        view.addGestureRecognizer(tap)
    }

    private func makeButton(title: String) -> UIButton {
        let b = UIButton(type: .system)
        b.setTitle(title, for: .normal)
        b.setTitleColor(.white, for: .normal)
        b.setTitleColor(UIColor.white.withAlphaComponent(0.7), for: .highlighted)
        b.titleLabel?.font = .systemFont(ofSize: 16)
        b.backgroundColor = UIColor.white.withAlphaComponent(0.12)
        b.layer.cornerRadius = 10
        b.layer.borderWidth = 1
        b.layer.borderColor = UIColor.white.withAlphaComponent(0.35).cgColor
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    @objc private func pickBand1() { dismiss(animated: true) { [onSelect, band1] in onSelect(band1) } }
    @objc private func pickBand2() { dismiss(animated: true) { [onSelect, band2] in onSelect(band2) } }
    @objc private func cancelTapped() { dismiss(animated: true, completion: onCancel) }

    @objc private func backgroundTapped(_ g: UITapGestureRecognizer) {
        let loc = g.location(in: view)
        if let panel = view.subviews.first, panel.frame.contains(loc) { return }
        cancelTapped()
    }
}
