//
//  IRGalleryPhoto.swift
//  IRGallery-swift
//
//  Created by Phil on 2020/8/25.
//  Copyright © 2020 Phil. All rights reserved.
//

import Foundation
import UIKit
import CommonCrypto
import os

let IRDefaultCacheTimeValue = 604800.0 // 7 days
let IRDefaultTimeoutValue = 60.0

protocol IRGalleryPhotoDelegate {
    func galleryPhoto(photo: IRGalleryPhoto, didLoadThumbnail image: UIImage)
    func galleryPhoto(photo: IRGalleryPhoto, didLoadFullsize image: UIImage)
    
    // MARK: - optional
    func galleryPhoto(photo: IRGalleryPhoto, willLoadThumbnailFromUrl url: String)
    func galleryPhoto(photo: IRGalleryPhoto, willLoadFullsizeFromUrl url: String)
    func galleryPhoto(photo: IRGalleryPhoto, willLoadThumbnailFromPath path: String)
    func galleryPhoto(photo: IRGalleryPhoto, willLoadFullsizeFromPath path: String)
    func galleryPhoto(photo: IRGalleryPhoto, loadingFullsize image: UIImage)
    func galleryPhoto(photo: IRGalleryPhoto, loadingThumbnail image: UIImage)
    func galleryPhoto(photo: IRGalleryPhoto, showThumbnail show: Bool)
    func galleryPhotoLoadThumbnailFromLocal(photo: IRGalleryPhoto) -> UIImage?
}

extension IRGalleryPhotoDelegate {
    func galleryPhoto(photo: IRGalleryPhoto, willLoadThumbnailFromUrl url: String) {}
    func galleryPhoto(photo: IRGalleryPhoto, willLoadFullsizeFromUrl url: String) {}
    func galleryPhoto(photo: IRGalleryPhoto, willLoadThumbnailFromPath path: String) {}
    func galleryPhoto(photo: IRGalleryPhoto, willLoadFullsizeFromPath path: String) {}
    func galleryPhoto(photo: IRGalleryPhoto, loadingFullsize image: UIImage) {}
    func galleryPhoto(photo: IRGalleryPhoto, loadingThumbnail image: UIImage) {}
    func galleryPhoto(photo: IRGalleryPhoto, showThumbnail show: Bool) {}
    func galleryPhotoLoadThumbnailFromLocal(photo: IRGalleryPhoto) -> UIImage? { return nil }
}

class IRGalleryPhoto: NSObject, NSURLConnectionDataDelegate {
    // value which determines if the photo was initialized with local file paths or network paths.
    var _useNetwork: Bool = false
     
    var _thumbData: NSMutableData?
    var _fullsizeData: NSMutableData?
    
    var _thumbConnection: NSURLConnection?
    var _fullsizeConnection: NSURLConnection?
    
    private var _imageSource: CGImageSource?
    // Width of the downloaded image
    private var _imageWidth: Int = 0
    // Height of the downloaded image
    private var _imageHeight: Int = 0
    // Expected image size
    private var _expectedSize: Int64 = 0
    // Connection queue
    private var _queue: DispatchQueue?
    
    private var logger: Logger?
    
    public init(thumbnailUrl thumb: String, fullsizeUrl fullsize: String, delegate: IRGalleryPhotoDelegate) {
//        super.init()
        _useNetwork = true
        thumbUrl = thumb
        fullsizeUrl = fullsize
        self.delegate = delegate
    }
    
    public init(thumbnailPath thumb: String, fullsizePath fullsize: String, delegate: IRGalleryPhotoDelegate) {
        _useNetwork = false
        thumbUrl = thumb
        fullsizeUrl = fullsize
        self.delegate = delegate
    }
    
    override init() {
        super.init()
        logger = Logger.init(subsystem: Bundle.main.bundleIdentifier!, category:self.description)
        initializeAttributes()
    }
    
