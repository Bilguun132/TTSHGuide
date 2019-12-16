//
//  File.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 3/5/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import UIKit
import IndoorAtlas

class IALocationService {
    
    private let apiKey = "23f47a1c-80a5-4c25-b031-52450420d383"
    private let apiSecret = "5nnTRoi7RUhEEtGkX564OLh+OA+/GQyCQq2cn/GQbsiH6u+hf5xS0+NKF0p+LY+pI+xhHmtAq93eO9wCaMH7nFr7k7Uz+vhueNNbsRYpUwVzX4BgsDwAeiVQpRoZbg=="
    
    static let shared = IALocationService()
    
    init() {
        IALocationManager.sharedInstance().setApiKey(apiKey, andSecret: apiSecret)
    }
    
}
