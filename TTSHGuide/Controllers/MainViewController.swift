//
//  ViewController.swift
//  Mapital
//
//  Created by Bilguun Batbold on 18/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit
import ArcGIS
import DropDownMenuKit
import SwiftyJSON
import SVProgressHUD
import IndoorAtlas


class MainViewController: UIViewController, AGSGeoViewTouchDelegate, DirectionsViewControllerDelegate, UIGestureRecognizerDelegate {
    
    //MARK: - Properties
    
    private var dropDownViewFrame: UIView!
    
    @IBOutlet weak var mapView: AGSMapView!
    @IBOutlet var dropDownMenu: DropDownMenu!
    @IBOutlet weak var searchTypeImage: UIImageView!
    @IBOutlet weak var floorPickerView: UIPickerView!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var resultsTableView: UITableView!
    @IBOutlet weak var directionsView: DirectionsView!
    @IBOutlet weak var navDirectionView: NavDirectionView!
    @IBOutlet weak var directionsViewHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var searchBarTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var navDirectionsTopConstraint: NSLayoutConstraint!
    @IBOutlet weak var pickerViewTrailingConstraint: NSLayoutConstraint!
    
    private var selectedBuildingName: String = ""
    private var floorDataJSON: JSON = []
    private var floorPlanLevel1: AGSArcGISTiledLayer = AGSArcGISTiledLayer(url: URL(string: "https://tiles.arcgis.com/tiles/w3759YKEh5QSGFrI/arcgis/rest/services/TTSH_B2Colours_100319/MapServer")!)
    private var floorPlanLevel2: AGSArcGISTiledLayer = AGSArcGISTiledLayer(url: URL(string: "https://tiles.arcgis.com/tiles/w3759YKEh5QSGFrI/arcgis/rest/services/TTSH_B1Colours_100319/MapServer")!)
    private var floorPlanLevel3: AGSArcGISTiledLayer = AGSArcGISTiledLayer(url: URL(string: "https://tiles.arcgis.com/tiles/w3759YKEh5QSGFrI/arcgis/rest/services/TTSH_L1Colours/MapServer")!)
    private var serviceFeatureTableB2: AGSServiceFeatureTable = AGSServiceFeatureTable(url: URL(string: "https://services9.arcgis.com/w3759YKEh5QSGFrI/arcgis/rest/services/TTSH_B2Colours/FeatureServer/3")!)
    private var serviceFeatureTableB1: AGSServiceFeatureTable = AGSServiceFeatureTable(url: URL(string: "https://services9.arcgis.com/w3759YKEh5QSGFrI/arcgis/rest/services/TTSH_B1_Labels_210219/FeatureServer/1")!)
    private var serviceFeatureTableL1: AGSServiceFeatureTable = AGSServiceFeatureTable(url: URL(string: "https://services9.arcgis.com/w3759YKEh5QSGFrI/arcgis/rest/services/TTSH_L1_Labels_210219/FeatureServer/1")!)
    private var featureLayerB2: AGSFeatureLayer?
    private var featureLayerB1: AGSFeatureLayer?
    private var featureLayerL1: AGSFeatureLayer?
    private var TILED_LAYER_URL = "https://mapservices.onemap.sg/mapproxy/wmts"
    private var BASE_LAYER_URL = ""
    
    private var selectedSearchType: SearchType = SearchType.All
    private var listOfSearchResults: [[SearchResultModel]]  = [[],[],[],[],[],[],[]]
    private let sectionHeaderHeight: CGFloat = 25
    
    private var directions = [AGSDirectionManeuver]()
    
    private var map:AGSMap!
    private var graphicOverlay = AGSGraphicsOverlay()
    private var routeOverlay = AGSGraphicsOverlay()
    private var selectedRouteOverlay = AGSGraphicsOverlay()
    private var locationGraphic: AGSGraphic?
    
    private var startLocation: AGSPoint?
    
    private var floorPickerData: [(floorName:String, floorNumber:Int)] = []
    private var currentShowFloor = (floorName: "L1", floorNumber: 3) //show level 1
    
    private var didSelectSearchResult = false
    
    private let locationManager = IALocationManager.sharedInstance()
    private let coreLocationManager = CLLocationManager()
    private let datasource = CustomDataSource()
    
