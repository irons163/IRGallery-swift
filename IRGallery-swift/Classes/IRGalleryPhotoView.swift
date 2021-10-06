//
//  IRGalleryPhotoView.swift
//  IRGallery-swift
//
//  Created by Phil on 2020/8/25.
//  Copyright © 2020 Phil. All rights reserved.
//

import Foundation
import UIKit

protocol IRGalleryPhotoViewDelegate: NSObjectProtocol {
    // indicates single touch and allows controller repsond and go toggle fullscreen
    func didTapPhotoView(photoView: IRGalleryPhotoView)
}

class IRGalleryPhotoView: UIScrollView, UIScrollViewDelegate {
    var mainView: UIView!
    var isZoomed: Bool?
    var tapTimer: Timer?
    var widthConstraint, heightConstraint, thumbwidthConstraint, thumbheightConstraint: NSLayoutConstraint!
    
    weak var photoDelegate:IRGalleryPhotoViewDelegate?
    public private(set) var imageView: UIImageView!
    public private(set) var button: UIButton?
    public private(set) var activity: UIActivityIndicatorView!
    public private(set) var thumbView: UIImageView!
    
    override var frame: CGRect {
        didSet {
            thumbwidthConstraint?.constant =  frame.size.width
            widthConstraint?.constant = thumbwidthConstraint.constant
            thumbheightConstraint?.constant = frame.size.height
            heightConstraint?.constant = thumbheightConstraint.constant
            
            self.setNeedsUpdateConstraints()
        }
    }

    func killActivityIndicator() {
        
    }

//    // inits this view to have a button over the image
//    init(frame: CGRect, target: Any, action: Selector) {
//        super.init(frame: frame)
//
//        setupUI()
//    }
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

extension IRGalleryPhotoView {
    
    func setupUI() {
        
        self.isUserInteractionEnabled = true
        self.clipsToBounds = true
        self.delegate = self
        self.contentMode = .center
        self.maximumZoomScale = 3.0
        self.minimumZoomScale = 1.0
        self.decelerationRate = DecelerationRate(rawValue: 0.85)
        
        self.contentSize = CGSize(width: frame.size.width, height: frame.size.height)
        
        mainView = UIView.init(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        mainView.contentMode = .scaleAspectFit
        thumbView = UIImageView.init(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        thumbView.contentMode = .scaleAspectFit
        imageView = UIImageView.init(frame: CGRect(x: 0, y: 0, width: frame.size.width, height: frame.size.height))
        imageView.contentMode = .scaleAspectFit
        
        mainView.addSubview(thumbView)
        mainView.addSubview(imageView)
        self.addSubview(mainView)
        
        activity = UIActivityIndicatorView(style: .medium)
        activity.center = CGPoint(x: frame.width * 0.5, y: frame.height * 0.5)
        self.addSubview(activity)
        
        setupConstraint(with: mainView)
        setupConstraint(with: thumbView)
        setupConstraint(with: imageView)
        
        widthConstraint = NSLayoutConstraint(item: imageView!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: frame.width)
        heightConstraint = NSLayoutConstraint(item: imageView!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: frame.height)
        widthConstraint.isActive = true
        heightConstraint.isActive = true
        
        thumbwidthConstraint = NSLayoutConstraint(item: thumbView!, attribute: .width, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: frame.width)
        thumbheightConstraint = NSLayoutConstraint(item: thumbView!, attribute: .height, relatedBy: .equal, toItem: nil, attribute: .notAnAttribute, multiplier: 1.0, constant: frame.height)
        thumbwidthConstraint.isActive = true
        thumbheightConstraint.isActive = true
        
    }
    
    func setupConstraint(with view: UIView) {
        
        view.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint(item: view, attribute: .leading, relatedBy: .equal, toItem: view.superview, attribute: .leading, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: view, attribute: .trailing, relatedBy: .equal, toItem: view.superview, attribute: .trailing, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: view, attribute: .bottom, relatedBy: .equal, toItem: view.superview, attribute: .bottom, multiplier: 1, constant: 0).isActive = true
        NSLayoutConstraint(item: view, attribute: .top, relatedBy: .equal, toItem: view.superview, attribute: .top, multiplier: 1, constant: 0).isActive = true
        
    }
    
}
