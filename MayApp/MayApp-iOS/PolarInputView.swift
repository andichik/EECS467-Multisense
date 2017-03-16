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
    
    let background = UIVisualEffectView(effect: UIBlurEffect(style: .extraLight))
    let knob = UIView()
    
    let gestureRecognizer = UILongPressGestureRecognizer()
    
    var knobXConstraint: NSLayoutConstraint!
    var knobYConstraint: NSLayoutConstraint!
    
    required init?(coder aDecoder: NSCoder) {
        
        super.init(coder: aDecoder)
        
        background.translatesAutoresizingMaskIntoConstraints = false
        background.clipsToBounds = true
        background.isUserInteractionEnabled = false
        addSubview(background)
        
        knob.translatesAutoresizingMaskIntoConstraints = false
        knob.isUserInteractionEnabled = false
        knob.backgroundColor = UIColor.white
        knob.layer.cornerRadius = 22.0
        knob.layer.shadowOpacity = 0.3
        knob.layer.shadowOffset = CGSize(width: 0.0, height: 2.0)
        knob.layer.shadowRadius = 5.0
        addSubview(knob)
        
        knobXConstraint = knob.centerXAnchor.constraint(equalTo: centerXAnchor)
        knobYConstraint = knob.centerYAnchor.constraint(equalTo: centerYAnchor)
        
        NSLayoutConstraint.activate([
            centerXAnchor.constraint(equalTo: background.centerXAnchor),
            centerYAnchor.constraint(equalTo: background.centerYAnchor),
            widthAnchor.constraint(equalTo: background.widthAnchor),
            heightAnchor.constraint(equalTo: background.heightAnchor),
            knobXConstraint,
            knobYConstraint,
            knob.widthAnchor.constraint(equalToConstant: 44.0),
            knob.heightAnchor.constraint(equalToConstant: 44.0),
        ])
    }
    
    // MARK: Layout
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        background.layer.cornerRadius = background.bounds.width / 2.0
    }
    
    // MARK: Tracking
    
    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        
        return true
    }
    
    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        
        let previousPosition = touch.previousLocation(in: self)
        let position = touch.location(in: self)
        
        let translation = CGPoint(x: position.x - previousPosition.x, y: position.y - previousPosition.y)
        
        let radius = (bounds.width - knob.bounds.width) / 2.0
        
        value.point = CGPoint(x: value.point.x + translation.x / radius, y: value.point.y + translation.y / radius)
        
        sendActions(for: .valueChanged)
        
        return true
    }
    
    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        endOrCancelTracking()
    }
    
    override func cancelTracking(with event: UIEvent?) {
        endOrCancelTracking()
    }
    
    func endOrCancelTracking() {
        
        
        
        UIView.animate(withDuration: 0.25) {
            self.value = PolarPoint.zero
            self.layoutIfNeeded()
        }
        
        sendActions(for: .valueChanged)
    }
    
    // MARK: Value
    
    struct PolarPoint {
        
        var point: CGPoint
        
        var angle: CGFloat {
            return point.x.isZero && point.y.isZero ? 0.0 : atan2(point.y, point.x)
        }
        
        var radius: CGFloat {
            return min(sqrt(point.x * point.x + point.y * point.y), 1.0)
        }
        
        var constrainedPoint: CGPoint {
            return CGPoint(x: radius * cos(angle), y: radius * sin(angle))
        }
        
        static let zero = PolarPoint(point: CGPoint.zero)
    }
    
    var value = PolarPoint.zero {
        didSet {
            knobXConstraint.constant = value.constrainedPoint.x * (bounds.width - knob.bounds.width) / 2.0
            knobYConstraint.constant = value.constrainedPoint.y * (bounds.height - knob.bounds.height) / 2.0
        }
    }
}
