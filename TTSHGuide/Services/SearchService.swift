//
//  SearchService.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 18/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import Foundation
import SwiftyJSON
import ArcGIS

class SearchService {
    private let maxRecords = 6
    private var listOfSearchResults: [[SearchResultModel]] = [[],[],[],[],[],[],[]]
    var delegate: SearchServiceDelegate?
    
    static let shared = SearchService()
    
    init() {}
    
    
    
    func clearSearchResults() {
        listOfSearchResults = [[],[],[],[],[],[],[]]
    }
    
    
    func getSearchResults(selectedSearchType: SearchType, searchText: String) {
        switch selectedSearchType.rawValue {
        case SearchType.All.rawValue:
            getAllResults(searchText: searchText)
        case SearchType.Medical.rawValue:
            getSearchResults(searchText: searchText, type: "Medical Centre Block", searchType: selectedSearchType)
        case SearchType.Atrium.rawValue:
            getSearchResults(searchText: searchText, type: "Atrium Block", searchType: selectedSearchType)
        case SearchType.Access.rawValue:
            getSearchResults(searchText: searchText, type: "Access Points", searchType: selectedSearchType)
        case SearchType.Ward.rawValue:
            getSearchResults(searchText: searchText, type: "Ward Block", searchType: selectedSearchType)
        case SearchType.Amenities.rawValue:
            getSearchResults(searchText: searchText, type: "Amenities", searchType: selectedSearchType)
        case SearchType.Emergency.rawValue:
            getSearchResults(searchText: searchText, type: "Emergency Block", searchType: selectedSearchType)
        case SearchType.NNI.rawValue:
            getSearchResults(searchText: searchText, type: "National Neuroscience Institute (NNI) Block", searchType: selectedSearchType)
        default:
            getAllResults(searchText: searchText)
        }
    }
    
    func getAllResults(searchText: String) {
        getSearchResults(searchText: searchText, type: "Medical Centre Block", searchType: SearchType.Medical)
        getSearchResults(searchText: searchText, type: "Emergency Block", searchType: SearchType.Emergency)
        getSearchResults(searchText: searchText, type: "Amenities", searchType: SearchType.Amenities)
        getSearchResults(searchText: searchText, type: "National Neuroscience Institute (NNI) Block", searchType: SearchType.NNI)
        getSearchResults(searchText: searchText, type: "Ward Block", searchType: SearchType.Ward)
        getSearchResults(searchText: searchText, type: "Access Points", searchType: SearchType.Access)
        getSearchResults(searchText: searchText, type: "Atrium Block", searchType: SearchType.Access)
    }
    
    private func getSearchResults(searchText: String, type: String, searchType: SearchType) {
        guard let type = type.addingPercentEncoding(withAllowedCharacters: .urlHostAllowed) else {return}
        let url = "https://services9.arcgis.com/w3759YKEh5QSGFrI/arcgis/rest/services/TTSHSearchLayer_060419/FeatureServer/0/query?f=json&where=UPPER%28Name%29+LIKE+%27%25\(searchText)%25%27+AND+UPPER%28Block%29+Like+%27%25\(type)%25%27&returnGeometry=true&spatialRel=esriSpatialRelIntersects&outFields=Floor%2C+Name&outSR=102100&resultRecordCount=\(maxRecords)"
        
        HTTPService.getData(urlString: url) { (result) in
            switch result {
            case .success(let value):
                var results = [SearchResultModel]()
                for result in value["features"].arrayValue {
                    let agsPoint = AGSPoint(x: result["geometry"]["x"].doubleValue, y: result["geometry"]["y"].doubleValue, spatialReference: AGSSpatialReference.init(wkid: 3857))
                    results.append(SearchResultModel(coordinates: agsPoint, name: result["attributes"]["Name"].stringValue, floor: result["attributes"]["Floor"].stringValue))
                }
                self.listOfSearchResults[searchType.rawValue-1] = results
                print(self.listOfSearchResults)
                DispatchQueue.main.async {
                    self.delegate?.updateSearchResults(listOfSearchResults: self.listOfSearchResults)
                }
            case .failure(let error):
                print(error)
            }
        }
    }
}





public enum SearchType: Int {
    case All = 0, Medical, Atrium, Access, Ward, Amenities, Emergency, NNI
    var name: String {
        switch self {
        case .Medical:
            return "Medical Centre Block"
        case .Atrium:
            return "Atrium Block"
        case .Access:
            return "Access Points"
        case .Ward:
            return "Ward Block"
        case .Amenities:
            return "Amenities"
        case .Emergency:
            return "Emergency Block"
        case .NNI:
            return "National Neuroscience Institute (NNI) Block"
        case .All:
            return "All"
        }
    }
}

protocol SearchServiceDelegate {
    func updateSearchResults(listOfSearchResults: [[SearchResultModel]])
}