    open func loadThumbnail() {
        if isThumbLoading || hasThumbLoaded {
            return
        }
        
        // load from network
        if _useNetwork {
            self.delegate?.galleryPhoto(photo: self, willLoadThumbnailFromUrl: thumbUrl ?? "")
            
            DispatchQueue.main.async {
                self.delegate?.galleryPhotoLoadThumbnailFromLocal(photo: self)
                
                if (self.thumbnail == nil) {
                    self.loadImageAtURL(url: URL.init(string: self.thumbUrl ?? ""), isThumbSize: true)
                } else {
                    self.delegate?.galleryPhoto(photo: self, didLoadThumbnail: self.thumbnail!)
                }
            }
        } else { // load from disk
            self.delegate?.galleryPhoto(photo: self, willLoadThumbnailFromPath: self.thumbUrl ?? "")
            
            isThumbLoading = true
            
            DispatchQueue.global().async {
                self.thumbnail = UIImage.init(contentsOfFile: self.thumbUrl ?? "")
                
                self.hasThumbLoaded = true
                self.isThumbLoading = false
                
                DispatchQueue.main.async {
                    self.delegate?.galleryPhoto(photo: self, didLoadThumbnail: self.thumbnail!)
                }
            }
        }
    }
    
    open func loadFullsize() {
        if isFullsizeLoading || hasFullsizeLoaded {
            return
        }
        
        if _useNetwork {
            self.delegate?.galleryPhoto(photo: self, willLoadFullsizeFromUrl: fullsizeUrl ?? "")
            enableProgressive = true
            
            self.loadImageAtURL(url: URL.init(string: fullsizeUrl ?? ""), isThumbSize: false)
        } else {
            self.delegate?.galleryPhoto(photo: self, willLoadFullsizeFromPath: fullsizeUrl ?? "")
            isFullsizeLoading = true
            
            DispatchQueue.global().async {
                self.fullsize = UIImage.init(contentsOfFile: self.fullsizeUrl ?? "")
                
                self.hasFullsizeLoaded = true
                self.isFullsizeLoading = false
                
                DispatchQueue.main.async {
                    self.delegate?.galleryPhoto(photo: self, didLoadFullsize: self.fullsize!)
                }
            }
        }
    }
    
    open func unloadFullsize() {
        Utilities.synchronized(self) {
            NSLog("unloadFullsize")
            _fullsizeConnection?.cancel()
            NSLog("cancel")
            
            killFullsizeLoadObjects()
            
            isFullsizeLoading = false
            hasFullsizeLoaded = false
            fullsize = nil
        }
    }
    
    open func unloadThumbnail() {
        Utilities.synchronized(self) {
            NSLog("unloadThumbnail")
            _thumbConnection?.cancel()
            NSLog("cancel")
            
            killThumbnailLoadObjects()
            
            isThumbLoading = false
            hasThumbLoaded = false
            thumbnail = nil
        }
    }
    
    open var tag: UInt = 0
    
    open private(set) var thumbUrl: String?
    open private(set) var fullsizeUrl: String?
    
    open private(set) var isThumbLoading: Bool = false
    open private(set) var hasThumbLoaded: Bool = false
    
    open private(set) var isFullsizeLoading: Bool = false
    open private(set) var hasFullsizeLoaded: Bool = false
    
    open private(set) var thumbnail: UIImage?
    open private(set) var fullsize: UIImage?

    open var delegate: IRGalleryPhotoDelegate?
    
    // MARK: - Memory Management
    func releaseFullsizeImageSource() {
        if (_imageSource != nil) {
            _imageSource = nil
        }
    }

    func killThumbnailLoadObjects() {
        _thumbConnection = nil;
        _thumbData = nil;
    }

    func killFullsizeLoadObjects() {
        _fullsizeConnection = nil
        _fullsizeData = nil
        releaseFullsizeImageSource()
    }

    deinit {
        _fullsizeConnection?.cancel()
        _thumbConnection?.cancel()
        killFullsizeLoadObjects()
        killThumbnailLoadObjects()
    }
    
