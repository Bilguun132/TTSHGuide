//
//  Extensions.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 18/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import Foundation
import ArcGIS

extension URLSession {
    
    func dataTask(with url: URL, result: @escaping (Result<(URLResponse, Data), Error>) -> Void) -> URLSessionDataTask {
        return dataTask(with: url, completionHandler: { (data, response, error) in
            if let error = error {
                result(.failure(error))
                return
            }
            guard let response = response, let data = data else {
                let error = NSError(domain: "error", code: 0, userInfo: nil)
                result(.failure(error))
                return
            }
            
            result(.success((response, data)))
        })
    }
}


class CustomDataSource: AGSLocationDataSource {
    
    var locationDelegate: CustomDataSourceDelegate?
    
    override init() {
        super.init()
    }
    
    override func doStart() {
        super.doStart()
        print("Started")
        locationDelegate?.startUpdatingLocation()
        self.didStartOrFailWithError(nil)
    }
    
    override func doStop() {
        super.doStop()
        locationDelegate?.stopUpdatingLocation()
        self.didStop()
        print("Stopped")
    }
    
    override func didUpdateHeading(_ heading: Double) {
        super.didUpdateHeading(heading)
        print("updated heading")
    }
    
    override func didUpdate(_ location: AGSLocation) {
        super.didUpdate(location)
        print("updated location")
    }
}

protocol CustomDataSourceDelegate {
    func startUpdatingLocation()
    func stopUpdatingLocation()
}
