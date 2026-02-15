//
//  CompactActionSheetViewController.swift
//  70000TonsBands
//
//  Custom compact action sheet with icon support
//

import UIKit

class CompactActionSheetViewController: UIViewController, UIGestureRecognizerDelegate {
    
    struct MenuItem {
        let title: String
        let iconName: String?
        let isSelected: Bool
        let action: () -> Void
    }
    
    struct MenuSection {
        let header: String
        let items: [MenuItem]
    }
    
    private var sections: [MenuSection] = []
    private var titleText: String = ""
    private var cancelAction: (() -> Void)?
    /// When set (e.g. in portrait), menu is positioned near this point (in window coordinates). Nil = bottom-anchored.
    var sourcePointInWindow: CGPoint?
    
    private let containerView = UIView()
    private let titleLabel = UILabel()
    private let scrollView = UIScrollView()
    private let contentView = UIView()
    private let cancelButton = UIButton(type: .system)
    
    private let rowHeight: CGFloat = 36.0
    private let headerHeight: CGFloat = 22.0
    private let titleHeight: CGFloat = 40.0
    private let spacing: CGFloat = 1.0  // Minimal spacing
    private let cornerRadius: CGFloat = 14.0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Force dark mode appearance
        overrideUserInterfaceStyle = .dark
        setupUI()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        layoutContent()
    }
    
    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        hasLaidOutContent = false
        coordinator.animate(alongsideTransition: { _ in
            self.layoutContent()
        })
    }
    
    private var constraintsSet = false
    
    private func setupUI() {
        view.backgroundColor = UIColor.black.withAlphaComponent(0.4)
        
        // Container view
        containerView.backgroundColor = UIColor.systemGray6
        containerView.layer.cornerRadius = cornerRadius
        containerView.clipsToBounds = true
        view.addSubview(containerView)
        containerView.translatesAutoresizingMaskIntoConstraints = false
        
        // Title label
        titleLabel.text = titleText
        titleLabel.font = UIFont.boldSystemFont(ofSize: 16)
        titleLabel.textColor = .label
        titleLabel.textAlignment = .center
        titleLabel.backgroundColor = UIColor.systemGray6
        containerView.addSubview(titleLabel)
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        
        // Scroll view for content
        scrollView.showsVerticalScrollIndicator = true
        scrollView.backgroundColor = .clear
        containerView.addSubview(scrollView)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        
        // Content view
        contentView.backgroundColor = .clear
        scrollView.addSubview(contentView)
        contentView.translatesAutoresizingMaskIntoConstraints = false
        
        // Cancel button
        cancelButton.setTitle(NSLocalizedString("Cancel", comment: ""), for: .normal)
        cancelButton.titleLabel?.font = UIFont.systemFont(ofSize: 16)
        cancelButton.setTitleColor(.systemBlue, for: .normal)
        cancelButton.backgroundColor = UIColor.systemGray6
        cancelButton.layer.cornerRadius = cornerRadius
        cancelButton.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)
        view.addSubview(cancelButton)
        cancelButton.translatesAutoresizingMaskIntoConstraints = false
        
        // Tap gesture to dismiss - must not interfere with button taps
        let tapGesture = UITapGestureRecognizer(target: self, action: #selector(backgroundTapped))
        tapGesture.cancelsTouchesInView = false
        tapGesture.delegate = self
        view.addGestureRecognizer(tapGesture)
        
        // Set up base constraints (will be updated in layoutContent)
        setupBaseConstraints()
    }
    
    private func setupBaseConstraints() {
        containerView.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        containerView.widthAnchor.constraint(equalToConstant: view.bounds.width - 80).isActive = true
        containerBottomConstraint = containerView.bottomAnchor.constraint(equalTo: cancelButton.topAnchor, constant: -spacing)
        containerBottomConstraint?.isActive = true
        
        titleLabel.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        titleLabel.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        titleLabel.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        titleLabel.heightAnchor.constraint(equalToConstant: titleHeight).isActive = true
        
        scrollView.topAnchor.constraint(equalTo: titleLabel.bottomAnchor).isActive = true
        scrollView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        scrollView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
        scrollView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
        
        contentView.topAnchor.constraint(equalTo: scrollView.topAnchor).isActive = true
        contentView.leadingAnchor.constraint(equalTo: scrollView.leadingAnchor).isActive = true
        contentView.trailingAnchor.constraint(equalTo: scrollView.trailingAnchor).isActive = true
        contentView.bottomAnchor.constraint(greaterThanOrEqualTo: scrollView.bottomAnchor).isActive = true
        contentView.widthAnchor.constraint(equalTo: scrollView.widthAnchor).isActive = true
        
        cancelButton.centerXAnchor.constraint(equalTo: view.centerXAnchor).isActive = true
        cancelButton.widthAnchor.constraint(equalToConstant: view.bounds.width - 40).isActive = true
        cancelButton.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
        cancelBottomConstraint = cancelButton.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -spacing)
        cancelBottomConstraint?.isActive = true
    }
    
    private var containerHeightConstraint: NSLayoutConstraint?
    private var containerBottomConstraint: NSLayoutConstraint?
    /// Center Y from top (for near-tap positioning)
    private var containerCenterYFromTopConstraint: NSLayoutConstraint?
    /// Center Y in view (for centered positioning)
    private var containerCenterYInViewConstraint: NSLayoutConstraint?
    private var cancelBottomConstraint: NSLayoutConstraint?
    private var cancelTopToContainerConstraint: NSLayoutConstraint?
    private var hasLaidOutContent = false
    
    private func layoutContent() {
        // Prevent multiple layout calls that cause performance issues
        guard !hasLaidOutContent else { return }
        hasLaidOutContent = true
        
        // Remove existing subviews
        contentView.subviews.forEach { $0.removeFromSuperview() }
        itemActions.removeAll()
        
        let isLandscape = view.bounds.width > view.bounds.height
        
        // For landscape, use two-column layout (Priority left, Attendance right)
        if isLandscape && sections.count == 2 {
            layoutTwoColumnContent()
        } else {
            layoutSingleColumnContent()
        }
        
        // Calculate container height - make it compact, especially for landscape
        var totalContentHeight: CGFloat = 0
        
        if isLandscape && sections.count == 2 {
            // For two-column layout, use the height of the taller column
            let leftHeight = CGFloat(sections[0].items.count) * rowHeight + headerHeight + spacing * 2
            let rightHeight = CGFloat(sections[1].items.count) * rowHeight + headerHeight + spacing * 2
            totalContentHeight = max(leftHeight, rightHeight)
        } else {
            // Single column layout
            for section in sections {
                totalContentHeight += headerHeight + spacing
                totalContentHeight += CGFloat(section.items.count) * rowHeight
                totalContentHeight += spacing
            }
            totalContentHeight += spacing
        }
        
        // For landscape, use a much smaller max height (35% of screen)
        let maxContentHeight = isLandscape ? min(totalContentHeight, view.bounds.height * 0.35) : min(totalContentHeight, view.bounds.height * 0.5)
        let cancelButtonHeight: CGFloat = rowHeight
        let containerHeight = titleHeight + maxContentHeight + cancelButtonHeight + spacing * 2
        
        // Update container height constraint
        containerHeightConstraint?.isActive = false
        containerHeightConstraint = containerView.heightAnchor.constraint(equalToConstant: containerHeight)
        containerHeightConstraint?.isActive = true
        
        // Position menu near tap in portrait when source point is provided
        let isPortrait = view.bounds.height > view.bounds.width
        let groupHeight = containerHeight + spacing + cancelButtonHeight
        
        if isPortrait, let pointInWindow = sourcePointInWindow, let window = view.window {
            let pointInView = view.convert(pointInWindow, from: window)
            let safeTop = view.safeAreaInsets.top
            let safeBottom = view.safeAreaInsets.bottom
            let maxBottom = view.bounds.maxY - safeBottom
            let groupTopPreferred = pointInView.y - groupHeight / 2
            let groupTopClamped = min(max(groupTopPreferred, safeTop), maxBottom - groupHeight)
            let containerCenterY = groupTopClamped + containerHeight / 2
            
            containerBottomConstraint?.isActive = false
            cancelBottomConstraint?.isActive = false
            
            if cancelTopToContainerConstraint == nil {
                cancelTopToContainerConstraint = cancelButton.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: spacing)
            }
            cancelTopToContainerConstraint?.isActive = true
            
            containerCenterYInViewConstraint?.isActive = false
            if containerCenterYFromTopConstraint == nil {
                containerCenterYFromTopConstraint = containerView.centerYAnchor.constraint(equalTo: view.topAnchor, constant: containerCenterY)
            }
            containerCenterYFromTopConstraint?.constant = containerCenterY
            containerCenterYFromTopConstraint?.isActive = true
        } else {
            // Center the menu on screen (portrait without tap point, or landscape)
            containerBottomConstraint?.isActive = false
            cancelBottomConstraint?.isActive = false
            containerCenterYFromTopConstraint?.isActive = false
            
            if cancelTopToContainerConstraint == nil {
                cancelTopToContainerConstraint = cancelButton.topAnchor.constraint(equalTo: containerView.bottomAnchor, constant: spacing)
            }
            cancelTopToContainerConstraint?.isActive = true
            
            // Center the group (container + cancel) vertically
            let centerOffset = -(spacing + cancelButtonHeight) / 2
            if containerCenterYInViewConstraint == nil {
                containerCenterYInViewConstraint = containerView.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: centerOffset)
            }
            containerCenterYInViewConstraint?.constant = centerOffset
            containerCenterYInViewConstraint?.isActive = true
        }
    }
    
    private func layoutSingleColumnContent() {
        var previousView: UIView?
        
        for (sectionIndex, section) in sections.enumerated() {
            // Section header
            let headerView = createHeaderView(text: section.header)
            contentView.addSubview(headerView)
            headerView.translatesAutoresizingMaskIntoConstraints = false
            
            if let prev = previousView {
                headerView.topAnchor.constraint(equalTo: prev.bottomAnchor, constant: spacing).isActive = true
            } else {
                headerView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: spacing).isActive = true
            }
            headerView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
            headerView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
            headerView.heightAnchor.constraint(equalToConstant: headerHeight).isActive = true
            previousView = headerView
            
            // Section items
            for (itemIndex, item) in section.items.enumerated() {
                let itemView = createItemView(item: item, sectionIndex: sectionIndex, itemIndex: itemIndex)
                contentView.addSubview(itemView)
                itemView.translatesAutoresizingMaskIntoConstraints = false
                
                itemView.topAnchor.constraint(equalTo: previousView!.bottomAnchor).isActive = true
                itemView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
                itemView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
                itemView.heightAnchor.constraint(equalToConstant: rowHeight).isActive = true
                previousView = itemView
            }
            
            // Add spacing after section (except last)
            if sectionIndex < sections.count - 1 {
                let spacer = UIView()
                spacer.translatesAutoresizingMaskIntoConstraints = false
                spacer.backgroundColor = .clear
                contentView.addSubview(spacer)
                spacer.topAnchor.constraint(equalTo: previousView!.bottomAnchor).isActive = true
                spacer.leadingAnchor.constraint(equalTo: contentView.leadingAnchor).isActive = true
                spacer.trailingAnchor.constraint(equalTo: contentView.trailingAnchor).isActive = true
                spacer.heightAnchor.constraint(equalToConstant: spacing).isActive = true
                previousView = spacer
            }
        }
        
        // Connect last view to bottom
        if let lastView = previousView {
            lastView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing).isActive = true
        } else {
            contentView.heightAnchor.constraint(greaterThanOrEqualToConstant: spacing * 2).isActive = true
        }
    }
    
    private func layoutTwoColumnContent() {
        // Split sections: first section (Priority) on left, second section (Attendance) on right
        guard sections.count == 2 else {
            layoutSingleColumnContent()
            return
        }
        
        let prioritySection = sections[0]
        let attendanceSection = sections[1]
        
        // Calculate column width (accounting for spacing between columns)
        // Use containerView width minus padding (40pt on each side = 80pt total)
        let containerWidth = view.bounds.width - 40
        let columnSpacing: CGFloat = 8.0
        let columnWidth = (containerWidth - columnSpacing) / 2.0
        
        // Left column container (Priority)
        let leftColumn = UIView()
        leftColumn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(leftColumn)
        
        // Right column container (Attendance)
        let rightColumn = UIView()
        rightColumn.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(rightColumn)
        
        // Layout columns side by side
        NSLayoutConstraint.activate([
            leftColumn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: spacing),
            leftColumn.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            leftColumn.widthAnchor.constraint(equalToConstant: columnWidth),
            
            rightColumn.topAnchor.constraint(equalTo: contentView.topAnchor, constant: spacing),
            rightColumn.leadingAnchor.constraint(equalTo: leftColumn.trailingAnchor, constant: columnSpacing),
            rightColumn.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            rightColumn.widthAnchor.constraint(equalToConstant: columnWidth)
        ])
        
        // Layout Priority section in left column
        var leftPreviousView: UIView?
        
        // Priority header
        let priorityHeader = createHeaderView(text: prioritySection.header)
        leftColumn.addSubview(priorityHeader)
        priorityHeader.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            priorityHeader.topAnchor.constraint(equalTo: leftColumn.topAnchor),
            priorityHeader.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor),
            priorityHeader.trailingAnchor.constraint(equalTo: leftColumn.trailingAnchor),
            priorityHeader.heightAnchor.constraint(equalToConstant: headerHeight)
        ])
        leftPreviousView = priorityHeader
        
        // Priority items
        for (itemIndex, item) in prioritySection.items.enumerated() {
            let itemView = createItemView(item: item, sectionIndex: 0, itemIndex: itemIndex)
            leftColumn.addSubview(itemView)
            itemView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                itemView.topAnchor.constraint(equalTo: leftPreviousView!.bottomAnchor),
                itemView.leadingAnchor.constraint(equalTo: leftColumn.leadingAnchor),
                itemView.trailingAnchor.constraint(equalTo: leftColumn.trailingAnchor),
                itemView.heightAnchor.constraint(equalToConstant: rowHeight)
            ])
            leftPreviousView = itemView
        }
        
        if let lastLeft = leftPreviousView {
            lastLeft.bottomAnchor.constraint(equalTo: leftColumn.bottomAnchor, constant: -spacing).isActive = true
        }
        
        // Layout Attendance section in right column
        var rightPreviousView: UIView?
        
        // Attendance header
        let attendanceHeader = createHeaderView(text: attendanceSection.header)
        rightColumn.addSubview(attendanceHeader)
        attendanceHeader.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            attendanceHeader.topAnchor.constraint(equalTo: rightColumn.topAnchor),
            attendanceHeader.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor),
            attendanceHeader.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),
            attendanceHeader.heightAnchor.constraint(equalToConstant: headerHeight)
        ])
        rightPreviousView = attendanceHeader
        
        // Attendance items
        for (itemIndex, item) in attendanceSection.items.enumerated() {
            let itemView = createItemView(item: item, sectionIndex: 1, itemIndex: itemIndex)
            rightColumn.addSubview(itemView)
            itemView.translatesAutoresizingMaskIntoConstraints = false
            
            NSLayoutConstraint.activate([
                itemView.topAnchor.constraint(equalTo: rightPreviousView!.bottomAnchor),
                itemView.leadingAnchor.constraint(equalTo: rightColumn.leadingAnchor),
                itemView.trailingAnchor.constraint(equalTo: rightColumn.trailingAnchor),
                itemView.heightAnchor.constraint(equalToConstant: rowHeight)
            ])
            rightPreviousView = itemView
        }
        
        if let lastRight = rightPreviousView {
            lastRight.bottomAnchor.constraint(equalTo: rightColumn.bottomAnchor, constant: -spacing).isActive = true
        }
        
        // Connect columns to contentView bottom (height determined by taller column)
        // Use the taller column's bottom to set contentView height
        let leftHeight = CGFloat(prioritySection.items.count) * rowHeight + headerHeight + spacing * 2
        let rightHeight = CGFloat(attendanceSection.items.count) * rowHeight + headerHeight + spacing * 2
        
        if leftHeight >= rightHeight {
            leftColumn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing).isActive = true
            rightColumn.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -spacing).isActive = true
        } else {
            rightColumn.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -spacing).isActive = true
            leftColumn.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -spacing).isActive = true
        }
    }
    
    private func createHeaderView(text: String) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        
        let label = UILabel()
        label.text = text
        label.font = UIFont.boldSystemFont(ofSize: 12)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        view.addSubview(label)
        label.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor)
        ])
        
        return view
    }
    
    private var itemActions: [(sectionIndex: Int, itemIndex: Int, action: () -> Void)] = []
    
    private func createItemView(item: MenuItem, sectionIndex: Int, itemIndex: Int) -> UIView {
        let view = UIView()
        view.backgroundColor = UIColor.systemGray6
        
        let button = UIButton(type: .system)
        button.contentHorizontalAlignment = .left
        button.contentEdgeInsets = UIEdgeInsets(top: 0, left: 12, bottom: 0, right: 12)  // Reduced padding
        button.isExclusiveTouch = true  // Prevent multiple simultaneous touches
        button.isUserInteractionEnabled = true  // Ensure button can receive touches
        button.adjustsImageWhenHighlighted = true  // Visual feedback on tap
        // Ensure button has a clear background so entire area is tappable
        button.backgroundColor = .clear
        
        // Store action with indices
        let actionIndex = itemActions.count
        itemActions.append((sectionIndex: sectionIndex, itemIndex: itemIndex, action: item.action))
        button.tag = actionIndex
        button.addTarget(self, action: #selector(itemTapped(_:)), for: .touchUpInside)
        
        // Create horizontal stack for icon, text, and checkmark (checkmark on the right)
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8  // Reduced from 12 for compact layout
        stackView.alignment = .center
        
        // Icon
        if let iconName = item.iconName, !iconName.isEmpty, let iconImage = UIImage(named: iconName) {
            let iconView = UIImageView(image: iconImage)
            iconView.contentMode = .scaleAspectFit
            iconView.tintColor = .label  // Ensure icon uses label color for dark mode
            iconView.widthAnchor.constraint(equalToConstant: 18).isActive = true
            iconView.heightAnchor.constraint(equalToConstant: 18).isActive = true
            stackView.addArrangedSubview(iconView)
        }
        
        // Text
        let label = UILabel()
        label.text = item.title
        label.font = UIFont.systemFont(ofSize: 16)
        label.textColor = .label
        stackView.addArrangedSubview(label)
        
        // Checkmark on the right
        if item.isSelected {
            let checkmark = UILabel()
            checkmark.text = "✓"
            checkmark.font = UIFont.boldSystemFont(ofSize: 16)
            checkmark.textColor = .systemGreen
            checkmark.widthAnchor.constraint(equalToConstant: 16).isActive = true
            stackView.addArrangedSubview(checkmark)
        } else {
            let spacer = UIView()
            spacer.widthAnchor.constraint(equalToConstant: 16).isActive = true
            stackView.addArrangedSubview(spacer)
        }
        
        button.addSubview(stackView)
        stackView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 12),  // Reduced padding
            stackView.trailingAnchor.constraint(lessThanOrEqualTo: button.trailingAnchor, constant: -12),
            stackView.centerYAnchor.constraint(equalTo: button.centerYAnchor)
        ])
        
        // Ensure button fills entire view for maximum tap area
        view.addSubview(button)
        button.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: view.topAnchor),
            button.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            button.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        
        // Ensure stackView doesn't block touches - it's inside button so should be fine
        stackView.isUserInteractionEnabled = false
        
        // Separator line - must not block touches
        let separator = UIView()
        separator.backgroundColor = UIColor.separator
        separator.isUserInteractionEnabled = false  // Critical: don't block touches
        view.addSubview(separator)
        separator.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            separator.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),  // Reduced padding
            separator.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            separator.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            separator.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        
        // Ensure the view itself doesn't block touches
        view.isUserInteractionEnabled = true
        
        return view
    }
    
    private var isProcessingTap = false
    
    @objc private func itemTapped(_ sender: UIButton) {
        // Prevent multiple taps
        guard !isBeingDismissed, !isProcessingTap else { return }
        
        let actionIndex = sender.tag
        guard actionIndex < itemActions.count else { return }
        
        isProcessingTap = true
        
        // Execute action immediately
        let action = itemActions[actionIndex]
        action.action()
        
        // Dismiss immediately
        dismiss(animated: true) { [weak self] in
            self?.isProcessingTap = false
        }
    }
    
    @objc private func cancelTapped() {
        guard !isBeingDismissed, !isProcessingTap else { return }
        isProcessingTap = true
        cancelAction?()
        dismiss(animated: true) { [weak self] in
            self?.isProcessingTap = false
        }
    }
    
    // UIGestureRecognizerDelegate - prevent background tap from interfering with buttons
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        // Don't handle touches on buttons or interactive views
        if touch.view is UIButton {
            return false
        }
        // Don't handle touches inside containerView
        let location = touch.location(in: view)
        if containerView.frame.contains(location) || cancelButton.frame.contains(location) {
            return false
        }
        return true
    }
    
    @objc private func backgroundTapped(_ gesture: UITapGestureRecognizer) {
        guard !isBeingDismissed else { return }
        view.isUserInteractionEnabled = false
        dismiss(animated: true)
    }
    
    // Public interface
    /// - Parameter sourcePointInWindow: Optional. When set (e.g. in portrait), menu is positioned near this point (in window coordinates). Nil = bottom-anchored.
    static func present(
        from viewController: UIViewController,
        title: String,
        sections: [MenuSection],
        cancelAction: (() -> Void)? = nil,
        sourcePointInWindow: CGPoint? = nil
    ) {
        let actionSheet = CompactActionSheetViewController()
        actionSheet.titleText = title
        actionSheet.sections = sections
        actionSheet.cancelAction = cancelAction
        actionSheet.sourcePointInWindow = sourcePointInWindow
        actionSheet.modalPresentationStyle = .overFullScreen
        actionSheet.modalTransitionStyle = .crossDissolve
        viewController.present(actionSheet, animated: true)
    }
}
