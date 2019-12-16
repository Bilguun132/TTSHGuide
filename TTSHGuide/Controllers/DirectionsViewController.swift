//
//  DirectionsViewController.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 22/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit
import SVProgressHUD
import SwiftyJSON
import ArcGIS

class DirectionsViewController: UIViewController {
    
    
    //MARK: - Properties
    
    @IBOutlet weak var walkButton: UIButton!
    @IBOutlet weak var resultsTableView: UITableView!
    @IBOutlet weak var startSearchBar: UISearchBar!
    @IBOutlet weak var endSearchBar: UISearchBar!
    @IBOutlet weak var topSpaceTableConstraint: NSLayoutConstraint!
    
    private var selectedSearchType: SearchType = SearchType.All
    private var listOfSearchResults: [[SearchResultModel]]  = [[],[],[],[],[],[],[]]
    private let sectionHeaderHeight: CGFloat = 25
    private var selectedModeButton: UIButton?
    private var selectedMode: TransportType! = .Walk
    private var selectedSearchBar: SearchBar = SearchBar.Start
    private var startLocation: SearchResultModel?
    private var endLocation: SearchResultModel?
    private var isLoading: Bool = false {
        didSet {
            if isLoading {SVProgressHUD.show()}
            else {SVProgressHUD.dismiss()}
        }
    }
    
    private var didSelectSearchResult = false
    
    weak var delegate: DirectionsViewControllerDelegate?
    
    var currentLocation: AGSPoint?
    
    enum SearchBar: Int {
        case Start = 0, End
    }
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        selectedModeButton = walkButton
        startSearchBar.delegate = self
        endSearchBar.delegate = self
        SearchService.shared.delegate = self
        setupTableViews()
        
        if let currentLocation = self.currentLocation {
            startLocation = SearchResultModel(coordinates: currentLocation, name: "Current Location", floor: "1")
            startSearchBar.text = "Current Location"
        }

        // Do any additional setup after loading the view.
    }

    
    //MARK: - Buttons
    
    @IBAction func close(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func selectTransportMode(_ sender: UIButton) {
        if let selectedModeButton = selectedModeButton {
            selectedModeButton.isSelected = false
        }
        
        selectedModeButton = sender
        selectedModeButton?.isSelected = true
        if selectedModeButton != nil {
            selectedMode = TransportType.init(rawValue: selectedModeButton!.tag)
        }
    }
}


//MARK: - Search

extension DirectionsViewController: UISearchBarDelegate, UISearchDisplayDelegate, SearchServiceDelegate {
    
    func updateSearchResults(listOfSearchResults: [[SearchResultModel]]) {
        if didSelectSearchResult {return}
        self.listOfSearchResults = listOfSearchResults
        resultsTableView.reloadData()
        resultsTableView.isHidden = false
        SVProgressHUD.dismiss()
    }
    
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if !searchText.isEmpty && searchText.count > 1 {
            if searchBar.tag == 0 {
                selectedSearchBar = SearchBar.Start
                topSpaceTableConstraint.constant = 0
                print("start search bar")
            }
            else {
                topSpaceTableConstraint.constant = 50
                selectedSearchBar = SearchBar.End
                print("start end bar")
            }
            print(searchText)
            SearchService.shared.clearSearchResults()
            getSearchResults(searchText: searchText.uppercased())
        }
        if searchText.isEmpty {
            resultsTableView.isHidden = true
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        if searchBar.tag == 0 {
            endSearchBar.becomeFirstResponder()
        }
        else {
             getDirections()
        }
    }
    
    func getSearchResults(searchText:String) {
        SVProgressHUD.show()
        didSelectSearchResult = false
        SearchService.shared.getAllResults(searchText: searchText)
    }
    
    @IBAction func getDirections() {
        isLoading = true
        guard let startLocation = startLocation, let endLocation = endLocation else {
            isLoading = false
            return
        }
        NavigationRouteService.shared.setTransportMode(with: selectedMode)
        NavigationRouteService.shared.getDirection(startLocation: startLocation, endLocation: endLocation, restrictionList: []) { (route) in
            self.isLoading = false
            guard let route = route else {
                return
            }
            self.delegate?.didGetDirections(route: route, startLocation: startLocation, endLocation: endLocation)
            self.dismiss(animated: true, completion: nil)
        }
    }
}

//MARK: - Table

extension DirectionsViewController: UITableViewDelegate, UITableViewDataSource {
    func setupTableViews() {
        resultsTableView.register(UINib(nibName: "SearchResultCell", bundle: nil), forCellReuseIdentifier: "cell")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return listOfSearchResults[section].count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SearchResultCell
        let data = listOfSearchResults[indexPath.section][indexPath.row]
        cell.configure(with: data)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionHeaderHeight
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 7
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40.0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: sectionHeaderHeight))
        let label = UILabel(frame: CGRect(x: 15, y: 10, width: tableView.bounds.width - 30, height: sectionHeaderHeight))
        label.font = UIFont.systemFont(ofSize: 12)
        label.textColor = UIColor.gray
        
        let searchType = SearchType(rawValue: section + 1)
        label.text = searchType?.name.uppercased()
        view.addSubview(label)
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! SearchResultCell
        guard let model = cell.model else { return }
        resultsTableView.isHidden = true
        if selectedSearchBar == .Start {
            startSearchBar.text = model.name
            startLocation = model
        }
        else {
            endSearchBar.text = model.name
            endLocation = model
        }
        didSelectSearchResult = true
    }
}

protocol DirectionsViewControllerDelegate: class {
    func didGetDirections(route: AGSRoute, startLocation: SearchResultModel, endLocation: SearchResultModel)
}
