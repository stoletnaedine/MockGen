//
//  Helpers.swift
//  MockGen
//
//  Created by MockGen on 2.09.2026.
//  Copyright © 2026 MockGen. All rights reserved.
//

import SwiftUI

struct Border: Shape {
    var width: CGFloat = 1
    var edges: [Edge] = [.top, .bottom, .leading, .trailing]
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        for edge in edges {
            switch edge {
            case .top:
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            case .bottom:
                path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            case .leading:
                path.move(to: CGPoint(x: rect.minX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            case .trailing:
                path.move(to: CGPoint(x: rect.maxX, y: rect.minY))
                path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            }
        }
        
        return path
    }
}

extension View {
    func border(width: CGFloat = 1, edges: [Edge] = [.top, .bottom, .leading, .trailing], color: Color = .gray) -> some View {
        self.overlay(Border(width: width, edges: edges).stroke(color, lineWidth: width))
    }
}
