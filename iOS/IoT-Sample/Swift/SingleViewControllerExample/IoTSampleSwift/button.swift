//
//  button.swift
//  IoTSampleSwift
//
//  Created by Michael Vartanian on 2/22/20.
//  Copyright © 2020 Amazon. All rights reserved.
//

import Foundation
import UIKit

extension UIButton {

    func pulsate() {

        let pulse = CASpringAnimation(keyPath: "transform.scale")
        pulse.duration = 0.2
        pulse.fromValue = 0.95
        pulse.toValue = 1.0
        pulse.autoreverses = true
        pulse.repeatCount = 2
        pulse.initialVelocity = 0.5
        pulse.damping = 1.0

        layer.add(pulse, forKey: "pulse")
    }

    func flash() {

        let flash = CABasicAnimation(keyPath: "opacity")
        flash.duration = 0.2
        flash.fromValue = 1
        flash.toValue = 0.1
        flash.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        flash.autoreverses = true
        flash.repeatCount = 3

        layer.add(flash, forKey: nil)
    }

    func shake() {

        let shake = CABasicAnimation(keyPath: "position")
        shake.duration = 0.05
        shake.repeatCount = 2
        shake.autoreverses = true

        let fromPoint = CGPoint(x: center.x - 5, y: center.y)
        let fromValue = NSValue(cgPoint: fromPoint)

        let toPoint = CGPoint(x: center.x + 5, y: center.y)
        let toValue = NSValue(cgPoint: toPoint)

        shake.fromValue = fromValue
        shake.toValue = toValue

        layer.add(shake, forKey: "position")
    }

    func shrink() {

        let shrink = CABasicAnimation(keyPath: "transform.scale")
        shrink.duration = 0.2
        shrink.fromValue = 1.0
        shrink.toValue = 0.95
        layer.add(shrink, forKey: "transform.scale")
    }

    func expand() {

        let expand = CABasicAnimation(keyPath: "transform.scale")
        expand.duration = 0.2
        expand.fromValue = 1.0
        expand.toValue = 1/0.95
        layer.add(expand, forKey: "transform.scale")
    }

    func applyGradient(colors: [CGColor]) {

        let gradientLayer = CAGradientLayer()
        gradientLayer.colors = colors
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 0)
        gradientLayer.frame = self.bounds
        self.layer.insertSublayer(gradientLayer, at: 0)
    }

    enum axis {
        case vertical, horizontal
    }

    func setGradientBackgroundColor(colors: [UIColor], axis: axis, cornerRadius: CGFloat? = nil, apply: ((UIView) -> ())? = nil) {
        self.layoutIfNeeded()

        let cgColors = colors.map { $0.cgColor }

        let gradient: CAGradientLayer = CAGradientLayer()
        gradient.colors = cgColors
        gradient.locations = [0.0, 1.0]

        if axis == .horizontal {
            gradient.startPoint = CGPoint(x: 0.0, y: 1.0)
            gradient.endPoint = CGPoint(x: 1.0, y: 1.0)
        }

        gradient.frame = self.bounds
        self.layer.insertSublayer(gradient, at: 0)

        guard let cornerRadius = cornerRadius else { return }

        let circularPath = CGMutablePath()

        circularPath.move(to: CGPoint.init(x: cornerRadius, y: 0))
        circularPath.addLine(to: CGPoint.init(x: self.bounds.width - cornerRadius, y: 0))
        circularPath.addQuadCurve(to: CGPoint.init(x: self.bounds.width, y: cornerRadius), control: CGPoint.init(x: self.bounds.width, y: 0))
        circularPath.addLine(to: CGPoint.init(x: self.bounds.width, y: self.bounds.height - cornerRadius))
        circularPath.addQuadCurve(to: CGPoint.init(x: self.bounds.width - cornerRadius, y: self.bounds.height), control: CGPoint.init(x: self.bounds.width, y: self.bounds.height))
        circularPath.addLine(to: CGPoint.init(x: cornerRadius, y: self.bounds.height))
        circularPath.addQuadCurve(to: CGPoint.init(x: 0, y: self.bounds.height - cornerRadius), control: CGPoint.init(x: 0, y: self.bounds.height))
        circularPath.addLine(to: CGPoint.init(x: 0, y: cornerRadius))
        circularPath.addQuadCurve(to: CGPoint.init(x: cornerRadius, y: 0), control: CGPoint.init(x: 0, y: 0))

        let maskLayer = CAShapeLayer()
        maskLayer.path = circularPath
        maskLayer.fillRule = CAShapeLayerFillRule.evenOdd
        maskLayer.fillColor = UIColor.red.cgColor
        self.layer.mask = maskLayer

        apply?(self)
    }
}