    private var currentLocation: AGSPoint?
    private var requestedEndLocation: SearchResultModel?
    
    
    //MARK: - Lifecycle
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupDropdownMenu()
        setupMap()
        setupTableViews()
        directionsView.topView.addGestureRecognizer(panRecognizer)
        directionsView.delegate = self
        navDirectionView.delegate = self
        locationManager.delegate = self
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        floorPickerView.selectRow(2, inComponent: 0, animated: true)
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "DirectionsSegue" {
            guard let destVC = segue.destination as? DirectionsViewController else {return}
            destVC.delegate = self
            destVC.currentLocation = currentLocation
        }
    }
    
    //MARK: - Map
    
    func setupMap() {
        
        self.map = AGSMap(basemap: AGSBasemap.topographic())
        floorPlanLevel1.isVisible = false
        floorPlanLevel2.isVisible = false
        floorPlanLevel3.isVisible = true
        self.map.basemap.baseLayers.addObjects(from: [floorPlanLevel1, floorPlanLevel2, floorPlanLevel3])
        print(self.map.basemap.baseLayers.count)
        
        floorPickerData.append(("B2", 1))
        floorPickerData.append(("B1", 2))
        floorPickerData.append(("1", 3))
        
        createLabels()
        
        self.map.initialViewpoint = AGSViewpoint(latitude: 1.321280, longitude: 103.845753, scale: 2000)
        
        map.load { (error) -> Void in
            self.map.minScale = 2500
            self.map.maxScale = 300
            self.mapView.map = self.map
            self.mapView.touchDelegate = self
            self.mapView.graphicsOverlays.add(self.graphicOverlay)
            self.mapView.graphicsOverlays.add(self.routeOverlay)
            self.mapView.graphicsOverlays.add(self.selectedRouteOverlay)
            self.datasource.locationDelegate = self
            self.coreLocationManager.delegate = self
//            self.locationManager.startUpdatingLocation()
            self.mapView.locationDisplay.dataSource = self.datasource
            MapMatchingService.shared.delegate = self
        }
    }
    
    func geoView(_ geoView: AGSGeoView, didTapAtScreenPoint screenPoint: CGPoint, mapPoint: AGSPoint) {
        hideViews()
//        if routeOverlay.graphics.count > 0 {
//            print(mapPoint)
//            print(mapPoint.toCLLocationCoordinate2D())
//            MapMatchingService.shared.createEdgeTable(trackPoint: mapPoint)
//        }
    }
        
    func createLabels() {
        
        featureLayerB2 = AGSFeatureLayer(featureTable: serviceFeatureTableB2)
        featureLayerB1 = AGSFeatureLayer(featureTable: serviceFeatureTableB1)
        featureLayerL1 = AGSFeatureLayer(featureTable: serviceFeatureTableL1)
        
        let featureLayers = [featureLayerB2, featureLayerB1, featureLayerL1]
        
        self.map.operationalLayers.addObjects(from: [featureLayerB2 as Any, featureLayerB1 as Any, featureLayerL1 as Any])
        
        let textSymbol = AGSTextSymbol()
        textSymbol.size = 14
        textSymbol.color = UIColor.black
        textSymbol.haloColor = UIColor.white
        textSymbol.haloWidth = 1
        textSymbol.angle = 0
        
        do {
            let json = try JSON(["labelExpressionInfo":["expression":"$feature.Name"], "labelPlacement":"esriServerPolygonPlacementAlwaysHorizontal", "minScale":"1200", "maxScale":"0", "where":"Name <> ' '", "symbol":JSON(textSymbol.toJSON())])
            let jsonData = try JSONSerialization.jsonObject(with: json.rawData(), options: .mutableContainers)
            let labelDefinition = try AGSLabelDefinition.fromJSON(jsonData)
            featureLayerB2?.labelDefinitions.add(labelDefinition)
            featureLayerB1?.labelDefinitions.add(labelDefinition)
            featureLayerL1?.labelDefinitions.add(labelDefinition)
        }
        catch let(error) {
            print(error)
        }
        
        
        let lineSymbol = AGSSimpleLineSymbol(style: .null, color: #colorLiteral(red: 0, green: 0, blue: 1, alpha: 1), width: 2.0)
        let fillSymbol = AGSSimpleFillSymbol(style: .null, color: UIColor.white, outline: lineSymbol)
        
        for featureLayer in featureLayers {
            featureLayer?.renderer = AGSSimpleRenderer(symbol: fillSymbol)
            featureLayer?.labelsEnabled = true
            featureLayer?.isVisible = false
        }
        
        featureLayerL1?.isVisible = true
        
    }
    
    func navigateToStartPoint(point: AGSPoint) {
        let viewPoint = AGSViewpoint(center: point, scale: 800)
        self.hideViews()
        self.startLocation = point
        self.mapView.setViewpoint(viewPoint, duration: 0.3, completion: nil)
        graphicOverlay.graphics.removeAllObjects()
        let pictureSymbol = AGSPictureMarkerSymbol(image: #imageLiteral(resourceName: "radio_checked"))
        locationGraphic = AGSGraphic(geometry: point, symbol: pictureSymbol, attributes: [:])
        graphicOverlay.graphics.add(locationGraphic as Any)
    }
    
    func didGetDirections(route: AGSRoute, startLocation: SearchResultModel, endLocation: SearchResultModel) {

        if  !self.mapView.locationDisplay.started {
            startLocationUpdate()
        }
        
        if let polyline = route.routeGeometry {
            MapMatchingService.shared.createSegTable(polyline: polyline)
        }
        requestedEndLocation = endLocation
        directionsView.loadTable(route: route)
        directions = route.directionManeuvers
        routeOverlay.graphics.removeAllObjects()
        graphicOverlay.graphics.removeAllObjects()
        let startSymbol = AGSPictureMarkerSymbol(image: #imageLiteral(resourceName: "icon_starting"))
        locationGraphic = AGSGraphic(geometry: startLocation.coordinates, symbol: startSymbol, attributes: [:])
        graphicOverlay.graphics.add(locationGraphic as Any)
        let endSymbol = AGSPictureMarkerSymbol(image: #imageLiteral(resourceName: "icon_end"))
        locationGraphic = AGSGraphic(geometry: endLocation.coordinates, symbol: endSymbol, attributes: [:])
        graphicOverlay.graphics.add(locationGraphic as Any)
        let routeSymbol = AGSSimpleLineSymbol(style: .solid, color: #colorLiteral(red: 0.6000000238, green: 0.6000000238, blue: 0.6000000238, alpha: 1), width: 4.0)
        let routeGraphic = AGSGraphic(geometry: route.routeGeometry, symbol: routeSymbol, attributes: nil)
        routeOverlay.graphics.add(routeGraphic)
        directionsView.isHidden = false
        for direction in directions {
            print(direction.directionText)
        }
        searchBarTopConstraint.constant = -200
        navDirectionsTopConstraint.constant = 8
//        pickerViewTrailingConstraint.constant = -100
        navDirectionView.configure(startLocation: startLocation, endLocation: endLocation)
        
        toggleSelectedRoute()
    }
    
    func toggleSelectedRoute() {
        selectedRouteOverlay.graphics.removeAllObjects()
        let blueRouteSymbol = AGSSimpleLineSymbol(style: .solid, color: #colorLiteral(red: 0.4392156863, green: 0.6470588235, blue: 1, alpha: 1), width: 4.0)
        for direction in directions {
            let messages = direction.maneuverMessages
            if messages.count > 0 && messages.first!.text.lowercased().contains(currentShowFloor.floorName.lowercased()) {
                let selectedRouteGraphic = AGSGraphic(geometry: direction.geometry, symbol: blueRouteSymbol, attributes: nil)
                selectedRouteOverlay.graphics.add(selectedRouteGraphic)
            }
        }
    }
    
    func startLocationUpdate() {
//        self.mapView.locationDisplay.autoPanMode = AGSLocationDisplayAutoPanMode.navigation
        self.mapView.locationDisplay.start { [weak self] (error) in
            if let error = error {
                self?.showAlert(withStatus: error.localizedDescription)
            }
        }
    }
    //MARK: - Support Functions
    
    func hideViews() {
        resultsTableView.isHidden = true
        dropDownMenu.hide()
        dropDownViewFrame.isHidden = true
        self.view.endEditing(true)
    }
    
    // Gestures
    
    private lazy var panRecognizer: InstantPanGestureRecognizer = {
        let recognizer = InstantPanGestureRecognizer()
        recognizer.addTarget(self, action: #selector(popupViewPanned(recognizer:)))
        recognizer.delegate = self
        return recognizer
    }()
    
    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        
        if touch.view is UIButton {
            return false
        }
        return true
    }
    
    private var currentState: State = .closed
    
    /// All of the currently running animators.
    private var runningAnimators = [UIViewPropertyAnimator]()
    
    /// The progress of each animator. This array is parallel to the `runningAnimators` array.
    private var animationProgress = [CGFloat]()
    
    /// Animates the transition, if the animation is not already running.
    private func animateTransitionIfNeeded(to state: State, duration: TimeInterval) {
        
        // ensure that the animators array is empty (which implies new animations need to be created)
        guard runningAnimators.isEmpty else { return }
        
        // an animator for the transition
        let transitionAnimator = UIViewPropertyAnimator(duration: duration, dampingRatio: 1, animations: {
            switch state {
            case .open:
                self.directionsViewHeightConstraint.constant = self.view.bounds.height - 50
            case .closed:
                self.directionsViewHeightConstraint.constant = 50
            }
            self.view.layoutIfNeeded()
        })
        
        // the transition completion block
        transitionAnimator.addCompletion { position in
            
            // update the state
            switch position {
            case .start:
                self.currentState = state.opposite
            case .end:
                self.currentState = state
            case .current:
                ()
            @unknown default:
                print("unknown")
            }
            
            // manually reset the constraint positions
            switch self.currentState {
            case .open:
                self.directionsViewHeightConstraint.constant = self.view.bounds.height - 50
            case .closed:
                self.directionsViewHeightConstraint.constant = 50
            }
            
            // remove all running animators
            self.runningAnimators.removeAll()
        }
        
        // start all animators
        transitionAnimator.startAnimation()
        
        // keep track of all running animators
        runningAnimators.append(transitionAnimator)
        
    }
    
    
    @objc private func popupViewPanned(recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            
            // start the animations
            animateTransitionIfNeeded(to: currentState.opposite, duration: 0.5)
            
            // pause all animations, since the next event may be a pan changed
            runningAnimators.forEach { $0.pauseAnimation() }
            
            // keep track of each animator's progress
            animationProgress = runningAnimators.map { $0.fractionComplete }
            
        case .changed:
            // variable setup
            let translation = recognizer.translation(in: directionsView)
            var fraction = -translation.y / self.view.bounds.height
            // adjust the fraction for the current state and reversed state
            if currentState == .open { fraction *= -1 }
            if runningAnimators[0].isReversed { fraction *= -1 }
            
            // apply the new fraction
            for (index, animator) in runningAnimators.enumerated() {
                animator.fractionComplete = fraction + animationProgress[index]
            }
            
        case .ended:
            
            // variable setup
            let yVelocity = recognizer.velocity(in: directionsView).y
            let shouldClose = yVelocity > 0
            
            // if there is no motion, continue all animations and exit early
            if yVelocity == 0 {
                runningAnimators.forEach { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
                break
            }
            
            // reverse the animations based on their current state and pan motion
            switch currentState {
            case .open:
                if !shouldClose && !runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
                if shouldClose && runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
            case .closed:
                if shouldClose && !runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
                if !shouldClose && runningAnimators[0].isReversed { runningAnimators.forEach { $0.isReversed = !$0.isReversed } }
            }
            
            // continue all animations
            runningAnimators.forEach { $0.continueAnimation(withTimingParameters: nil, durationFactor: 0) }
            
        default:
            ()
        }
    }
    
    private func showAlert(withStatus: String) {
        let alertController = UIAlertController(title: "Alert", message:
            withStatus, preferredStyle: UIAlertController.Style.alert)
        alertController.addAction(UIAlertAction(title: "Dismiss", style: UIAlertAction.Style.default,handler: nil))
        present(alertController, animated: true, completion: nil)
    }
    
    //MARK: - Buttons
    
    @IBAction func handleShrinkAndEnlarge(sender: UIButton) {
        switch sender.tag {
        case 0:
            self.mapView.setViewpointScale(self.mapView.mapScale * 0.75, completion: nil)
        case 1:
            self.mapView.setViewpointScale(self.mapView.mapScale * 1.5, completion: nil)
        default:
            return
        }
    }
    
    @IBAction func currentLocationTap(_ sender: Any) {
        SVProgressHUD.show(withStatus: "Location you...")
        SVProgressHUD.dismiss(withDelay: 10.0) {
            self.showAlert(withStatus: "Unable to locate after 10s. Please ensure Bluetooth is turned on.")
        }
        if  !self.mapView.locationDisplay.started {
            startLocationUpdate()
        }
        else {
            self.mapView.locationDisplay.stop()
            SVProgressHUD.dismiss()
        }
    }
    
    
}

//MARK: - Search

extension MainViewController: SearchServiceDelegate, DropDownMenuDelegate, UISearchBarDelegate, UISearchDisplayDelegate {
    
    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if !searchText.isEmpty && searchText.count > 1 {
            print(searchText)
            listOfSearchResults = [[],[],[],[],[],[],[]]
            getSearchResults(searchText: searchText.uppercased())
        }
        if searchText.isEmpty {
            
        }
    }
    
    func searchBarSearchButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
        guard let searchText = searchBar.text?.uppercased() else {return}
        if searchText != "" {
            getSearchResults(searchText: searchText)
        }
        else {
            hideViews()
        }
    }
    
    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        didSelectSearchResult = true
    }
    
    func getSearchResults(searchText:String) {
        SearchService.shared.delegate = self
        SearchService.shared.clearSearchResults()
        didSelectSearchResult = false
        SVProgressHUD.show()
        SearchService.shared.getSearchResults(selectedSearchType: selectedSearchType, searchText: searchText)
    }
    
    func updateSearchResults(listOfSearchResults: [[SearchResultModel]] ) {
        if didSelectSearchResult {return}
        print(listOfSearchResults)
        self.listOfSearchResults = listOfSearchResults
        resultsTableView.reloadData()
        resultsTableView.isHidden = false
        SVProgressHUD.dismiss()
    }
    
    /// Sets up the drop down menu for search results
    func setupDropdownMenu() {
        dropDownViewFrame = UIView()
        dropDownViewFrame.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(dropDownViewFrame)
        dropDownViewFrame.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16).isActive = true
        dropDownViewFrame.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16).isActive = true
        dropDownViewFrame.topAnchor.constraint(equalTo: view.topAnchor, constant: 120).isActive = true
        dropDownViewFrame.heightAnchor.constraint(equalToConstant: 400).isActive = true
        dropDownViewFrame.layer.cornerRadius = 10
        dropDownViewFrame.isHidden = true
        dropDownMenu = DropDownMenu(frame: dropDownViewFrame.bounds)
        dropDownMenu.delegate = self
        dropDownMenu.container = dropDownViewFrame
        
        let allCell = DropDownMenuCell()
        allCell.textLabel!.text = "All"
        allCell.imageView!.image = UIImage(named: "typesearch_all")
        allCell.tag = SearchType.All.rawValue
        allCell.showsCheckmark = false
        allCell.menuAction = #selector(MainViewController.chooseDropDown(_:))
        allCell.menuTarget = self
        
        let medicalCell = DropDownMenuCell()
        medicalCell.textLabel!.text = "Medical Centre Block"
        medicalCell.tag = SearchType.Medical.rawValue
        medicalCell.imageView!.image = UIImage(named: "typesearch_medical")
        medicalCell.showsCheckmark = false
        medicalCell.menuAction = #selector(MainViewController.chooseDropDown(_:))
        medicalCell.menuTarget = self
        
        let atriumCell = DropDownMenuCell()
        atriumCell.textLabel!.text = "Atrium Block"
        atriumCell.tag = SearchType.Atrium.rawValue
        atriumCell.imageView!.image = UIImage(named: "typesearch_atrium")
        atriumCell.showsCheckmark = false
        atriumCell.menuAction = #selector(MainViewController.chooseDropDown(_:))
        atriumCell.menuTarget = self
        
        let apCell = DropDownMenuCell()
        apCell.textLabel!.text = "Access Points"
        apCell.tag = SearchType.Access.rawValue
        apCell.imageView!.image = UIImage(named: "typesearch_access")
        apCell.showsCheckmark = false
        apCell.menuAction = #selector(MainViewController.chooseDropDown(_:))
        apCell.menuTarget = self
        
        let wardCell = DropDownMenuCell()
        wardCell.textLabel!.text = "Ward Block"
        wardCell.tag = SearchType.Ward.rawValue
        wardCell.imageView!.image = UIImage(named: "typesearch_ward")
        wardCell.showsCheckmark = false
        wardCell.menuAction = #selector(MainViewController.chooseDropDown(_:))
        wardCell.menuTarget = self
        
        let amenityCell = DropDownMenuCell()
        amenityCell.textLabel!.text = "Amenities"
        amenityCell.tag = SearchType.Amenities.rawValue
        amenityCell.imageView!.image = UIImage(named: "typesearch_amenities")
        amenityCell.showsCheckmark = false
        amenityCell.menuAction = #selector(MainViewController.chooseDropDown(_:))
        amenityCell.menuTarget = self
        
        let emergencyCell = DropDownMenuCell()
        emergencyCell.textLabel!.text = "Emergency Block"
        emergencyCell.tag = SearchType.Emergency.rawValue
        emergencyCell.imageView!.image = UIImage(named: "typesearch_emergency")
        emergencyCell.showsCheckmark = false
        emergencyCell.menuAction = #selector(MainViewController.chooseDropDown(_:))
        emergencyCell.menuTarget = self
        
        let nniCell = DropDownMenuCell()
        nniCell.textLabel!.text = "National Neuroscience Institute (NNI) Block"
        nniCell.textLabel?.numberOfLines = 0
        nniCell.tag = SearchType.NNI.rawValue
        nniCell.imageView!.image = UIImage(named: "typesearch_nni")
        nniCell.showsCheckmark = false
        nniCell.menuAction = #selector(MainViewController.chooseDropDown(_:))
        nniCell.menuTarget = self
        
        dropDownMenu.menuCells = [allCell, medicalCell, atriumCell, apCell, wardCell, amenityCell, emergencyCell, nniCell]
    }
    
    func didTapInDropDownMenuBackground(_ menu: DropDownMenu) {
        dropDownMenu.hide()
    }
    
    @IBAction func chooseDropDown(_ sender: AnyObject) {
        let dropDownMenuCell = sender as! DropDownMenuCell
        searchTypeImage.image = dropDownMenuCell.imageView!.image
        selectedSearchType = SearchType(rawValue: dropDownMenuCell.tag) ?? SearchType.All
        showDropDownMenu()
    }
    
    @IBAction func showDropDownMenu() {
        if dropDownViewFrame.isHidden {
            dropDownMenu.show()
            dropDownViewFrame.isHidden = false
        }
        else {
            hideViews()
        }
    }
}

