//
//  IRGalleryViewController.swift
//  IRGallery-swift
//
//  Created by Phil on 2020/8/25.
//  Copyright © 2020 Phil. All rights reserved.
//

import Foundation
import UIKit

let kThumbnailSize = 75
let kThumbnailSpacing = 4
let kCaptionPadding = 3
let kToolbarHeight = 45

class MyCollectionViewCell : UICollectionViewCell {
    var imageView: IRGalleryPhotoView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        var imageFrame = frame
        imageFrame.origin = CGPoint.zero
        
        self.imageView = IRGalleryPhotoView.init(frame: imageFrame)
        self.imageView.autoresizingMask = [AutoresizingMask.flexibleWidth, AutoresizingMask.flexibleHeight]
        self.imageView.autoresizesSubviews = true
        self.clipsToBounds = true
        self.contentView.addSubview(self.imageView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func prepareForReuse() {
        self.imageView.frame = self.contentView.frame
    }
}

class MyUICollectionViewFlowLayout: UICollectionViewFlowLayout {
    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        let attributes = super.layoutAttributesForElements(in: rect)
        var newAttributes = attributes
        for attribute: UICollectionViewLayoutAttributes in attributes! {
            if ((attribute.frame.origin.x + attribute.frame.size.width <= self.collectionViewContentSize.width) &&
                (attribute.frame.origin.y + attribute.frame.size.height <= self.collectionViewContentSize.height)) {
                newAttributes?.append(attribute)
            }
        }
        return newAttributes;
    }
}

public enum IRGalleryPhotoSize
{
    case IRGalleryPhotoSizeThumbnail
    case IRGalleryPhotoSizeFullsize
}

public enum IRGalleryPhotoSourceType
{
    case network
    case local
}

public protocol IRGalleryViewControllerSourceDelegate: NSObjectProtocol {
    func numberOfPhotosForPhotoGallery(gallery: IRGalleryViewController) -> Int
    func photoGallery(gallery: IRGalleryViewController, sourceTypeForPhotoAtIndex index: UInt) -> IRGalleryPhotoSourceType
    func photoGallery(gallery: IRGalleryViewController, captionForPhotoAtIndex index:UInt) -> String?
    func photoGallery(gallery: IRGalleryViewController, filePathForPhotoSize size: IRGalleryPhotoSize, index: UInt) -> String?
    func photoGallery(gallery: IRGalleryViewController, urlForPhotoSize size: IRGalleryPhotoSize, index: UInt) -> String?
    func photoGallery(gallery: IRGalleryViewController, isFavoriteForPhotoAtIndex index:UInt) -> Bool
    func photoGallery(gallery: IRGalleryViewController, loadThumbnailFromLocalAtIndex index:UInt) -> UIImage?
}

public extension IRGalleryViewControllerSourceDelegate {
    func photoGallery(gallery: IRGalleryViewController, captionForPhotoAtIndex index:UInt) -> String? { return nil }
    func photoGallery(gallery: IRGalleryViewController, filePathForPhotoSize size: IRGalleryPhotoSize, index: UInt) -> String? { return nil }
    func photoGallery(gallery: IRGalleryViewController, urlForPhotoSize size: IRGalleryPhotoSize, index: UInt) -> String? {  return nil }
    func photoGallery(gallery: IRGalleryViewController, isFavoriteForPhotoAtIndex index:UInt) -> Bool { return false }
    func photoGallery(gallery: IRGalleryViewController, loadThumbnailFromLocalAtIndex index:UInt) -> UIImage? {  return nil }
}

public protocol IRGalleryViewControllerDelegate: NSObjectProtocol {
    func photoGallery(gallery: IRGalleryViewController, deleteAtIndex index:UInt)
    func photoGallery(gallery: IRGalleryViewController, addFavorite isAddToFavortieList: Bool, index: UInt)
}

public extension IRGalleryViewControllerDelegate {
    func photoGallery(gallery: IRGalleryViewController, deleteAtIndex index:UInt) {}
    func photoGallery(gallery: IRGalleryViewController, addFavorite isAddToFavortieList: Bool, index: UInt) {}
}