    // MARK: - Progressive behavior messages
    /// Launch the image download
    func loadImageAtURL(url: URL?, isThumbSize: Bool) {
        if (isThumbSize ? isThumbLoading : isFullsizeLoading || url == nil) {
            return
        }
        
        if caching {
            // check if file exists on cache
            let fileManager = FileManager.init()
            let cacheDir = IRGalleryPhoto.cacheDirectoryAddress()
            let cachedImagePath = cacheDir.appendingPathComponent(self.cachedImageSystemNameByUrl(url))
            
            if fileManager.fileExists(atPath: cachedImagePath) {
                do {
                    let attributes = try fileManager.attributesOfItem(atPath: cachedImagePath)
                    let mofificationDate: Date = attributes[FileAttributeKey.modificationDate] as! Date
                    if mofificationDate.timeIntervalSinceNow * -1 > cacheTime ?? 0 {
                        resetCacheByUrl(url)
                    }
                } catch {
                    loadImageFromCache(cachedImagePath: cachedImagePath, isThumbSize: isThumbSize)
                    
                    return
                }
                
            }
        }
        
        _queue?.async {
            let request = URLRequest.init(url: url!, cachePolicy: .useProtocolCachePolicy, timeoutInterval: IRDefaultTimeoutValue)
            
            if isThumbSize {
                self.isThumbLoading = true
                self._thumbConnection = NSURLConnection.init(request: request, delegate: self, startImmediately: false)
                self._thumbConnection?.schedule(in: RunLoop.current, forMode: .common)
                self._thumbData = NSMutableData.init()
                self._thumbConnection?.start()
            } else {
                self.isFullsizeLoading = true
                self._fullsizeConnection = NSURLConnection.init(request: request, delegate: self, startImmediately: false)
                self._fullsizeConnection?.schedule(in: RunLoop.current, forMode: .common)
                self._fullsizeData = NSMutableData.init()
                self._fullsizeConnection?.start()
            }
            
            CFRunLoopRun()
        }
    }
    
    class func resetImageCache() {
        do {
            try FileManager.init().removeItem(atPath: IRGalleryPhoto.cacheDirectoryAddress())
        } catch {}
    }
    
    class func getCacheSize() -> UInt64 {
        var size: UInt64 = 0
        let fileEnumerator: FileManager.DirectoryEnumerator? = FileManager.default.enumerator(atPath: IRGalleryPhoto.cacheDirectoryAddress())
        
        for fileName in fileEnumerator! {
            let filePath = IRGalleryPhoto.cacheDirectoryAddress().appendingPathComponent(fileName as! String)
            do {
                let attrs: Dictionary = try FileManager.default.attributesOfItem(atPath: filePath)
                size += (attrs[FileAttributeKey.size] as! NSNumber).uint64Value
            } catch {}
        }
        
        return size
    }
    
    // MARK: - Progressive behavior properties
    // Enable / Disable caching
    open var caching: Bool = false
    // Cache time in seconds
    open var cacheTime: TimeInterval?
    
    open var enableProgressive: Bool = false
    
    open var imageOrientation: UIImage.Orientation?

    // MARK: - Private
    private func initializeAttributes() {
        cacheTime = IRDefaultCacheTimeValue
        caching = true
        imageOrientation = .up
        _imageSource = nil
        
        if _queue == nil {
            _queue = DispatchQueue.init(label: "com.irons.IRGalleryPhoto")
        }
    }
    
    private class func cacheDirectoryAddress() -> String {
        let path = NSSearchPathForDirectoriesInDomains(FileManager.SearchPathDirectory.cachesDirectory, .userDomainMask, true)
        let documentsDirectoryPath = path.first!
        return documentsDirectoryPath.appendingPathComponent("NYXProgressiveImageViewCache")
    }
    
    private func cachedImageSystemNameByUrl( _ url: URL?) -> String {
        return url?.absoluteString.md5 ?? ""
    }
    
    private func resetCacheByUrl( _ url: URL?) {
        do {
            try FileManager.init().removeItem(atPath: IRGalleryPhoto.cacheDirectoryAddress().appendingPathComponent(cachedImageSystemNameByUrl(url)))
        } catch {
            
        }
    }
    