extension MainViewController: UITableViewDelegate, UITableViewDataSource {
    
    func setupTableViews() {
        resultsTableView.register(UINib(nibName: "SearchResultCell", bundle: nil), forCellReuseIdentifier: "cell")
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return tableView == resultsTableView ? listOfSearchResults[section].count : directions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if tableView == resultsTableView {
            let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath) as! SearchResultCell
            let data = listOfSearchResults[indexPath.section][indexPath.row]
            cell.configure(with: data)
            
            return cell
        }
        
        return UITableViewCell()
    }
    
    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return sectionHeaderHeight
    }
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return tableView == resultsTableView ? 7 : 1
    }
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return tableView == resultsTableView ? 40.0 : 60.0
    }
    
    func tableView(_ tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
        let view = UIView(frame: CGRect(x: 0, y: 0, width: tableView.bounds.width, height: sectionHeaderHeight))
        let label = UILabel(frame: CGRect(x: 15, y: 10, width: tableView.bounds.width - 30, height: sectionHeaderHeight))
        
        if tableView == resultsTableView {
            label.font = UIFont.systemFont(ofSize: 12)
            label.textColor = UIColor.gray
            
            let searchType = SearchType(rawValue: section + 1)
            label.text = searchType?.name.uppercased()
            view.addSubview(label)
        }
        
        return view
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let cell = tableView.cellForRow(at: indexPath) as! SearchResultCell
        guard let model = cell.model else { return }
        // print(model)
        navigateToStartPoint(point: model.coordinates)
        searchBar.text = model.name
        didSelectSearchResult = true
        view.endEditing(true)
    }
    
}

