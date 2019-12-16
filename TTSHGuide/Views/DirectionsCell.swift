//
//  DirectionsCell.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 23/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit
import ArcGIS

class DirectionsCell: UITableViewCell {
    
    @IBOutlet weak var directionImageView: UIImageView!
    @IBOutlet weak var directionLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        directionImageView.contentMode = .scaleAspectFit
        directionLabel.numberOfLines = 0
    }
    
    func configure(with direction: AGSDirectionManeuver) {
        directionLabel.text = direction.directionText
    }
}
