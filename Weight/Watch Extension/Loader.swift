//
//  Loader.swift
//  Weight
//
//  Created by Tobias Due Munk on 08/09/15.
//  Copyright © 2015 Tobias Due Munk. All rights reserved.
//

import WatchKit


class Loader {
    
    weak var controller: WKInterfaceController?
    let interfaceImages: [WKInterfaceImage]
    let tintColor: UIColor
    let size: CGSize
    let duration: TimeInterval
    private var timer: Timer?
    private(set) var animating: Bool = false
    
    convenience init(controller: WKInterfaceController, interfaceImages: [WKInterfaceImage]) {
        let size = controller.contentFrame.size
        self.init(controller: controller, interfaceImages: interfaceImages, tintColor: .white, size: size, duration: 1)
    }
    
    init(controller: WKInterfaceController, interfaceImages: [WKInterfaceImage], tintColor: UIColor, size: CGSize, duration: TimeInterval) {
        self.controller = controller
        self.interfaceImages = interfaceImages
        self.size = size
        self.duration = duration
        self.tintColor = tintColor
    }

    @objc func setupAnimation() {
        let animation = Animation()
        guard let controller = controller else { return }
        animation.setupAnimationInController(controller, images: interfaceImages, size: size, tintColor: tintColor, duration: duration)
    }
    
    func startAnimating() {
        timer = Timer.scheduledTimer(timeInterval: duration, target: self, selector: #selector(Loader.setupAnimation), userInfo: nil, repeats: true)
        animating = true
    }
    
    func stopAnimating() {
        timer?.invalidate()
        timer = nil
        animating = false
    }
}


class Animation {

    func drawImage(_ size: CGSize, tintColor: UIColor) -> UIImage {
        let scale = WKInterfaceDevice.current().screenScale
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        let center = CGPoint(x: size.width/2, y: size.height/2)
        let radius = min(size.width/2, size.height/2) / 2
        let circlePath = UIBezierPath()
        circlePath.addArc(withCenter: center, radius: radius, startAngle: 0, endAngle: 2 * .pi, clockwise: true)
        circlePath.lineWidth = 2
        tintColor.setFill()
        circlePath.fill()
        tintColor.setStroke()
        circlePath.stroke()
    
        let img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        
        return img!
    }
    
    func setupAnimationInController(_ controller: WKInterfaceController, images: [WKInterfaceImage], size: CGSize, tintColor: UIColor, duration: TimeInterval) {
        let image = images.first!
        let img = drawImage(size, tintColor: tintColor)
        image.setImage(img)
        image.setAlpha(1)
        image.setWidth(0)
        image.setHeight(0)
        image.setHorizontalAlignment(.center)
        image.setVerticalAlignment(.center)
        
        controller.animate(withDuration: duration) {
            image.setWidth(size.width)
            image.setHeight(size.height)
            image.setAlpha(0)
        }
    }
}