extension MainViewController: MapMatchingServiceDelegate {
    func didMatchPoint(point: AGSPoint) {
//        print(point)
//        let pictureSymbol = AGSPictureMarkerSymbol(image: #imageLiteral(resourceName: "radio_checked"))
//        locationGraphic = AGSGraphic(geometry: point, symbol: pictureSymbol, attributes: [:])
//        graphicOverlay.graphics.add(locationGraphic as Any)
    }
    
    func shouldReRoute(point: AGSPoint) {
        print(point)
        SVProgressHUD.show(withStatus: "Re-routing...")
        NavigationRouteService.shared.getNearestPoint(currentPoint: point) { (result) in
            switch result {
            case .success(let point):
                self.currentLocation = point
                let startLocation = SearchResultModel.init(coordinates: point, name: "Current Location", floor: "1")
                guard let endLocation = self.requestedEndLocation else {return}
                NavigationRouteService.shared.getDirection(startLocation: startLocation, endLocation: endLocation, restrictionList: [], completion: { (route) in
                    guard let route = route else {return}
                    print("Re routed")
                    self.didGetDirections(route: route, startLocation: startLocation, endLocation: endLocation)
                    SVProgressHUD.dismiss()
                })
                print(point)
            case .failure(let error):
                print(error)
                SVProgressHUD.dismiss()
            }
        }
    }
}

