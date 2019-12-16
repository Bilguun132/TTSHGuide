//
//  DirectionsView.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 23/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit
import ArcGIS

class DirectionsView: UIView, UITableViewDelegate, UITableViewDataSource {
    
    //MARK: - Properties
    
    @IBOutlet var contentView: UIView!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var navigationView: UIView!
    @IBOutlet weak var directionsTable: UITableView!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var distanceLabel: UILabel!
    @IBOutlet weak var directionTextLabel: UILabel!
    
    private var directions = [AGSDirectionManeuver]()
    private var currentDirections: AGSDirectionManeuver?
    private var currentIndex = 0
    weak var delegate: DirectionsViewDelegate?
    
    //MARK: - Lifecycle
    
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
        
        Bundle.main.loadNibNamed("DirectionsView", owner: self, options: nil)
        addSubview(contentView)
        directionsTable.register(UINib(nibName: "DirectionsCell", bundle: nil), forCellReuseIdentifier: "cell")
        directionsTable.dataSource = self
        directionsTable.delegate = self
        
    }
    
    func loadTable(route: AGSRoute) {
        timeLabel.text = "\(Int(route.totalTime)) min"
        distanceLabel.text = "\(String.init(format: "%.2f", route.totalLength)) m"
        self.directions = route.directionManeuvers
        currentDirections = directions.first
        directionsTable.reloadData()
    }
    
    
    //MARK: - Buttons
    
    @IBAction func didTapGo(_ sender: Any) {
        
        delegate?.didTapGo(directions: directions)
        directionTextLabel.text = directions[currentIndex].directionText
        switchViews()
    }
    
    @IBAction func previousDirectionTap(_ sender: Any) {
        currentIndex -= 1
        if currentIndex >= 0 {
            delegate?.didSelectDirection(direction: directions[currentIndex])
            directionTextLabel.text = directions[currentIndex].directionText
        }
        else {
            currentIndex = 0
        }
    }
    
    @IBAction func nextDirectionTap(_ sender: Any) {
        currentIndex += 1
        if currentIndex < directions.count {
            delegate?.didSelectDirection(direction: directions[currentIndex])
            directionTextLabel.text = directions[currentIndex].directionText
        }
        else {
            currentIndex = directions.count - 1
        }
    }
    
    @IBAction func closeTap(_ sender: Any) {
        self.topView.isHidden = !self.topView.isHidden
        self.topView.isUserInteractionEnabled = true
        self.navigationView.isHidden = !self.navigationView.isHidden
        delegate?.hideDirectionsView()
    }
    
    
    //MARK: - Support
    
    private func switchViews() {
        self.topView.isHidden = !self.topView.isHidden
        self.topView.isUserInteractionEnabled = false
        self.navigationView.isHidden = !self.navigationView.isHidden
    }
    
    //MARK: - Table
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return directions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! DirectionsCell
        cell.configure(with: directions[indexPath.row])
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let direction = directions[indexPath.row]
        delegate?.didSelectDirection(direction: direction)
    }
}

protocol DirectionsViewDelegate: class {
    func didSelectDirection(direction: AGSDirectionManeuver)
    func didTapGo(directions: [AGSDirectionManeuver])
    func hideDirectionsView()
}

extension DirectionsViewDelegate {
    
    func didTapGo(directions: [AGSDirectionManeuver]) {
        return
    }
    
    func hideDirectionsView() {
        return
    }
}

