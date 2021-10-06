//
//  ViewController.swift
//  demo
//
//  Created by Phil on 2020/8/25.
//  Copyright © 2020 Phil. All rights reserved.
//

import UIKit
import IRGallery_swift

class ViewController: UIViewController, UITableViewDataSource, UITableViewDelegate, IRGalleryViewControllerSourceDelegate, IRGalleryViewControllerDelegate {
    
    @IBOutlet weak var tableView: UITableView!
    
    var images: [Any] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView?.register(UINib.init(nibName: ImagesTableViewCell.identifier(), bundle: nil), forCellReuseIdentifier: ImagesTableViewCell.identifier())
        
        images = ["1.png", "2.png", "3.png"]
    }

    //UITableViewDataSource
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return images.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell: ImagesTableViewCell = tableView.dequeueReusableCell(withIdentifier: ImagesTableViewCell.identifier()) as! ImagesTableViewCell
        let image: UIImage = UIImage.init(named: images[indexPath.row] as! String)!
        cell.thumbImageView.image = image;
        cell.titleLabel.text = NSString.init(format: "%d", indexPath.row + 1) as String
        return cell;
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let galleryVC = IRGalleryViewController.init(photoSrc: self)
        galleryVC.delegate = self
        galleryVC.startingIndex = indexPath.row
        galleryVC.useThumbnailView = false
        galleryVC.gotoImageByIndex(UInt(indexPath.row), animated: false)
        self.navigationController?.pushViewController(galleryVC, animated: true)
    }

    // MARK: - IRGalleryViewControllerDelegate

    func numberOfPhotosForPhotoGallery(gallery: IRGalleryViewController) -> Int {
        return images.count
    }
    
    func photoGallery(gallery: IRGalleryViewController, sourceTypeForPhotoAtIndex index: UInt) -> IRGalleryPhotoSourceType {
        return .local
    }
    
    func photoGallery(gallery: IRGalleryViewController, captionForPhotoAtIndex index: UInt) -> String? {
        let filename = "\(index + 1)"
        return filename
    }
    
    func photoGallery(gallery: IRGalleryViewController, filePathForPhotoSize size: IRGalleryPhotoSize, index: UInt) -> String? {
        let path = Bundle.main.url(forResource: images[Int(index)] as! String?, withExtension: nil)?.path
        return path
    }
    
    func photoGallery(gallery: IRGalleryViewController, urlForPhotoSize size: IRGalleryPhotoSize, index: UInt) -> String? {
        return nil
    }
    
    func photoGallery(gallery: IRGalleryViewController, isFavoriteForPhotoAtIndex index: UInt) -> Bool {
        return false
    }

}

