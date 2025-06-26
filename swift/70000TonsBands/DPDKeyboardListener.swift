//
//  KeyboardListener.swift
//  DropDown
//
//  Created by Kevin Hirsch on 30/07/15.
//  Copyright (c) 2015 Kevin Hirsch. All rights reserved.
//

import UIKit

/**
 Singleton class to listen for keyboard appearance and disappearance notifications.
 */
internal final class KeyboardListener {
	
	static let sharedInstance = KeyboardListener()
	
	fileprivate(set) var isVisible = false
	fileprivate(set) var keyboardFrame = CGRect.zero
	fileprivate var isListening = false
	
	/**
	 Deinitializes the KeyboardListener and stops listening to keyboard notifications.
	 */
	deinit {
		stopListeningToKeyboard()
	}
	
}

//MARK: - Notifications

extension KeyboardListener {
	
	/**
	 Starts listening to keyboard show/hide notifications.
	 */
	func startListeningToKeyboard() {
		if isListening {
			return
		}
		
		isListening = true
		
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(keyboardWillShow(_:)),
			name: UIResponder.keyboardWillShowNotification,
			object: nil)
		NotificationCenter.default.addObserver(
			self,
			selector: #selector(keyboardWillHide(_:)),
			name: UIResponder.keyboardWillHideNotification,
			object: nil)
	}
	
	/**
	 Stops listening to keyboard notifications.
	 */
	func stopListeningToKeyboard() {
		NotificationCenter.default.removeObserver(self)
	}
	
	/**
	 Handles the keyboard will show notification and updates visibility and frame.
	 - Parameter notification: The notification object containing keyboard info.
	 */
	@objc
	fileprivate func keyboardWillShow(_ notification: Notification) {
		isVisible = true
		keyboardFrame = keyboardFrame(fromNotification: notification)
	}
	
	/**
	 Handles the keyboard will hide notification and updates visibility and frame.
	 - Parameter notification: The notification object containing keyboard info.
	 */
	@objc
	fileprivate func keyboardWillHide(_ notification: Notification) {
		isVisible = false
		keyboardFrame = keyboardFrame(fromNotification: notification)
	}
	
	/**
	 Extracts the keyboard frame from the notification.
	 - Parameter notification: The notification object containing keyboard info.
	 - Returns: The CGRect representing the keyboard's frame.
	 */
	fileprivate func keyboardFrame(fromNotification notification: Notification) -> CGRect {
		return ((notification as NSNotification).userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue ?? CGRect.zero
	}
	
}
