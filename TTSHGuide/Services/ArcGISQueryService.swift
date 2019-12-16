//
//  ArcGISQueryService.swift
//  Mapital
//
//  Created by Bilguun Batbold on 18/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit
import ArcGIS
import SwiftyJSON

class ArcGISQueryService {
    
    private var AMENITIES_MAP_IMAGE_LAYER_URL = ""
    private var AMENITIES_FEATURE_SERVICE_URL = ""
    private var CARTOGRAPHY_FEATURE_SERIVCE_URL = ""
    private var AP_FEATURE_SERVICE_URL = ""
    private var LOCATOR_TASK_URL = ""
    private var ROUTE_TASK_URL = ""
    private var TILED_LAYER_URL = ""
    private var BASE_LAYER_URL = ""
    
    private var amenitiesLayer: AGSArcGISMapImageLayer! = nil
    private var amenitiesFeatureTable: AGSServiceFeatureTable! = nil
    private var apFeatureTable: AGSServiceFeatureTable! = nil
    private var cartographyFeatureTable: AGSServiceFeatureTable! = nil
    private var locatorTask: AGSLocatorTask! = nil
    private var routeTask: AGSRouteTask! = nil
    
    static let shared = ArcGISQueryService()
    
    init() {}
    
    func getAPPoint(locationCode: String) -> AGSPoint? {
        let query = AGSQueryParameters()
        query.returnGeometry = true
        query.whereClause = "OBJECTID=\(locationCode)"
        query.outSpatialReference = AGSSpatialReference(wkid: 102100)
        
        return queryFeatures(query: query)
    }
    
    func queryFeatures(query: AGSQueryParameters) -> AGSPoint? {
        
        var point: AGSPoint?
        let group = DispatchGroup()
        group.enter()
        
        DispatchQueue.global().async(group: group) {
            self.apFeatureTable.queryFeatures(with: query, queryFeatureFields: .loadAll) { (result, error) in
                if error != nil {
                    print(error as Any)
                }
                else {
                    guard let feature: AGSFeature = (result?.featureEnumerator().nextObject()) else {
                        group.leave()
                        return
                    }
                    point = feature.geometry as? AGSPoint
                }
                group.leave()
                return
            }
        }
        group.wait()
        
        return point
    }
    
    func queryFloorData(mapPoint: AGSPoint, completionHandler: @escaping (JSON?) -> Void) {
        let wgs84Point = AGSGeometryEngine.projectGeometry(mapPoint, to: AGSSpatialReference.wgs84())
        print(wgs84Point as Any)
        let queryParams = AGSQueryParameters()
        queryParams.geometry = wgs84Point
        queryParams.whereClause = "1=1"
        self.cartographyFeatureTable.queryFeatures(with: queryParams, queryFeatureFields: .loadAll) { (queryResult:AGSFeatureQueryResult?, error:Error?) -> Void in
            if let error = error {
                print(error)
                completionHandler(nil)
            }
            if queryResult?.featureEnumerator().allObjects.count == 0 {
                completionHandler(nil)
            }
            guard let feature:AGSFeature = (queryResult?.featureEnumerator().nextObject()) else {
                completionHandler(nil)
                return
            }
            completionHandler(JSON(feature.attributes))
        }
    }
    
    func queryAmenity(query: AGSQueryParameters, completionHandler: @escaping(AGSFeature?) -> Void) {
        
        
        self.amenitiesFeatureTable.queryFeatures(with: query, queryFeatureFields: .loadAll) { (queryResult:AGSFeatureQueryResult?, error:Error?) -> Void in
            if let error = error {
                print(error)
                completionHandler(nil)
            }
            if let result = queryResult {
                if result.featureEnumerator().allObjects.count > 0 {
                    completionHandler(result.featureEnumerator().nextObject()!)
                }
                else {
                    print ("No feature")
                    completionHandler(nil)
                }
            }
        }
    }
}
