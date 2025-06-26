//
//  dispatch.swift
//  70K Bands!
//
//  Created by Ron Dorn on 1/19/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import Foundation

class dispatch {
    
    /**
     Provides asynchronous dispatch methods for background and main queues.
     */
    class async {
        /**
         Executes a block asynchronously on a background queue.
         - Parameter block: The block to execute.
         */
        class func bg(block: dispatch_block_t) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), block)
        }
        
        /**
         Executes a block asynchronously on the main queue.
         - Parameter block: The block to execute.
         */
        class func main(block: dispatch_block_t) {
            dispatch_async(dispatch_get_main_queue(), block)
        }
    }
    
    /**
     Provides synchronous dispatch methods for background and main queues.
     */
    class sync {
        /**
         Executes a block synchronously on a background queue.
         - Parameter block: The block to execute.
         */
        class func bg(block: dispatch_block_t) {
            dispatch_sync(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_BACKGROUND, 0), block)
        }
        
        /**
         Executes a block synchronously on the main queue. If already on the main thread, executes immediately.
         - Parameter block: The block to execute.
         */
        class func main(block: dispatch_block_t) {
            if NSThread.isMainThread() {
                block()
            }
            else {
                dispatch_sync(dispatch_get_main_queue(), block)
            }
        }
    }
}

 