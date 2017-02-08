//
//  PolarInputView.swift
//  MayApp
//
//  Created by Russell Ladd on 2/7/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import UIKit

final class PolarInputView: UIControl {
    
    // MARK: Initializer
    
    let knob = UIView(frame: CGRect(x: 0.0, y: 0.0, width: 44.0, height: 44.0))
    
    let gestureRecognizer = UILongPressGestureRecognizer()
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        
        shapeLayer.fillColor = UIColor(white: 0.9, alpha: 1.0).cgColor
        
        updatePath()
        
        knob.backgroundColor = UIColor.white
        knob.layer.cornerRadius = 22.0
        knob.center = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
        addSubview(knob)
        
        gestureRecognizer.minimumPressDuration = 0.0
        gestureRecognizer.addTarget(self, action: #selector(handlePan))
        addGestureRecognizer(gestureRecognizer)
    }
    
    // MARK: Layer type
    
    override class var layerClass: AnyClass {
        return CAShapeLayer.self
    }
    
    var shapeLayer: CAShapeLayer {
        return layer as! CAShapeLayer
    }
    
    func updatePath() {
        
        shapeLayer.path = UIBezierPath(ovalIn: bounds).cgPath
    }
    
    // MARK: Frame change
    
    override var bounds: CGRect {
        didSet {
            
            updatePath()
        }
    }
    
    // MARK: Gesture recognizer
    
    var gestureOriginalPosition = CGPoint.zero
    
    func handlePan() {
        
        let position = gestureRecognizer.location(in: nil)
        
        switch gestureRecognizer.state {
            
        case .began:
            gestureOriginalPosition = position
            
        case .changed:
            let translation = CGPoint(x: position.x - gestureOriginalPosition.x, y: position.y - gestureOriginalPosition.y)
            
            let angle = atan2(translation.y, translation.x)
            let radius = min(sqrt(translation.x * translation.x + translation.y * translation.y) / ((bounds.width - knob.bounds.width) / 2.0), 1.0)
            
            knob.center = CGPoint(x: bounds.width / 2.0 + cos(angle) * radius * (bounds.width - knob.bounds.width) / 2.0, y: bounds.height / 2.0 + sin(angle) * radius * (bounds.height - knob.bounds.height) / 2.0)
            
            value = PolarPoint(angle: angle, radius: radius)
            
            sendActions(for: .valueChanged)
            
        case .ended, .cancelled:
            knob.center = CGPoint(x: bounds.width / 2.0, y: bounds.height / 2.0)
            
            value = PolarPoint.zero
            
            sendActions(for: .valueChanged)
            
        default: break
        }
    }
    
    // MARK: Value
    
    struct PolarPoint {
        
        var angle: CGFloat
        var radius: CGFloat
        
        static let zero = PolarPoint(angle: 0.0, radius: 0.0)
    }
    
    var value = PolarPoint.zero
}
