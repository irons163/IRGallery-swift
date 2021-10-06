//
//  ImagesTableViewCell.swift
//  demo
//
//  Created by Phil on 2020/8/25.
//  Copyright © 2020 Phil. All rights reserved.
//

import UIKit

class ImagesTableViewCell: UITableViewCell {

    @IBOutlet weak var thumbImageView: UIImageView!
    @IBOutlet weak var titleLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }
    
    public class func identifier() -> String {
        return String(describing: self)
    }
}
