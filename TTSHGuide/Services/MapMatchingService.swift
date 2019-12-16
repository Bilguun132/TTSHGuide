//
//  MapMatchingService.swift
//  TTSHGuide
//
//  Created by Bilguun Batbold on 10/5/19.
//  Copyright © 2019 Bilguun. All rights reserved.
//

import Foundation
import ArcGIS

class MapMatchingService {
    
    let DEFAULT_BETA = 5.0
    let DEFAULT_SIGMA_Z = 4.07
    let DEFAULT_MAX_ROUTE_DISTANCE = 10.0
    
    private var offCourseRouteCount = 0

    weak var delegate: MapMatchingServiceDelegate?
    
    struct Segment {
        let index: Int
        let source: AGSPoint?
        let target: AGSPoint?
    }
    
    struct Edge {
        var index: Int
        let distanceToEdge: Double
        var matchPoint: [Double]
        var prob: Double
    }
    
    var segTable = [Segment]()
    var edgeTable = [Edge]()
    var seq = 0
    
    var route: AGSRoute?
    
    static let shared = MapMatchingService()
    
    init () {}
    
    func createSegTable(polyline: AGSPolyline) {
        segTable.removeAll()
        offCourseRouteCount = 0
        let polylineBuilder = AGSPolylineBuilder(polyline: polyline)
        for i in 0..<polylineBuilder.parts[0].points.array().count {
            if i < polylineBuilder.parts[0].points.array().count - 1 {
                let point = AGSGeometryEngine.projectGeometry(polylineBuilder.parts[0].points.array()[i], to: .webMercator()) as! AGSPoint
                let nextPoint = AGSGeometryEngine.projectGeometry(polylineBuilder.parts[0].points.array()[i+1], to: .webMercator()) as! AGSPoint
                segTable.append(Segment.init(index: i, source: point, target: nextPoint))
            }
            
            else {
                let point = AGSGeometryEngine.projectGeometry(polylineBuilder.parts[0].points.array()[i], to: .webMercator()) as! AGSPoint
                segTable.append(Segment.init(index: i, source: point, target: nil))
            }
            
            print("Created seg table")
        }
    }
    
    
    func createEdgeTable(trackPoint: AGSPoint) -> AGSPoint {
        print("creating edge table")
        edgeTable.removeAll()
        let beta = DEFAULT_BETA
        let sigma_z = DEFAULT_SIGMA_Z
        let c = 1 / (sigma_z * sqrt(2 * Double.pi))
        let b = 1 / beta
        
        for seg in segTable {
            guard let startx = seg.source?.x, let starty = seg.source?.y, let endx = seg.target?.x, let endy = seg.target?.y else {continue}
            let x = trackPoint.x
            let y = trackPoint.y
            let cross = (endx-startx)*(x-startx) + (endy-starty)*(y-starty)
            let d2 = (endx-startx)*(endx-startx) + (endy-starty)*(endy-starty)
            let r = cross / d2;
            let outx = startx + r * (endx - startx);
            let outy = starty + r * (endy - starty);
            if cross <= 0 {
                let des = sqrt(((x - startx) * (x - startx) + (y - endy) * (y - endy)))
                let wmDist = round(des)
                if wmDist < DEFAULT_MAX_ROUTE_DISTANCE {
                    let emissionProb = c * exp(-(pow(wmDist, 2)))
                    let delta = abs(routeDistance(seq: seq, index: seg.index, outx: outx, outy: outy) - greatCircleValue(seq: seq, outx: outx, outy: outy))
                    let transitionProb = b * exp(-delta)
                    let jointProb = emissionProb + transitionProb
                    edgeTable.append(Edge.init(index: seg.index, distanceToEdge: wmDist, matchPoint: [outx, outy], prob: jointProb))
                }
            }
            
            if (cross < d2 && cross > 0) {
                let r = cross / d2;
                let outx = startx + r * (endx - startx);
                let outy = starty + r * (endy - starty);
                let des = sqrt(
                    (x - outx) * (x - outx) + (y - outy) * (y - outy)
                );
                
                let wmDist = round(des)
                if wmDist < DEFAULT_MAX_ROUTE_DISTANCE {
                    let emissionProb = c * exp(-(pow(wmDist, 2)))
                    let delta = abs(routeDistance(seq: seq, index: seg.index, outx: outx, outy: outy) - greatCircleValue(seq: seq, outx: outx, outy: outy))
                    let transitionProb = b * exp(-delta)
                    let jointProb = emissionProb + transitionProb
                    edgeTable.append(Edge.init(index: seg.index, distanceToEdge: wmDist, matchPoint: [outx, outy], prob: jointProb))
                }
            }
            
            print("created edge table")
        }
        
        if edgeTable.count > 0 {
            print("searching for map point")
            return searchMatchPoint()
        }
        else {
            print("returning original point")
            offCourseRouteCount += 1
            if offCourseRouteCount == 3 {
                delegate?.shouldReRoute(point: trackPoint)
                offCourseRouteCount = 0
            }
            return trackPoint
        }
    }
    
    func routeDistance(seq:Int, index:Int, outx:Double, outy:Double) -> Double {
        var sumDist = 0.0
        for i in seq..<index {
            let seg = segTable[i]
            guard let startx = seg.source?.x, let starty = seg.source?.y, let endx = seg.target?.x, let endy = seg.target?.y else {continue}
            let routeDist = sqrt(pow(endx-startx, 2) + pow(endy-starty, 2))
            sumDist = sumDist + routeDist
        }
        
        sumDist = sumDist + sqrt(pow((outx - (segTable[seq].source?.x ?? 0)), 2) + pow((outy - (segTable[seq].source?.y ?? 0)), 2))
        
        return sumDist
    }
    
    func greatCircleValue(seq: Int, outx: Double, outy: Double) -> Double {
        return sqrt(pow((outx - (segTable[seq].source?.x ?? 0)), 2) + pow((outy - (segTable[seq].source?.y ?? 0)), 2))
    }
    
    func searchMatchPoint() -> AGSPoint {
        var list = Edge(index: 0, distanceToEdge: 0, matchPoint: [], prob: 0)
        for edge in edgeTable {
            if edge.prob >= list.prob {
                list.index = edge.index
                list.matchPoint = edge.matchPoint
                list.prob = edge.prob
            }
        }
        print(list)
        let point = AGSPoint(x: list.matchPoint[0], y: list.matchPoint[1], spatialReference: .webMercator())
        //delegate?.didMatchPoint(point: point)
        return point
    }
    
}

protocol MapMatchingServiceDelegate: class {
    func didMatchPoint(point: AGSPoint)
    func shouldReRoute(point: AGSPoint)
}