extension MainViewController: DirectionsViewDelegate, NavDirectionsViewDelegate {
    
    func didTapBack() {
        UIView.animate(withDuration: 0.5) {
            self.directionsView.isHidden = true
            self.searchBarTopConstraint.constant = 8
            self.navDirectionsTopConstraint.constant = -200
            self.pickerViewTrailingConstraint.constant = 8
            self.view.layoutIfNeeded()
        }
        
        self.routeOverlay.graphics.removeAllObjects()
        self.graphicOverlay.graphics.removeAllObjects()
        self.selectedRouteOverlay.graphics.removeAllObjects()
        requestedEndLocation = nil
    }
    
    
    func didSelectDirection(direction: AGSDirectionManeuver) {
        print(direction)
        if currentState == .open {
            animateTransitionIfNeeded(to: currentState.opposite, duration: 0.5)
        }
        guard let geometry = direction.geometry, let extent = direction.geometry?.extent else {return}
        drawRouteWithExtent(geometry: geometry, extent: extent)
    }
    
    func drawRouteWithExtent(geometry: AGSGeometry, extent: AGSEnvelope) {
        let symbol = AGSSimpleLineSymbol(style: .solid, color: #colorLiteral(red: 0.5725490451, green: 0, blue: 0.2313725501, alpha: 1), width: 5)
        symbol.markerStyle = .arrow
        let graphic = AGSGraphic(geometry: geometry, symbol: symbol, attributes: nil)
        if routeOverlay.graphics.count == 2 {
            routeOverlay.graphics.removeLastObject()
        }
        routeOverlay.graphics.add(graphic)
        let viewPoint = AGSViewpoint(targetExtent: extent)
        mapView.setViewpoint(viewPoint, duration: 0.5) { (_) in
        }

    }
    
    func didTapGo(directions: [AGSDirectionManeuver]) {
        
        print(directions)
        
    }
    
    func hideDirectionsView() {
        directionsView.isHidden = true
    }
    
}

extension MainViewController: IALocationManagerDelegate, CustomDataSourceDelegate, CLLocationManagerDelegate {
    
