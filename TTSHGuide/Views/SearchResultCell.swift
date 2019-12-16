//
//  SearchResultCell.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 18/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit

class SearchResultCell: UITableViewCell {
    @IBOutlet var resultNameLabel: UILabel!
    
    var model: SearchResultModel?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        selectionStyle = .none
    }
    
    func configure(with model: SearchResultModel) {
        self.model = model
        resultNameLabel.text = model.name
    }
    
}