public class IRGalleryViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, IRGalleryPhotoViewDelegate, IRGalleryPhotoDelegate, UIDocumentInteractionControllerDelegate {
    
    var currentIndex: NSInteger = 0
    public var startingIndex: NSInteger = 0
    weak var photoSource: IRGalleryViewControllerSourceDelegate?
    public private(set) var toolBar: UIToolbar?
    public private(set) var thumbsView: UIView?
    var galleryID: String?
    public var useThumbnailView: Bool?
    var beginsInThumbnailView: Bool?
    var hideTitle: Bool = false
    var scrollEnable: Bool = false
    public weak var delegate: IRGalleryViewControllerDelegate?
    var fileInteractionController: UIDocumentInteractionController?
    var preDisplayView: UIImageView?

    var isActive: Bool = false
    var isFullscreen: Bool = false
    var isScrolling: Bool = false
    var isThumbViewShowing: Bool = false
    
    var prevNextButtonSize: CGFloat = 0
    var scrollerRect: CGRect = CGRect.zero
    
    var container: UIView? // used as view for the controller
    var innerContainer: UIView? // sized and placed to be fullscreen within the container
    var toolbar: UIToolbar?
    var collectionView: UICollectionView?
    
    var photoLoaders: Dictionary<String, IRGalleryPhoto>?
    var barItems: [UIBarButtonItem]
    
    var deleteButton: UIBarButtonItem?
    var favoriteButton: UIBarButtonItem?
    var sendButton: UIBarButtonItem?
    
    var activityIndicator: UIActivityIndicatorView?
    