    func startUpdatingLocation() {
        self.locationManager.startUpdatingLocation()
//        coreLocationManager.startUpdatingLocation()
    }
    
    func stopUpdatingLocation() {
        self.locationManager.stopUpdatingLocation()
//        coreLocationManager.stopUpdatingLocation()
    }
    
//    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
//
//        let l = locations.last
//
//        if let newLocation = l?.coordinate {
//            print("Position changed to coordinate: \(newLocation.latitude) \(newLocation.longitude)")
//            if requestedEndLocation != nil {
//                let point = AGSPoint(clLocationCoordinate2D: newLocation)
//                let matchPoint = MapMatchingService.shared.createEdgeTable(trackPoint: AGSGeometryEngine.projectGeometry(point, to: .webMercator()) as! AGSPoint)
//                let location = AGSLocation(position: matchPoint, horizontalAccuracy: 0, velocity: 0, course: 0, lastKnown: false)
//                datasource.didUpdate(location)
//            }
//            else {
//                let point = AGSPoint(clLocationCoordinate2D: newLocation)
//                let location = AGSLocation(position: point, horizontalAccuracy: 0, velocity: 0, course: 0, lastKnown: false)
//                datasource.didUpdate(location)
//            }
//        }
//    }
    
    func indoorLocationManager(_ manager: IALocationManager, didUpdateLocations locations: [Any]) {
        
        let l = locations.last as! IALocation
        
        if let newLocation = l.location {
            self.mapView.locationDisplay.dataSource = self.datasource
            print("Position changed to coordinate: \(newLocation.coordinate.latitude) \(newLocation.coordinate.longitude)")
            if requestedEndLocation != nil {
                var point = AGSPoint(clLocationCoordinate2D: newLocation.coordinate)
                let matchPoint = MapMatchingService.shared.createEdgeTable(trackPoint: AGSGeometryEngine.projectGeometry(point, to: .webMercator()) as! AGSPoint)
                point = AGSGeometryEngine.projectGeometry(matchPoint, to: .wgs84()) as! AGSPoint
                let location = AGSLocation(position: point, horizontalAccuracy: newLocation.horizontalAccuracy, velocity: newLocation.speed, course: newLocation.course, lastKnown: false)
                datasource.didUpdate(location)
//                let point = AGSPoint(clLocationCoordinate2D: newLocation.coordinate)
//                let location = AGSLocation(position: point, horizontalAccuracy: newLocation.horizontalAccuracy, velocity: newLocation.speed, course: newLocation.course, lastKnown: false)
//                datasource.didUpdate(location)
            }
            else {
                let point = AGSPoint(clLocationCoordinate2D: newLocation.coordinate)
                let location = AGSLocation(position: point, horizontalAccuracy: newLocation.horizontalAccuracy, velocity: newLocation.speed, course: newLocation.course, lastKnown: false)
                datasource.didUpdate(location)
            }
//            print("Position changed to coordinate: \(newLocation.latitude) \(newLocation.longitude)")
//            let location = AGSLocation(clLocation: l.location!)
//            datasource.didUpdate(location)
        }
        
        SVProgressHUD.dismiss()
    }
}

extension MainViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }
    
    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return floorPickerData.count
    }
    
    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return String.init(describing: floorPickerData[row].floorName)
    }
    
    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        if floorPickerData.count == 0 {
            return
        }
        let floor = floorPickerData[row].floorNumber
        guard let hideLayer = self.map.basemap.baseLayers[self.currentShowFloor.floorNumber] as? AGSArcGISTiledLayer, let showLayer = self.map.basemap.baseLayers[floor] as? AGSArcGISTiledLayer else {
            return
        }
        
        hideLayer.isVisible = false
        showLayer.isVisible = true
        
        print(self.map.operationalLayers.count)
        guard let opHideLayer = self.map.operationalLayers[self.currentShowFloor.floorNumber - 1] as? AGSFeatureLayer, let opShowLayer = self.map.operationalLayers[floor - 1] as? AGSFeatureLayer else {
            return
        }
        
        opHideLayer.isVisible = false
        opShowLayer.isVisible = true
        
        currentShowFloor = floorPickerData[row]
        toggleSelectedRoute()
    }
}


private enum State {
    case closed
    case open
}

extension State {
    var opposite: State {
        switch self {
        case .open: return .closed
        case .closed: return .open
        }
    }
}


// MARK: - InstantPanGestureRecognizer
/// A pan gesture that enters into the `began` state on touch down instead of waiting for a touches moved event.
class InstantPanGestureRecognizer: UIPanGestureRecognizer {
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        if (self.state == UIGestureRecognizer.State.began) { return }
        super.touchesBegan(touches, with: event)
        self.state = UIGestureRecognizer.State.began
    }
    
}
