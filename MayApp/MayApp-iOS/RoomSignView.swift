//
//  RoomSignView.swift
//  MayApp
//
//  Created by Russell Ladd on 4/16/17.
//  Copyright © 2017 University of Michigan. All rights reserved.
//

import UIKit

final class RoomSignView: UIView {
    
    let label = UILabel()
    
    init() {
        
        super.init(frame: CGRect.zero)
        
        backgroundColor = #colorLiteral(red: 0.5568627715, green: 0.3529411852, blue: 0.9686274529, alpha: 1)
        layer.cornerRadius = 8.0
        
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = .boldSystemFont(ofSize: 17.0)
        label.textColor = .white
        
        addSubview(label)
        
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 5.0),
            label.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5.0),
            label.topAnchor.constraint(equalTo: topAnchor, constant: 2.0),
            label.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -2.0)
        ])
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