    override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: Bundle?) {
        
        self.currentIndex = 0
        self.startingIndex = 0
        self.toolBar = nil
        self.thumbsView = nil
        self.barItems = [UIBarButtonItem]()
        
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
        
        if self.responds(to: #selector(self.setNeedsStatusBarAppearanceUpdate)) {
            perform(#selector(self.setNeedsStatusBarAppearanceUpdate))
        }
        
        self.galleryID = String.init(format:"%p", self)

        // configure view controller
        self.hidesBottomBarWhenPushed = true
        
        // set defaults
        useThumbnailView = true
        hideTitle = false
        
        self.photoLoaders = Dictionary<String, IRGalleryPhoto>()
        
    }
    
    required init?(coder: NSCoder) {
        self.currentIndex = 0
        self.startingIndex = 0
        self.barItems = [UIBarButtonItem]()
        
        super.init(coder: coder)
        
        self.galleryID = String.init(format: "%p", self)
        // configure view controller
        self.hidesBottomBarWhenPushed = true
        // set defaults
        self.useThumbnailView = true
        self.hideTitle = false
        
        self.photoLoaders = Dictionary<String, IRGalleryPhoto>()
        
    }
    
    convenience init(photoSrc: IRGalleryViewControllerSourceDelegate, barItems: Array<UIBarButtonItem>) {
        self.init(photoSrc: photoSrc)
        
        self.barItems.removeAll()
        self.barItems.append(contentsOf: barItems)
    }
    
    public convenience init(photoSrc: IRGalleryViewControllerSourceDelegate) {
        
        self.init(nibName: nil, bundle: nil)
        
        self.photoSource = photoSrc
        
        self.container = UIView.init(frame: CGRect.zero)
        self.innerContainer = UIView.init(frame: CGRect.zero)
        
        self.collectionView = UICollectionView.init(frame: CGRect.init(x: self.view.bounds.origin.x, y: self.view.bounds.origin.y, width: self.view.bounds.size.width, height: self.view.bounds.size.height), collectionViewLayout: UICollectionViewFlowLayout())
        self.thumbsView = UIScrollView.init(frame: CGRect.zero)
        self.toolbar = UIToolbar.init(frame: CGRect.zero)
        self.container!.backgroundColor = UIColor.white
        
        self.collectionView!.delegate = self
        self.collectionView!.dataSource = self
        self.collectionView!.isPagingEnabled = true
        self.collectionView!.showsVerticalScrollIndicator = false
        self.collectionView!.showsHorizontalScrollIndicator = false
        self.collectionView?.contentInsetAdjustmentBehavior = .never
        
        // make things flexible
        self.container!.autoresizesSubviews = false
        self.innerContainer!.autoresizesSubviews = false
        self.collectionView!.autoresizesSubviews = false
        self.container!.autoresizingMask = [UIView.AutoresizingMask.flexibleWidth, UIView.AutoresizingMask.flexibleHeight]
        
        // set view
        self.view = self.container
        
        self.preDisplayView = UIImageView.init(frame: CGRect.zero)
        self.preDisplayView!.backgroundColor = .white
        self.preDisplayView!.isHidden = false
        self.preDisplayView!.contentMode = .scaleAspectFit
        
        // add items to their containers
        self.container!.addSubview(self.innerContainer!)
        self.innerContainer!.addSubview(self.collectionView!)
        self.innerContainer!.addSubview(self.toolbar!)
        
        self.positionInnerContainer()
        self.positionCollectionView()
        self.positionToolbar()
        
        self.createToolbarItems()
        self.prevNextButtonSize = 30
        
        // set buttons on the toolbar.
        var items = Array.init(self.barItems)
        var i = 1
        for _ in 1..<self.barItems.count {
            let space = UIBarButtonItem.init(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
            items.insert(space, at: i)
            i += 2
        }
        self.toolbar!.setItems(items, animated: false)
        self.initMyFavorites()
        self.reloadGallery()
        
        if self.currentIndex == -1 {
            self.next()
        }
        
        activityIndicator?.stopAnimating()
        activityIndicator = nil
        
    }
    
    func createToolbarItems() {
        
        // create buttons for toolbar
        let doDeleteButton = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 40, height: 50))
        var image = UIImage.imageNamedForCurrentBundle(name: "btn_trash")
        image = Utilities.image(image!, scaledToSize: CGSize.init(width: 20, height: 26.67))
        doDeleteButton.setImage(image, for: .normal)
        image = UIImage.imageNamedForCurrentBundle(name: "btn_trash")
        image = Utilities.image(image!, scaledToSize: CGSize.init(width: 20, height: 26.67))
        doDeleteButton.setImage(image, for: .highlighted)
        doDeleteButton.addTarget(self, action: #selector(deleteClk), for: .touchUpInside)
        self.deleteButton = UIBarButtonItem.init(customView: doDeleteButton)
        
        let doFavoriteButton = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 40, height: 50))
        image = UIImage.imageNamedForCurrentBundle(name: "btn_video_heart")
        image = Utilities.image(image!, scaledToSize: CGSize.init(width: 21.4, height: 20))
        doFavoriteButton.setImage(image, for: .normal)
        image = UIImage.imageNamedForCurrentBundle(name: "btn_video_heart")
        image = Utilities.image(image!, scaledToSize: CGSize.init(width: 21.4, height: 20))
        doFavoriteButton.setImage(image, for: .highlighted)
        image = UIImage.imageNamedForCurrentBundle(name: "btn_heart_h")
        image = Utilities.image(image!, scaledToSize: CGSize.init(width: 21.4, height: 20))
        doFavoriteButton.setImage(image, for: .selected)
        doFavoriteButton.addTarget(self, action: #selector(addToMyFavoritesClk), for: .touchUpInside)
        self.favoriteButton = UIBarButtonItem.init(customView: doFavoriteButton)
        
        let doSendButton = UIButton.init(frame: CGRect.init(x: 0, y: 0, width: 40, height: 50))
        image = UIImage.imageNamedForCurrentBundle(name: "btn_video_send")
        image = Utilities.image(image!, scaledToSize: CGSize.init(width: 25, height: 25))
        doSendButton.setImage(image, for: .normal)
        image = UIImage.imageNamedForCurrentBundle(name: "btn_video_send")
        image = Utilities.image(image!, scaledToSize: CGSize.init(width: 25, height: 25))
        doSendButton.setImage(image, for: .highlighted)
        doSendButton.addTarget(self, action: #selector(shareClk), for: .touchUpInside)
        self.sendButton = UIBarButtonItem.init(customView: doSendButton)
        
        barItems.insert(self.sendButton!, at: 0)
        barItems.insert(self.favoriteButton!, at: 0)
        barItems.insert(self.deleteButton!, at: 0)
        
    }
    
    func destroyViews() {
        
        for pair in self.photoLoaders ?? [:] {
            let photoLoader: IRGalleryPhoto = pair.value
            photoLoader.delegate = nil
            photoLoader.unloadFullsize()
            photoLoader.unloadThumbnail()
        }
        self.photoLoaders?.removeAll()

    }

    func reloadGallery() {
        self.currentIndex = self.startingIndex
        self.isThumbViewShowing = false
        
        // remove the old
        self.destroyViews()
        
        NSLog("Load start");
        // build the new
        if self.photoSource?.numberOfPhotosForPhotoGallery(gallery: self) ?? 0 > 0 {
            self.layoutViews()
        }
    }

    func buildGalleryViews() {
        NSLog("Load start");
        // build the new
        if self.photoSource?.numberOfPhotosForPhotoGallery(gallery: self) ?? 0 > 0 {
            NSLog("buildView Finish");
            self.layoutViews()
            NSLog("reloadGallery Finish");
        }
    }
    
    func layoutViews() {
        NSLog("layoutViews go");
        self.positionInnerContainer()
        self.positionToolbar()
        self.updateScrollSize()
        self.updateCaption()
        self.resizeImageViewsWithRect(rect: self.collectionView!.frame)
        self.layoutButtons()
        self.moveScrollerToCurrentIndexWithAnimation(animation: false)
        NSLog("layoutViews end")
    }
    
    func updateScrollSize() {
        let contentWidth = self.collectionView!.frame.size.width *
            CGFloat((self.photoSource?.numberOfPhotosForPhotoGallery(gallery: self) ?? 0))
            
        self.collectionView?.contentSize = CGSize.init(width: contentWidth, height: self.collectionView!.frame.size.height - 80)
    }
    
    func updateCaption() {
        if (self.photoSource?.numberOfPhotosForPhotoGallery(gallery: self) ?? 0) > 0 {
            let caption = self.photoSource?.photoGallery(gallery: self, captionForPhotoAtIndex: UInt(self.currentIndex))
            self.navigationItem.title = caption
        }
    }
    
    func resizeImageViewsWithRect(rect: CGRect){
        self.preDisplayView?.frame = rect
    }
    
    func layoutButtons() {
        let buttonWidth = roundf( Float(self.toolbar!.frame.size.width / CGFloat(self.barItems.count) - self.prevNextButtonSize * 0.5));
        
        // loop through all the button items and give them the same width
        let count: Int = self.barItems.count
        for i in 0 ..< count {
            let btn = self.barItems[i]
            btn.width = CGFloat(buttonWidth);
        }
        self.toolbar?.setNeedsLayout()
    }
    
    func moveScrollerToCurrentIndexWithAnimation(animation: Bool) {
        let xp = self.collectionView!.frame.size.width * CGFloat(self.currentIndex)
        self.collectionView?.scrollRectToVisible(CGRect.init(x: xp, y: 0, width: self.collectionView!.frame.size.width, height: self.collectionView!.frame.size.height), animated: animation)
        self.isScrolling = animation
    }

//////////////////////
////// Collection
//////////////////////
    let myFavoritesCellIdentifier = "MyCollectionCell"
    
    func initMyFavorites() {
        
        collectionView?.register(MyCollectionViewCell.self, forCellWithReuseIdentifier: myFavoritesCellIdentifier)
        collectionView?.backgroundColor = .clear
        collectionView?.showsHorizontalScrollIndicator = false
        (collectionView?.collectionViewLayout as? UICollectionViewFlowLayout)?.minimumInteritemSpacing = CGFloat.greatestFiniteMagnitude
        (collectionView?.collectionViewLayout as? UICollectionViewFlowLayout)?.scrollDirection = .horizontal
        (collectionView?.collectionViewLayout as? UICollectionViewFlowLayout)?.minimumLineSpacing = 0

    }
    
    func next() {
        
        let numberOfPhotos = photoSource?.numberOfPhotosForPhotoGallery(gallery: self) ?? 0
        let nextIndex = currentIndex + 1
        if nextIndex <= numberOfPhotos {
            gotoImageByIndex(UInt(nextIndex), animated: false)
        }
        
    }

    func previous() {
        
        let prevIndex = currentIndex - 1
        gotoImageByIndex(UInt(prevIndex), animated: false)

    }

// MARK: - Private Methods
    func positionInnerContainer() {
        self.innerContainer!.translatesAutoresizingMaskIntoConstraints = false
        
        let leadingConstraint = NSLayoutConstraint.init(item: self.innerContainer as Any, attribute: .leading, relatedBy: .equal, toItem: self.innerContainer?.superview, attribute: .leading, multiplier: 1.0, constant: 0)
        let trailingConstraint = NSLayoutConstraint.init(item: self.innerContainer as Any, attribute: .trailing, relatedBy: .equal, toItem: self.innerContainer?.superview, attribute: .trailing, multiplier: 1.0, constant: 0)
        let bottomConstraint = NSLayoutConstraint.init(item: self.innerContainer as Any, attribute: .bottom, relatedBy: .equal, toItem: self.innerContainer?.superview, attribute: .bottom, multiplier: 1.0, constant: 0)
        let topConstraint = NSLayoutConstraint.init(item: self.innerContainer as Any, attribute: .top, relatedBy: .equal, toItem: self.innerContainer?.superview, attribute: .top, multiplier: 1.0, constant: 0)
        
        leadingConstraint.isActive = true
        trailingConstraint.isActive = true
        topConstraint.isActive = true
        bottomConstraint.isActive = true
    }

    func positionCollectionView() {
        self.collectionView?.translatesAutoresizingMaskIntoConstraints = false
        
        let leadingConstraint = NSLayoutConstraint.init(item: self.collectionView as Any, attribute: .leading, relatedBy: .equal, toItem: self.collectionView?.superview, attribute: .leading, multiplier: 1.0, constant: 0)
        let trailingConstraint = NSLayoutConstraint.init(item: self.collectionView as Any, attribute: .trailing, relatedBy: .equal, toItem: self.collectionView?.superview, attribute: .trailing, multiplier: 1.0, constant: 0)
        let bottomConstraint = NSLayoutConstraint.init(item: self.collectionView as Any, attribute: .bottom, relatedBy: .equal, toItem: self.collectionView?.superview, attribute: .bottom, multiplier: 1.0, constant: 0)
        let topConstraint = NSLayoutConstraint.init(item: self.collectionView as Any, attribute: .top, relatedBy: .equal, toItem: self.collectionView?.superview, attribute: .top, multiplier: 1.0, constant: 0)
        
        leadingConstraint.isActive = true
        trailingConstraint.isActive = true
        topConstraint.isActive = true
        bottomConstraint.isActive = true
    }
    
    func positionToolbar() {
        self.toolbar?.translatesAutoresizingMaskIntoConstraints = false
        
        let leadingConstraint = NSLayoutConstraint.init(item: self.toolbar as Any, attribute: .leading, relatedBy: .equal, toItem: self.toolbar?.superview, attribute: .leading, multiplier: 1.0, constant: 0)
        let trailingConstraint = NSLayoutConstraint.init(item: self.toolbar as Any, attribute: .trailing, relatedBy: .equal, toItem: self.toolbar?.superview, attribute: .trailing, multiplier: 1.0, constant: 0)
        let bottomConstraint = NSLayoutConstraint.init(item: self.toolbar as Any, attribute: .bottom, relatedBy: .equal, toItem: self.toolbar?.superview, attribute: .bottom, multiplier: 1.0, constant: 0)
        let topConstraint: NSLayoutConstraint
        if #available(iOS 11.0, *) {
            topConstraint = self.toolbar!.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.bottomAnchor)
            topConstraint.constant = -44
        } else {
            topConstraint = NSLayoutConstraint.init(item: self.toolbar as Any, attribute: .top, relatedBy: .equal, toItem: self.view, attribute: .bottom, multiplier: 1.0, constant: -44)
        }
        
        
        leadingConstraint.isActive = true
        trailingConstraint.isActive = true
        topConstraint.isActive = true
        bottomConstraint.isActive = true
    }
    
    public func gotoImageByIndex(_ index: UInt, animated: Bool) {
        let numPhotos = photoSource?.numberOfPhotosForPhotoGallery(gallery: self)
        
        // constrain index within our limits
        var newIndex: NSInteger = 0
        if index >= numPhotos ?? 0 {
            newIndex = numPhotos ?? 0 - 1
        }
        
        if numPhotos == 0 {
            // no photos!
            currentIndex = -1
        } else {
            self.unloadFullsizeImageWithIndex(index)
            
            currentIndex = newIndex
            self.moveScrollerToCurrentIndexWithAnimation(animation: animated)
            self.updateTitle()
            
            if !animated {
                self.preloadThumbnailImages()
                self.loadFullsizeImageWithIndex(UInt(newIndex))
            }
        }
        self.updateButtons()
        self.updateCaption()
    }
    
    func updateTitle() {

    }

    func updateButtons() {
        if photoSource?.numberOfPhotosForPhotoGallery(gallery: self) ?? 0 > 0 {
            if ((photoSource?.photoGallery(gallery: self, isFavoriteForPhotoAtIndex: UInt(currentIndex))) != nil) {
                let isFavorite = photoSource?.photoGallery(gallery: self, isFavoriteForPhotoAtIndex: UInt(currentIndex))
                (favoriteButton?.customView as? UIButton)?.isSelected = isFavorite ?? false
            }
        }
    }
    
    // MARK: - Image Loading
    func preloadThumbnailImages() {
        let index = currentIndex
        let count = photoSource?.numberOfPhotosForPhotoGallery(gallery: self)
        
        // make sure the images surrounding the current index have thumbs loading
        let nextIndex = index + 1
        let prevIndex = index - 1
        
        // the preload count indicates how many images surrounding the current photo will get preloaded.
        // a value of 2 at maximum would preload 4 images, 2 in front of and two behind the current image.
        let preloadCount = 1
        
        var photo = photoLoaders?["\(index)"]
        
        if photo != nil {
            self.loadThumbnailImageWithIndex(UInt(index))
            photo = photoLoaders?["\(index)"]
        }
        
        if !(photo?.hasThumbLoaded ?? false) && !(photo?.isThumbLoading ?? false) {
            photo?.loadThumbnail()
        }
        
        var curIndex = prevIndex
        let invalidIndex = -1
        
        while curIndex > invalidIndex && curIndex > (prevIndex - preloadCount) {
            photo = photoLoaders?["\(curIndex)"]
            
            if (photo == nil) {
                self.loadThumbnailImageWithIndex(UInt(curIndex))
                photo = photoLoaders?["\(curIndex)"]
            }
            
            if !(photo?.hasThumbLoaded ?? false) && !(photo?.isThumbLoading ?? false) {
                photo?.loadThumbnail()
            }
            
            curIndex-=1
        }
        
        curIndex = nextIndex
        
        while curIndex < count ?? 0 && curIndex < nextIndex + preloadCount {
            photo = photoLoaders?["\(curIndex)"]
            
            if (photo == nil) {
                self.loadThumbnailImageWithIndex(UInt(curIndex))
                photo = photoLoaders?["\(curIndex)"]
            }
            
            if !(photo?.hasThumbLoaded ?? false) && !(photo?.isThumbLoading ?? false) {
                photo?.loadThumbnail()
            }
            
            curIndex+=1
        }
        
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }
    
    func loadThumbnailImageWithIndex(_ index: UInt) {
        var photo = photoLoaders?["\(index)"]
        
        if photo == nil {
            photo = createGalleryPhotoForIndex(index)
        }
        
        photo?.loadThumbnail()
    }

    func loadFullsizeImageWithIndex(_ index: UInt) {
        var photo = photoLoaders?["\(index)"]
        
        if photo == nil {
            photo = createGalleryPhotoForIndex(index)
        }
        
        photo?.loadFullsize()
    }
    
    func unloadFullsizeImageWithIndex(_ index: UInt) {
        if index < photoSource?.numberOfPhotosForPhotoGallery(gallery: self) ?? 0 {
            let loader = photoLoaders?["\(index)"]
            loader?.unloadFullsize()
            
            var photoView: IRGalleryPhotoView?
            for indexPath in collectionView!.indexPathsForVisibleItems {
                if(indexPath.row == index){
                    photoView = (collectionView?.cellForItem(at: indexPath) as? MyCollectionViewCell)?.imageView
                    break;
                }
            }
            
            if photoView != nil {
                return
            }
            
            photoView?.imageView?.image = loader?.thumbnail
        }
    }
    
    func createGalleryPhotoForIndex(_ index: UInt) -> IRGalleryPhoto {
        let sourceType = photoSource?.photoGallery(gallery: self, sourceTypeForPhotoAtIndex: index)
        var photo: IRGalleryPhoto?
        var thumbPath: String?
        var fullsizePath: String?
        
        if sourceType == IRGalleryPhotoSourceType.local {
            thumbPath = photoSource?.photoGallery(gallery: self, filePathForPhotoSize: .IRGalleryPhotoSizeThumbnail, index: index)
            fullsizePath = photoSource?.photoGallery(gallery: self, filePathForPhotoSize: .IRGalleryPhotoSizeFullsize, index: index)
            photo = IRGalleryPhoto.init(thumbnailPath: thumbPath!, fullsizePath: fullsizePath!, delegate: self)
        } else {
            thumbPath = photoSource?.photoGallery(gallery: self, urlForPhotoSize: .IRGalleryPhotoSizeThumbnail, index: index)
            fullsizePath = photoSource?.photoGallery(gallery: self, urlForPhotoSize: .IRGalleryPhotoSizeFullsize, index: index)
            photo = IRGalleryPhoto.init(thumbnailUrl: thumbPath!, fullsizeUrl: fullsizePath!, delegate: self)
        }
        
        // assign the photo index
        photo?.tag = index
        
        // store it
        photoLoaders?["\(index)"] = photo
        
        return photo!
    }
    
    // MARK: - IRGalleryPhoto Delegate Methods
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        
        isScrolling = true
        
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        
        if !decelerate {
            scrollingHasEnded()
        }
        
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        
        scrollingHasEnded()
        
    }
    
    func scrollingHasEnded() {
        
        NSLog("scrollingHasEnded start")
        isScrolling = false
        
        guard let width = collectionView?.frame.size.width, width != 0, let offsetX = collectionView?.contentOffset.x, offsetX >= 0 else {
            return
        }
        
        let newIndex = UInt(floor(offsetX / width))
        
        if newIndex == currentIndex {
            return
        }
        
        unloadFullsizeImageWithIndex(newIndex)
        currentIndex = NSInteger(newIndex)
        
        updateCaption()
        updateTitle()
        updateButtons()
        loadFullsizeImageWithIndex(UInt(currentIndex))
        preloadThumbnailImages()
        
        NSLog("scrollingHasEnded finish")
        
    }
    
    // MARK: - IRGalleryPhoto Delegate Methods
    func galleryPhoto(photo: IRGalleryPhoto, didLoadThumbnail image: UIImage) {
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }
    
    func galleryPhoto(photo: IRGalleryPhoto, didLoadFullsize image: UIImage) {
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }
    
    func galleryPhoto(photo: IRGalleryPhoto, willLoadThumbnailFromUrl url: String) {
        
    }
    
    func galleryPhoto(photo: IRGalleryPhoto, willLoadThumbnailFromPath path: String) {
        
    }
    
    func galleryPhoto(photo: IRGalleryPhoto, loadingFullsize image: UIImage) {
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }
    
    func galleryPhoto(photo: IRGalleryPhoto, loadingThumbnail image: UIImage) {
        DispatchQueue.main.async {
            self.collectionView?.reloadData()
        }
    }
    
    func galleryPhotoLoadThumbnailFromLocal(photo: IRGalleryPhoto) -> UIImage? {
        return photoSource?.photoGallery(gallery: self, loadThumbnailFromLocalAtIndex: photo.tag)
    }
    
    public func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return self.photoSource?.numberOfPhotosForPhotoGallery(gallery: self) ?? 0
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: myFavoritesCellIdentifier, for: indexPath) as! MyCollectionViewCell
        cell.imageView.zoomScale = 1
        cell.imageView.photoDelegate = self
        cell.imageView.activity?.startAnimating()

        // only set the fullsize image if we're currently on that image
        if currentIndex == indexPath.row {
            let photo = photoLoaders?["\(indexPath.row)"]
            cell.imageView.imageView?.image = photo?.fullsize
            
            if currentIndex == preDisplayView?.tag && (photo?.thumbnail == nil) {
                cell.imageView.thumbView?.image = preDisplayView?.image
            } else {
                cell.imageView.thumbView?.image = photo?.thumbnail
            }
            
        } else { // otherwise, we don't need to keep this image around
            let photo = photoLoaders?["\(indexPath.row)"]
            photo?.unloadFullsize()
            
            cell.imageView.imageView?.image = photo?.fullsize
            cell.imageView.thumbView?.image = photo?.thumbnail
        }

        if (cell.imageView.imageView?.image != nil) || (cell.imageView.thumbView?.image != nil) {
            cell.imageView.activity?.stopAnimating()
        }

        return cell;
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        updateItemSize()
    }
    
    func updateItemSize() {
        
        let height = view.window?.windowScene?.statusBarManager?.statusBarFrame.height ?? 0
        var newFrame = collectionView?.frame
        newFrame?.origin.y = self.view.bounds.origin.y + (self.navigationController?.navigationBar.frame.size.height ?? 0) + height
        newFrame?.size.height = self.view.bounds.size.height - (self.navigationController?.navigationBar.frame.size.height ?? 0) - height - CGFloat(kToolbarHeight)
        newFrame?.size.width = self.view.bounds.size.width

        (collectionView?.collectionViewLayout as? UICollectionViewFlowLayout)?.sectionInset = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        
        (collectionView?.collectionViewLayout as? UICollectionViewFlowLayout)?.itemSize = newFrame?.size ?? CGSize.zero
        
        collectionView?.collectionViewLayout.invalidateLayout()
        
    }
    
}

