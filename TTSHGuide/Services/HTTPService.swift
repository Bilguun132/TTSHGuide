//
//  HTTPService.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 18/4/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import Foundation
import SwiftyJSON

class HTTPService {
    
    static func getData(urlString: String, completion: @escaping (Result<JSON, APIServiceError>) -> ()) {
        
        guard let url = URL(string: urlString) else {return}
        
        URLSession.shared.dataTask(with: url) { (result) in
            switch result {
            case .success(let (response, data)):
                guard let statusCode = (response as? HTTPURLResponse)?.statusCode, 200..<299 ~= statusCode else {
                    completion(.failure(.invalidResponse))
                    return
                }
                
                completion(.success(JSON(data)))
                
            case .failure( _):
                completion(.failure(.apiError))
                
            }
            }.resume()
    }
}

public enum APIServiceError: Error {
    case apiError
    case invalidEndpoint
    case invalidResponse
    case noData
    case decodeError
}
