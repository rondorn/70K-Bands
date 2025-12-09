//
//  ProfileTutorialOverlay.swift
//  70K Bands
//
//  Tutorial overlay to help users find the profile switcher after importing
//

import UIKit

class ProfileTutorialOverlay: UIView {
    
    private let messageLabel = UILabel()
    private let arrowView = UIView()
    private let dismissButton = UIButton(type: .system)
    
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
        let messageContainer = UIView()
        messageContainer.backgroundColor = UIColor.black.withAlphaComponent(0.85)
        messageContainer.layer.cornerRadius = 12
        messageContainer.translatesAutoresizingMaskIntoConstraints = false
        addSubview(messageContainer)
        
        messageLabel.text = "Tap here to switch between profiles"
        messageLabel.font = UIFont.boldSystemFont(ofSize: 17)
        messageLabel.textColor = .white
        messageLabel.textAlignment = .center
        messageLabel.numberOfLines = 0
        messageLabel.translatesAutoresizingMaskIntoConstraints = false
        messageContainer.addSubview(messageLabel)
        
        // Dismiss button (tap anywhere to close)
        dismissButton.setTitle("Tap anywhere to close", for: .normal)
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
        NSLayoutConstraint.activate([
            // Message container near top, just below count label area
            messageContainer.centerXAnchor.constraint(equalTo: centerXAnchor),
            messageContainer.topAnchor.constraint(equalTo: safeAreaLayoutGuide.topAnchor, constant: 60),
            messageContainer.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 40),
            messageContainer.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -40),
            
            // Message label inside container
            messageLabel.topAnchor.constraint(equalTo: messageContainer.topAnchor, constant: 12),
            messageLabel.bottomAnchor.constraint(equalTo: messageContainer.bottomAnchor, constant: -12),
            messageLabel.leadingAnchor.constraint(equalTo: messageContainer.leadingAnchor, constant: 12),
            messageLabel.trailingAnchor.constraint(equalTo: messageContainer.trailingAnchor, constant: -12),
            
            // Arrow pointing UP, positioned above the message to point to count label
            arrowView.bottomAnchor.constraint(equalTo: messageContainer.topAnchor, constant: -10),
            arrowView.centerXAnchor.constraint(equalTo: centerXAnchor),
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
    
    /// Shows the tutorial overlay on the given view controller
    /// Shows every time an import happens since it's unobtrusive
    /// Dismisses when user taps anywhere on screen
    static func show(on viewController: UIViewController) {
        print("📚 [TUTORIAL] Showing profile switch tutorial")
        
        let overlay = ProfileTutorialOverlay()
        overlay.frame = viewController.view.bounds
        overlay.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        overlay.alpha = 0
        
        viewController.view.addSubview(overlay)
        
        // Animate in
        UIView.animate(withDuration: 0.3) {
            overlay.alpha = 1
        }
    }
}

