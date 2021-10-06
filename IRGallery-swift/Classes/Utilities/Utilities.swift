//
//  Utilities.swift
//  IRGallery-swift
//
//  Created by Phil on 2020/9/18.
//  Copyright © 2020 Phil. All rights reserved.
//

import Foundation
import UIKit

class Utilities {
    class func getCurrentBundle() -> Bundle {
        return Bundle.init(for: self)
    }
    
    class func image(_ image: UIImage, scaledToSize newSize: CGSize) -> UIImage? {
        UIGraphicsBeginImageContextWithOptions(newSize, false, 0.0)
        image.draw(in: CGRect.init(x: 0, y: 0, width: newSize.width, height: newSize.height))
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return newImage
    }
    
    /**
    Makes sure no other thread reenters the closure before the one running has not returned
    */
    @discardableResult
    class public func synchronized<T>(_ lock: AnyObject, closure:() -> T) -> T {
        objc_sync_enter(lock)
        defer { objc_sync_exit(lock) }

        return closure()
    }
}
