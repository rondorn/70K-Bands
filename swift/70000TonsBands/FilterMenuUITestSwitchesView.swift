//
//  FilterMenuUITestSwitchesView.swift
//  70K Bands
//
//  UITest-only: SwiftUI List/Toggle accessibility is unreliable in XCUITest. A small UIKit strip of
//  UISwitches with stable identifiers drives the same filter setters as CommonFilterSheetView.
//

import UIKit

/// Shown only when `UITESTING` / `-UITesting` (see `MasterViewController.isRunningForUiTests()`).
final class FilterMenuUITestSwitchesView: UIView {

    static let preferredHeight: CGFloat = 52

    private let mustSwitch = UISwitch()
    private let mightSwitch = UISwitch()
    private let wontSwitch = UISwitch()
    private let unknownSwitch = UISwitch()

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = UIColor(white: 0.12, alpha: 1.0)
        configureSwitch(mustSwitch, id: "qaFilterToggleMustSee", action: #selector(mustChanged))
        configureSwitch(mightSwitch, id: "qaFilterToggleMightSee", action: #selector(mightChanged))
        configureSwitch(wontSwitch, id: "qaFilterToggleWontSee", action: #selector(wontChanged))
        configureSwitch(unknownSwitch, id: "qaFilterToggleUnknownSee", action: #selector(unknownChanged))

        let stack = UIStackView(arrangedSubviews: [mustSwitch, mightSwitch, wontSwitch, unknownSwitch])
        stack.axis = .horizontal
        stack.distribution = .equalSpacing
        stack.alignment = .center
        stack.spacing = 8
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: layoutMarginsGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: layoutMarginsGuide.trailingAnchor),
            stack.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        layoutMargins = UIEdgeInsets(top: 6, left: 10, bottom: 6, right: 10)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func configureSwitch(_ s: UISwitch, id: String, action: Selector) {
        s.accessibilityIdentifier = id
        s.addTarget(self, action: action, for: .valueChanged)
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window != nil {
            syncFromModelWithoutSideEffects()
        }
    }

    /// Keeps UIKit switches aligned if state changed elsewhere (e.g. Clear Filters in SwiftUI).
    func syncFromModelWithoutSideEffects() {
        mustSwitch.setOn(getMustSeeOn(), animated: false)
        mightSwitch.setOn(getMightSeeOn(), animated: false)
        wontSwitch.setOn(getWontSeeOn(), animated: false)
        unknownSwitch.setOn(getUnknownSeeOn(), animated: false)
    }

    @objc private func mustChanged() {
        apply { setMustSeeOn(mustSwitch.isOn) }
    }

    @objc private func mightChanged() {
        apply { setMightSeeOn(mightSwitch.isOn) }
    }

    @objc private func wontChanged() {
        apply { setWontSeeOn(wontSwitch.isOn) }
    }

    @objc private func unknownChanged() {
        apply { setUnknownSeeOn(unknownSwitch.isOn) }
    }

    private func apply(_ update: () -> Void) {
        update()
        writeFiltersFile()
        NotificationCenter.default.post(name: Notification.Name("VenueFiltersDidChange"), object: nil)
    }
}