// MARK: - Actions
extension IRGalleryViewController {
    
    @objc
    func deleteClk() {
        
        let alert = UIAlertController(title: "Confirm", message: "Do you want to delete this photo?", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { action in
            self.delete()
        }))
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(alert, animated: true)
        
    }
    
    func delete() {
        
        delegate?.photoGallery(gallery: self, deleteAtIndex: UInt(currentIndex))
        collectionView?.delegate = nil
        photoSource = nil
        navigationController?.popViewController(animated: true)
        
    }
    
    @objc
    func addToMyFavoritesClk() {
        
        guard let button = favoriteButton?.customView as? UIButton else { return }
        
        if button.isSelected {
            button.isSelected = false
        } else {
            button.isSelected = true
        }
        
        delegate?.photoGallery(gallery: self, addFavorite: button.isSelected, index: UInt(currentIndex))
        
    }
    
    @objc
    func shareClk(sender: Any) {
        
        let photo = photoLoaders?["\(currentIndex)"]
        shareByFileURLStringWithPath(file: photo?.fullsizeUrl ?? "")
        
    }
    
    func shareByFileURLStringWithPath(file: String) {
        
        fileInteractionController = UIDocumentInteractionController(url: URL(fileURLWithPath: file))
        fileInteractionController?.delegate = self
        fileInteractionController?.presentOpenInMenu(from: CGRect.zero, in: self.view, animated: true)
        
    }
    
}

// MARK: - IRGalleryPhotoViewDelegate
extension IRGalleryViewController {
    
    func didTapPhotoView(photoView: IRGalleryPhotoView) {
        NSLog("didTapPhotoView")
    }
    
}

// MARK: - UIDocumentInteractionController
extension IRGalleryViewController {
    
    public func documentInteractionControllerViewControllerForPreview(_ controller: UIDocumentInteractionController) -> UIViewController {
        return self
    }
    
    public func documentInteractionControllerViewForPreview(_ controller: UIDocumentInteractionController) -> UIView? {
        return self.view
    }
    
    public func documentInteractionControllerRectForPreview(_ controller: UIDocumentInteractionController) -> CGRect {
        return self.view.frame
    }
    
}

