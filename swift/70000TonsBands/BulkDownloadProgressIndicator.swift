//
//  BulkDownloadProgressIndicator.swift
//  70000TonsBands
//
//  Small non-blocking overlay matching Android's floating {completed}/{total} download bar.
//

import UIKit

/// Subtle bottom-of-screen progress for bulk image/notes downloads while the app is in the foreground.
final class BulkDownloadProgressIndicator {
    static let shared = BulkDownloadProgressIndicator()

    enum Phase: Hashable {
        case images
        case notes

        var localizedLabel: String {
            switch self {
            case .images:
                return NSLocalizedString("Bulk Image Download", comment: "Bulk image download progress label")
            case .notes:
                return NSLocalizedString("Bulk Note Download", comment: "Bulk note download progress label")
            }
        }
    }

    private let overlay = OverlayBar()
    private var activePhases = Set<Phase>()
    private var currentPhase: Phase?
    private var completed = 0
    private var total = 0
    private var hideWorkItem: DispatchWorkItem?
    private var observersInstalled = false
    private var sessionActive = false

    private init() {}

    /// Keeps the bar visible across image → notes phase gaps (map load, etc.).
    func beginSession() {
        DispatchQueue.main.async {
            self.installLifecycleObserversIfNeeded()
            self.hideWorkItem?.cancel()
            self.hideWorkItem = nil
            self.sessionActive = true
        }
    }

    /// Starts a phase. No-op when `total` is 0 so cached-only passes stay silent.
    func begin(phase: Phase, total: Int) {
        guard total > 0 else { return }
        DispatchQueue.main.async {
            self.installLifecycleObserversIfNeeded()
            self.hideWorkItem?.cancel()
            self.hideWorkItem = nil
            self.activePhases.insert(phase)
            self.currentPhase = phase
            self.completed = 0
            self.total = total
            self.refreshOverlay()
        }
    }

    func update(phase: Phase, completed: Int, total: Int) {
        guard total > 0 else { return }
        DispatchQueue.main.async {
            guard self.activePhases.contains(phase) else { return }
            self.currentPhase = phase
            self.completed = min(completed, total)
            self.total = total
            self.refreshOverlay()
        }
    }

    func end(phase: Phase) {
        DispatchQueue.main.async {
            self.activePhases.remove(phase)
            if self.activePhases.isEmpty && !self.sessionActive {
                self.scheduleHide()
            }
        }
    }

    /// Safety net when a bulk pass finishes (or is skipped after a phase already started).
    func finishAll() {
        DispatchQueue.main.async {
            self.sessionActive = false
            self.activePhases.removeAll()
            self.scheduleHide()
        }
    }

    private func installLifecycleObserversIfNeeded() {
        guard !observersInstalled else { return }
        observersInstalled = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillResignActive),
            name: UIApplication.willResignActiveNotification,
            object: nil
        )
    }

    @objc private func appDidBecomeActive() {
        refreshOverlay()
    }

    @objc private func appWillResignActive() {
        hideOverlay(animated: false)
    }

    private func refreshOverlay() {
        let hasProgress = total > 0 && currentPhase != nil
        let shouldShow = hasProgress && sessionActive
        guard shouldShow, let phase = currentPhase else {
            hideOverlay(animated: true)
            return
        }
        guard UIApplication.shared.applicationState == .active else {
            hideOverlay(animated: false)
            return
        }
        guard let window = Self.keyWindow() else { return }

        overlay.update(label: phase.localizedLabel, completed: completed, total: total)
        if overlay.superview !== window {
            overlay.removeFromSuperview()
            overlay.translatesAutoresizingMaskIntoConstraints = false
            window.addSubview(overlay)
            NSLayoutConstraint.activate([
                overlay.leadingAnchor.constraint(equalTo: window.leadingAnchor),
                overlay.trailingAnchor.constraint(equalTo: window.trailingAnchor),
                overlay.bottomAnchor.constraint(equalTo: window.safeAreaLayoutGuide.bottomAnchor, constant: -4)
            ])
        }
        window.bringSubviewToFront(overlay)
        overlay.showIfNeeded()
    }

    private func scheduleHide() {
        hideWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.hideOverlay(animated: true)
            self?.currentPhase = nil
            self?.completed = 0
            self?.total = 0
        }
        hideWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    private func hideOverlay(animated: Bool) {
        overlay.hide(animated: animated)
    }

    private static func keyWindow() -> UIWindow? {
        let windows = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .filter { $0.windowLevel == .normal }
        return windows.first(where: { $0.isKeyWindow }) ?? windows.first
    }
}

private final class OverlayBar: UIView {
    private let label = UILabel()
    private let progressView = UIProgressView(progressViewStyle: .default)
    private var isVisible = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        isAccessibilityElement = false
        accessibilityElementsHidden = true
        backgroundColor = UIColor.black.withAlphaComponent(0.9)
        alpha = 0

        label.font = UIFont.systemFont(ofSize: 11)
        label.textColor = .white
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        label.setContentHuggingPriority(.required, for: .horizontal)

        progressView.progress = 0
        progressView.trackTintColor = UIColor.white.withAlphaComponent(0.25)
        progressView.progressTintColor = UIColor.white.withAlphaComponent(0.85)

        let stack = UIStackView(arrangedSubviews: [label, progressView])
        stack.axis = .horizontal
        stack.alignment = .center
        stack.spacing = 8
        stack.isUserInteractionEnabled = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            stack.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -5),
            progressView.heightAnchor.constraint(equalToConstant: 3),
            heightAnchor.constraint(greaterThanOrEqualToConstant: 22)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func update(label title: String, completed: Int, total: Int) {
        self.label.text = "\(title): \(completed)/\(total)"
        let fraction = total > 0 ? Float(completed) / Float(total) : 0
        progressView.setProgress(fraction, animated: true)
    }

    func showIfNeeded() {
        guard !isVisible else { return }
        isVisible = true
        isHidden = false
        UIView.animate(withDuration: 0.2) {
            self.alpha = 1
        }
    }

    func hide(animated: Bool) {
        guard isVisible || alpha > 0 else { return }
        isVisible = false
        let apply = {
            self.alpha = 0
        }
        if animated {
            UIView.animate(withDuration: 0.2, animations: apply) { _ in
                if !self.isVisible {
                    self.isHidden = true
                }
            }
        } else {
            apply()
            isHidden = true
        }
    }
}