    private func loadImageFromCache(cachedImagePath: String, isThumbSize: Bool) {
        let localImage = UIImage.init(contentsOfFile: cachedImagePath)
        
        DispatchQueue.main.async {
            if isThumbSize {
                NSLog("Thumb load from cache")
                self.thumbnail = localImage
                self.delegate?.galleryPhoto(photo: self, didLoadThumbnail: self.thumbnail!)
            } else {
                NSLog("Full load from cache")
                self.fullsize = localImage
                self.delegate?.galleryPhoto(photo: self, didLoadFullsize: self.fullsize!)
            }
        }
    }
    
    private func exifOrientationToiOSOrientation(_ exifOrientation: Int) -> UIImage.Orientation {
        var orientation = UIImage.Orientation.up
        switch exifOrientation {
        case 1:
            orientation = .up
        case 3:
            orientation = .down
        case 8:
            orientation = .left
        case 6:
            orientation = .right
        case 2:
            orientation = .upMirrored
        case 4:
            orientation = .downMirrored
        case 5:
            orientation = .leftMirrored
        case 7:
            orientation = .rightMirrored
        default: break
        }
        
        return orientation
    }
    
    // MARK: - NSURLConnectionDataDelegate
    func connection(_ connection: NSURLConnection, didReceive response: URLResponse) {
        Utilities.synchronized(self) {
            if connection == _fullsizeConnection {
                _imageSource = CGImageSourceCreateIncremental(nil)
                _imageWidth = -1
                _imageHeight = -1
                _expectedSize = response.expectedContentLength
            }
        }
    }
    
