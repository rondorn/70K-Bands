//
//  ProfileTutorialOverlay.swift
//  70K Bands
//
//  Tutorial overlay to help users find the profile switcher after importing
//

import UIKit

class ProfileTutorialOverlay: UIView {
    
    private let messageLabel = UILabel()
    private let messageContainer = UIView()
    private let arrowView = UIView()
    private let dismissButton = UIButton(type: .system)
    private var messageContainerTopConstraint: NSLayoutConstraint?
    private var messageContainerCenterXConstraint: NSLayoutConstraint?
    private var arrowBottomConstraint: NSLayoutConstraint?
    private var arrowCenterXConstraint: NSLayoutConstraint?
    
    init() {
        super.init(frame: .zero)
        setupView()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
        // Very transparent background
        backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        // Add tap gesture to dismiss when tapping anywhere
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(dismissTutorial))
        addGestureRecognizer(tapGesture)
        isUserInteractionEnabled = true
        
        // Message label with background
        messageContainer.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        messageContainer.layer.cornerRadius = 12
        messageContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageContainer)
        
        messageLabel.text = NSLocalizedString("Tap here to switch between profiles", comment: "Tutorial message")
        messageLabel.font = UIFont.boldSystemFont(ofSize: 17)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageContainer.addSubview(messageLabel)
        
        // Dismiss button (tap anywhere to close)
        dismissButton.setTitle(NSLocalizedString("Tap anywhere to close", comment: "Tutorial dismiss button"), for: .normal)
        dismissButton.titleLabel?.font = UIFont.systemFont(ofSize: 15)
        dismissButton.setTitleColor(.white.withAlphaComponent(0.7), for: .normal)
        dismissButton.backgroundColor = UIColor.clear
        dismissButton.layer.cornerRadius = 10
        dismissButton.translatesAutoresizingMaskIntoConstraints = false
        dismissButton.isUserInteractionEnabled = false // Let tap gesture handle it
        addSubview(dismissButton)
        
        // Arrow indicator - positioned near the top for count label
        arrowView.translatesAutoresizingMaskIntoConstraints = false
        addSubview(arrowView)
        
        // Layout
        // Store constraints so we can adjust them dynamically based on count label position
        // Use topAnchor (not safeAreaLayoutGuide) since we calculate absolute position from window
        messageContainerTopConstraint = messageContainer.topAnchor.constraint(equalTo: topAnchor, constant: 60)
        messageContainerCenterXConstraint = messageContainer.centerXAnchor.constraint(equalTo: centerXAnchor)
        arrowBottomConstraint = arrowView.bottomAnchor.constraint(equalTo: messageContainer.topAnchor, constant: -10)
        arrowCenterXConstraint = arrowView.centerXAnchor.constraint(equalTo: centerXAnchor)
        
        NSLayoutConstraint.activate([
            // Message container - position will be adjusted dynamically
            messageContainerCenterXConstraint!,
            messageContainerTopConstraint!,
            messageContainer.widthAnchor.constraint(equalToConstant: 280),
            
            // Add safety margins to prevent going off screen
            messageContainer.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 20),
            messageContainer.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -20),
            
            // Message label inside container
            messageLabel.topAnchor.constraint(equalTo: messageContainer.topAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: messageContainer.bottomAnchor, constant: -12),
            messageLabel.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: messageContainer.trailingAnchor, constant: -12),
            
            // Arrow pointing UP - position will be adjusted dynamically
            arrowBottomConstraint!,
            arrowCenterXConstraint!,
            arrowView.widthAnchor.constraint(equalToConstant: 50),
            arrowView.heightAnchor.constraint(equalToConstant: 40),
            
            // Dismiss hint at bottom
            dismissButton.centerXAnchor.constraint(equalTo: centerXAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: safeAreaLayoutGuide.bottomAnchor, constant: -40),
            dismissButton.widthAnchor.constraint(equalToConstant: 220),
            dismissButton.heightAnchor.constraint(equalToConstant: 40)
        ])
    }
    
    override func draw(_ rect: CGRect) {
        super.draw(rect)
        
        // Draw bold arrow pointing UP toward count label
        let arrowPath = UIBezierPath()
        let arrowRect = arrowView.frame
        
        // Create a solid, bold arrow pointing upward
        // Arrow head (pointing up)
        arrowPath.move(to: CGPoint(x: arrowRect.midX, y: arrowRect.minY)) // Top point
        arrowPath.addLine(to: CGPoint(x: arrowRect.minX, y: arrowRect.minY + 15)) // Left head
        arrowPath.addLine(to: CGPoint(x: arrowRect.midX - 8, y: arrowRect.minY + 15)) // Left inner
        arrowPath.addLine(to: CGPoint(x: arrowRect.midX - 8, y: arrowRect.maxY)) // Left shaft
        arrowPath.addLine(to: CGPoint(x: arrowRect.midX + 8, y: arrowRect.maxY)) // Right shaft
        arrowPath.addLine(to: CGPoint(x: arrowRect.midX + 8, y: arrowRect.minY + 15)) // Right inner
        arrowPath.addLine(to: CGPoint(x: arrowRect.maxX, y: arrowRect.minY + 15)) // Right head
        arrowPath.close()
        
        // Draw with white fill and slight shadow for visibility
        let context = UIGraphicsGetCurrentContext()
        context?.setShadow(offset: CGSize(width: 0, height: 2), blur: 4, color: UIColor.black.cgColor)
        UIColor.white.setFill()
        arrowPath.fill()
    }
    
    @objc func dismissTutorial() {
        UIView.animate(withDuration: 0.3, animations: {
            self.alpha = 0
        }) { _ in
            self.removeFromSuperview()
        }
    }
    
    /// Updates the position of the message based on a target view's position
    func updatePosition(for targetView: UIView, in window: UIWindow) {
        let targetFrame = targetView.convert(targetView.bounds, to: window)
        let targetBottomY = targetFrame.maxY
        let targetCenterX = targetFrame.midX
        let spacing: CGFloat = 50 // Space for arrow + gap
        
        // Update vertical position
        messageContainerTopConstraint?.constant = targetBottomY + spacing
        
        // Update horizontal position (offset from window center)
        let windowCenterX = window.bounds.width / 2
        let offsetFromCenter = targetCenterX - windowCenterX
        arrowCenterXConstraint?.constant = offsetFromCenter
        messageContainerCenterXConstraint?.constant = offsetFromCenter
        
        setNeedsLayout()
        layoutIfNeeded()
    }
    
    /// Shows the tutorial overlay on the given view controller
    /// Shows every time an import happens since it's unobtrusive
    /// Dismisses when user taps anywhere on screen
    static func show(on viewController: UIViewController) {
        print("📚 [TUTORIAL] Showing profile switch tutorial")
        
        // Find the actual view controller that has the navigation item
        // (Might be in a navigation controller or split view controller)
        var targetVC = viewController
        if let navVC = viewController.navigationController {
            // If we're in a nav controller, use the visible view controller
            targetVC = navVC.visibleViewController ?? viewController
        }
        
        // Find the window to add overlay at the highest level
        // This ensures the overlay covers EVERYTHING, including navigation bar
        guard let window = targetVC.view.window ?? UIApplication.shared.windows.first(where: { $0.isKeyWindow }) else {
            print("❌ [TUTORIAL] Could not find window to show overlay")
            return
        }
        
        let overlay = ProfileTutorialOverlay()
        overlay.frame = window.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.alpha = 0
        
        // Add to window instead of view controller's view
        // This ensures it covers the navigation bar too
        window.addSubview(overlay)
        
        // Position the arrow to point at the count label (navigationItem.titleView)
        if let titleView = targetVC.navigationItem.titleView {
            // Convert titleView position to window coordinates
            let titleViewFrame = titleView.convert(titleView.bounds, to: window)
            let titleBottomY = titleViewFrame.maxY
            let titleCenterX = titleViewFrame.midX
            
            print("📚 [TUTORIAL] Window bounds: \(window.bounds)")
            print("📚 [TUTORIAL] Title view frame in window: \(titleViewFrame)")
            print("📚 [TUTORIAL] Title view bottom Y: \(titleBottomY)")
            print("📚 [TUTORIAL] Title view center X: \(titleCenterX)")
            
            // Position message container below the title view
            let spacing: CGFloat = 50 // Space for arrow (40) + gap (10)
            overlay.messageContainerTopConstraint?.constant = titleBottomY + spacing
            
            // Position arrow and message horizontally aligned with title view
            // Use offset from center instead of absolute position
            let windowCenterX = window.bounds.width / 2
            let offsetFromCenter = titleCenterX - windowCenterX
            
            overlay.arrowCenterXConstraint?.constant = offsetFromCenter
            overlay.messageContainerCenterXConstraint?.constant = offsetFromCenter
            
            print("📚 [TUTORIAL] Message container Y: \(titleBottomY + spacing), X offset: \(offsetFromCenter)")
        } else {
            // Fallback: use navigation bar height + some offset
            let navBarHeight = targetVC.navigationController?.navigationBar.frame.maxY ?? 100
            let fallbackOffset: CGFloat = navBarHeight + 10
            overlay.messageContainerTopConstraint?.constant = fallbackOffset
            // Keep centered horizontally
            overlay.arrowCenterXConstraint?.constant = 0
            overlay.messageContainerCenterXConstraint?.constant = 0
            print("⚠️ [TUTORIAL] No title view found, using navigation bar bottom: \(fallbackOffset)")
        }
        
        // Force layout update
        overlay.setNeedsLayout()
        overlay.layoutIfNeeded()
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }
}

