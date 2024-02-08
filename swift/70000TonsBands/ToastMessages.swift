//
//  ToastMessages.swift
//  70K Bands
//
//  Created by Ron Dorn on 6/17/18.
//  Copyright © 2018 Ron Dorn. All rights reserved.
//

import Foundation
import UIKit

class ToastMessages : UILabel {
    
    private let BOTTOM_MARGIN: CGFloat = 16
    private let SIDE_MARGIN: CGFloat = 16
    private let HEIGHT: CGFloat = 35
    private let SHOW_TIME_SECONDS = TimeInterval(3)
    private let BACKGROUND_COLOR = UIColor.darkGray.withAlphaComponent(0.8).cgColor
    private let TEXT_COLOR = UIColor.white
    private let ANIMATION_DURATION_SEC = 0.13
    
    private static var queue: [ToastHolder] = []
    private static var showing: ToastMessages?
    private static var cellLocationStore: CGRect = CGRect();
    
    init(_ text: String) {
        super.init(frame: CGRect(x: 0, y: 0, width: 0, height: 0))
        
        self.text = text
        self.textColor = TEXT_COLOR

        textAlignment = .center
        self.layer.backgroundColor = BACKGROUND_COLOR
        self.layer.cornerRadius = 5

    }
    
    public func show(_ parent: UIViewController, placeHigh: Bool) {
        
        show(parent,cellLocation: ToastMessages.cellLocationStore, placeHigh: placeHigh)
    }
    
    
    public func show(_ parent: UIViewController, cellLocation: CGRect, placeHigh: Bool) {
        
        print ("Toast cell location is \(cellLocation)")
        var heightOffSet:CGFloat = cellLocation.midY - (cellLocation.height/8);
        
        if (placeHigh == true){
            heightOffSet = 0
        }
        
        print ("heightOffSet is \(heightOffSet)")
        frame = CGRect(x: SIDE_MARGIN, y: heightOffSet, width: cellLocation.width - 2 * SIDE_MARGIN, height: HEIGHT)

        ToastMessages.cellLocationStore = frame
        
        //Log.d("showing \(String(describing: text))")
        ToastMessages.showing = self
        alpha = 0
        parent.view.addSubview(self)
        
        self.lineBreakMode = NSLineBreakMode.byWordWrapping
        self.numberOfLines = 4
        if ((text?.count)! > 40){
            self.sizeToFit()
        }
        
        UIView.animate(withDuration: ANIMATION_DURATION_SEC, animations: {
            self.alpha = 1
        }, completion: { (completed) in
            Timer.scheduledTimer(timeInterval: self.SHOW_TIME_SECONDS, target: self, selector: #selector(self.onTimeout), userInfo: nil, repeats: false)
        })

    }
    
    @objc func onTimeout() {
        UIView.animate(withDuration: ANIMATION_DURATION_SEC, animations: {
            self.alpha = 0
        }, completion: { (completed) in
            ToastMessages.showing = nil
            self.removeFromSuperview()
            
            if !ToastMessages.queue.isEmpty {
                let holder = ToastMessages.queue.removeFirst()
                holder.toast.show(holder.parent, placeHigh: false)
            }
        })
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("this initializer is not supported")
    }
    
    private class ToastHolder {
        let toast: ToastMessages
        let parent: UIViewController
        
        init(_ t: ToastMessages, _ p: UIViewController) {
            toast = t
            parent = p
        }
    }
}