    func connection(_ connection: NSURLConnection, didReceive data: Data) {
        Utilities.synchronized(self) {
            NSLog("didReceiveData")
            
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = true
            }
            
            if connection == _thumbConnection {
                _thumbData?.append(data)
            } else if connection == _fullsizeConnection {
                _fullsizeData?.append(data)
            }
            
            if !self.enableProgressive || connection == _thumbConnection || _fullsizeData == nil || _imageSource == nil {
                return
            }
            
//            if connection == _thumbConnection {
//                // TODO
//            } else if connection == _fullsizeConnection {
//            }
            let len = _fullsizeData?.length
            CGImageSourceUpdateData(_imageSource!, _fullsizeData!, (len ?? 0 == _expectedSize) ? true : false)
            
            if _imageHeight > 0 && _imageWidth > 0 {
                let cgImage = CGImageSourceCreateImageAtIndex(_imageSource!, 0, nil)
                if (cgImage != nil) {
                    let partialHeight: size_t = cgImage!.height
                    let alpha = cgImage!.alphaInfo
                    let hasAlpha = (alpha == .first || alpha == .last || alpha == .premultipliedFirst || alpha == .premultipliedLast)
                    let alphaInfo: CGImageAlphaInfo = (hasAlpha ? .premultipliedFirst : .noneSkipFirst)
                    let bmContext = CGContext.init(data: nil, width: _imageWidth, height: _imageHeight, bitsPerComponent: 8, bytesPerRow: _imageWidth * 4, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: alphaInfo.rawValue)
                    
                    var imgTmp: CGImage?
                    if bmContext != nil {
                        bmContext?.draw(cgImage!, in: CGRect.init(x: 0, y: 0, width: _imageWidth, height: partialHeight))
                        imgTmp = bmContext?.makeImage()
                    }
                    
                    if imgTmp != nil {
                        let img = UIImage.init(cgImage: imgTmp!, scale: 1.0, orientation: imageOrientation ?? UIImage.Orientation.leftMirrored)
                        imgTmp = nil
                        
                        if connection == _thumbConnection {
                            thumbnail = img
                            DispatchQueue.main.async {
                                self.delegate?.galleryPhoto(photo: self, loadingThumbnail: self.thumbnail!)
                            }
                        } else if connection == _fullsizeConnection {
                            fullsize = img
                            DispatchQueue.main.async {
                                self.delegate?.galleryPhoto(photo: self, loadingFullsize: self.fullsize!)
                            }
                        }
                    }
                }
                
            } else {
                let dic = CGImageSourceCopyPropertiesAtIndex(_imageSource!, 0, nil)
                if dic != nil {
                    if let list = dic as NSDictionary? {
                        if let val = list[kCGImagePropertyPixelHeight as NSString] {
                            CFNumberGetValue((val as! CFNumber), CFNumberType.intType, &_imageHeight)
                        }
                        
                        if let val = list[kCGImagePropertyPixelWidth as NSString] {
                            CFNumberGetValue((val as! CFNumber), CFNumberType.intType, &_imageWidth)
                        }
                        
                        if let val = list[kCGImagePropertyOrientation as NSString] {
                            var orientation = 0
                            CFNumberGetValue((val as! CFNumber), CFNumberType.intType, &orientation)
                            imageOrientation = self.exifOrientationToiOSOrientation(orientation)
                            logger?.info("UIImageOrientation:\(self.imageOrientation?.rawValue ?? 0)")
                        } else {
                            imageOrientation = .up
                            NSLog("UIImageOrientation:%ld", imageOrientation!.rawValue as NSInteger)
                        }
                    }
                }
            }
        }
    }
    
    func connectionDidFinishLoading(_ connection: NSURLConnection) {
        logger?.info("load Finish")
        
        var _dataTemp: NSMutableData?
        if connection == _thumbConnection {
            _dataTemp = _thumbData
        } else if connection == _fullsizeConnection {
            _dataTemp = _fullsizeData
        }
        
        if _dataTemp != nil {
            DispatchQueue.main.async { [self] in
                let img = UIImage.init(data: _dataTemp! as Data)
                
                if caching != nil {
                    // Create cache directory if it doesn't exist
                    var isDir: ObjCBool = true
                    
                    let fileManager = FileManager.init()
                    
                    let cacheDir = IRGalleryPhoto.cacheDirectoryAddress()
                    if !fileManager.fileExists(atPath: cacheDir, isDirectory: &isDir) {
                        do {
                            try fileManager.createDirectory(atPath: cacheDir, withIntermediateDirectories: false, attributes: nil)
                        } catch {}
                    }
                    
                    var url: URL?
                    if connection == _thumbConnection {
                        url = URL.init(string: thumbUrl!)
                    } else if connection == _fullsizeConnection {
                        url = URL.init(string: fullsizeUrl!)
                    }
                    
                    let path = cacheDir.appendingPathComponent(self.cachedImageSystemNameByUrl(url))
                    do {
                        try _dataTemp?.write(to: URL.init(string: path)!, options: .atomicWrite)
                    } catch {}
                }
                
                
                
                if connection == _thumbConnection {
                    
                    thumbnail = img
                    isThumbLoading = false
                    hasThumbLoaded = true
                    
                    // cleanup
                    self.killThumbnailLoadObjects()
                    
                    self.delegate?.galleryPhoto(photo: self, didLoadThumbnail: self.thumbnail!)
                    
                } else if connection == _fullsizeConnection {
                    
                    fullsize = img
                    isFullsizeLoading = false
                    hasFullsizeLoaded = true
                    
                    // cleanup
                    self.killFullsizeLoadObjects()
                    
                    self.delegate?.galleryPhoto(photo: self, didLoadFullsize: self.fullsize!)
                    
                }
            }
        }
        
        if connection == _thumbConnection {
            isThumbLoading = false
            
            // cleanup
            self.killThumbnailLoadObjects()
            
        } else if connection == _fullsizeConnection {
            isFullsizeLoading = false
            
            // cleanup
            self.killFullsizeLoadObjects()
            
        }
        
        // turn off data indicator
        if !isFullsizeLoading && !isThumbLoading {
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
        
        CFRunLoopStop(CFRunLoopGetCurrent())
    }
    
    func connection(_ connection: NSURLConnection, didFailWithError error: Error) {
        NSLog("load fail")
        
        if connection == _thumbConnection {
            isThumbLoading = false
            
            // cleanup
            self.killThumbnailLoadObjects()
            
        } else if connection == _fullsizeConnection {
            isFullsizeLoading = false
            
            // cleanup
            self.killFullsizeLoadObjects()
            
        }
        
        CFRunLoopStop(CFRunLoopGetCurrent());

        // turn off data indicator
        if !isFullsizeLoading && !isThumbLoading {
            DispatchQueue.main.async {
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
    }
}
