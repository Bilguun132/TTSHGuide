//
//  NavDirectionView.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 2/5/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit

class NavDirectionView: UIView {
   
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var startLocationLabel: UITextField!
    @IBOutlet weak var endLocationLabel: UITextField!
    
    private var startLocation: SearchResultModel?
    private var endLocation: SearchResultModel?
    
    weak var delegate: NavDirectionsViewDelegate?
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setup()
    }
    
    //MARK: - Setup
    
    func setup() {
        
        Bundle.main.loadNibNamed("NavDirectionView", owner: self, options: nil)
        contentView.fixInView(self)
    }
    
    func configure(startLocation: SearchResultModel, endLocation: SearchResultModel) {
        self.startLocation = startLocation
        self.endLocation = endLocation
        startLocationLabel.text = startLocation.name
        endLocationLabel.text = endLocation.name
    }
    
    
    //MARK: - Buttons
    
    @IBAction func didTapBack(_ sender: Any) {
        delegate?.didTapBack()
    }
}

extension UIView
{
    func fixInView(_ container: UIView!) -> Void{
        self.translatesAutoresizingMaskIntoConstraints = false;
        self.frame = container.frame;
        container.addSubview(self);
        NSLayoutConstraint(item: self, attribute: .leading, relatedBy: .equal, toItem: container, attribute: .leading, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .trailing, relatedBy: .equal, toItem: container, attribute: .trailing, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .top, relatedBy: .equal, toItem: container, attribute: .top, multiplier: 1.0, constant: 0).isActive = true
        NSLayoutConstraint(item: self, attribute: .bottom, relatedBy: .equal, toItem: container, attribute: .bottom, multiplier: 1.0, constant: 0).isActive = true
    }
}


protocol NavDirectionsViewDelegate: class {
    func didTapBack()
}
