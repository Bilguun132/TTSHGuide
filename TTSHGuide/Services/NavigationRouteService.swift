//
//  NavigationRouteService.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 22/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit
import ArcGIS
import SwiftyJSON

class NavigationRouteService {
    
    //MARK: - Properties
    private var routeTask: AGSRouteTask!
    private var transportMode: TransportType = .Walk
    private var currentLevel: CurrentLevel = .L1
    private var apTable: AGSServiceFeatureTable!
    
    static let shared = NavigationRouteService()
    
    init() {}
    
    //MARK: - Functions
    
    func setTransportMode(with selectedMode: TransportType) {
        transportMode = selectedMode
    }
    
    func getDirection(startLocation: SearchResultModel, endLocation: SearchResultModel, restrictionList: [String], completion: @escaping (AGSRoute?) -> ()) {
        let geoParameters = AGSGeocodeParameters()
        geoParameters.maxResults = 1

        let originalPoint = AGSPoint(x: startLocation.coordinates.x, y: startLocation.coordinates.y, spatialReference: AGSSpatialReference.init(wkid: 102100))
        let originalStop: AGSStop = AGSStop(point: originalPoint)

        let endPoint = AGSPoint(x: endLocation.coordinates.x, y: endLocation.coordinates.y, spatialReference: AGSSpatialReference.init(wkid: 102100))
        let endStop: AGSStop = AGSStop(point: endPoint)

        switch transportMode {
        case .Walk:
            routeTask = AGSRouteTask(url: URL(string: "https://arcgisops01.nus.edu.sg/arcgis/rest/services/TTSH/TTSH_Network_Regular_070219/NAServer/Route")!)
        case .Eldery:
            routeTask = AGSRouteTask(url: URL(string: "https://arcgisops01.nus.edu.sg/arcgis/rest/services/TTSH/TTSH_Network_Elderly_070219/NAServer/Route")!)
        case .Chair:
            routeTask = AGSRouteTask(url: URL(string: "https://arcgisops01.nus.edu.sg/arcgis/rest/services/TTSH/TTSH_Network_Handicap_070219/NAServer/Route")!)
        }
        
        routeTask.defaultRouteParameters() { defaultParams, error in
            guard error == nil else {
                print("Error getting default parameters: \(error!.localizedDescription)")
                 return completion(nil)
            }
            
            // To make best use of the service, we will base our request off the service's default parameters.
            guard let params = defaultParams else {
                print("No default parameters available.")
                 return completion(nil)
            }
            
            params.setStops([originalStop,endStop])
            params.returnDirections = true
            params.directionsDistanceUnits = AGSUnitSystem.metric
            params.directionsStyle = AGSDirectionsStyle.desktop
            params.travelMode?.uTurnPolicy = AGSUTurnPolicy.allowedAtDeadEnds
            self.routeTask.solveRoute(with: params, completion: { (result, error) in
                let routes = result?.routes
                let route = routes?.first
                if route == nil
                {
                    print("error")
                    return
                }
                completion(route)
            })
        }
    }
    
    func getNearestPoint(currentPoint: AGSPoint, completion: @escaping (Result<AGSPoint, Error>) -> ()) {
        
        switch currentLevel {
        case .B2:
            apTable = AGSServiceFeatureTable(url: URL(string: "https://services9.arcgis.com/w3759YKEh5QSGFrI/ArcGIS/rest/services/TTSH_B2_Combined_030219/FeatureServer/0")!)
        case .B1:
            apTable = AGSServiceFeatureTable(url: URL(string: "https://services9.arcgis.com/w3759YKEh5QSGFrI/ArcGIS/rest/services/TTSH_B1_Combined_030219/FeatureServer/0")!)
        case .L1:
            apTable = AGSServiceFeatureTable(url: URL(string: "https://services9.arcgis.com/w3759YKEh5QSGFrI/ArcGIS/rest/services/TTSH_L1_Combined_030219/FeatureServer/0")!)
        }
        
        let queryParams = AGSQueryParameters()
        queryParams.returnGeometry = true
        queryParams.outSpatialReference = .webMercator()
        queryParams.whereClause = "1=1"
        
        apTable.queryFeatures(with: queryParams, queryFeatureFields: .loadAll) { (result, error) in
            if error != nil {
                print(error!.localizedDescription)
                completion(.failure(error!))
            }
            else {
                guard let feature = result?.featureEnumerator().nextObject(), let polyLine = feature.geometry else {return}
                guard let nearestPoint = AGSGeometryEngine.nearestCoordinate(in: polyLine, to: currentPoint) else {return}
                print("nearest point is \(nearestPoint.point)")
                completion(.success(nearestPoint.point))
                
            }
        }
    }
    
}

public enum TransportType: Int {
    case Walk = 0, Eldery, Chair
}

public enum CurrentLevel: Int {
    case B2 = 0, B1, L1
}
