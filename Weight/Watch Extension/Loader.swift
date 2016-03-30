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
    let duration: NSTimeInterval
    private var timer: NSTimer?
    private(set) var animating: Bool = false
    
    convenience init(controller: WKInterfaceController, interfaceImages: [WKInterfaceImage]) {
        let size = controller.contentFrame.size
        self.init(controller: controller, interfaceImages: interfaceImages, tintColor: .whiteColor(), size: size, duration: 1)
    }
    
    init(controller: WKInterfaceController, interfaceImages: [WKInterfaceImage], tintColor: UIColor, size: CGSize, duration: NSTimeInterval) {
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
        timer = NSTimer.scheduledTimerWithTimeInterval(duration, target: self, selector: #selector(Loader.setupAnimation), userInfo: nil, repeats: true)
        animating = true
    }
    
    func stopAnimating() {
        timer?.invalidate()
        timer = nil
        animating = false
    }
}


class Animation {

    func drawImage(size: CGSize, tintColor: UIColor) -> UIImage {
        let scale = WKInterfaceDevice.currentDevice().screenScale
        
        UIGraphicsBeginImageContextWithOptions(size, false, scale)
        
        let center = CGPointMake(size.width/2, size.height/2)
        let radius = min(size.width/2, size.height/2) / 2
        let circlePath = UIBezierPath()
        circlePath.addArcWithCenter(center, radius: radius, startAngle: 0, endAngle: CGFloat(2 * M_PI), clockwise: true)
        circlePath.lineWidth = 2
        tintColor.setFill()
        circlePath.fill()
        tintColor.setStroke()
        circlePath.stroke()
    
        let img = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext()
        
        return img
    }
    
    func setupAnimationInController(controller: WKInterfaceController, images: [WKInterfaceImage], size: CGSize, tintColor: UIColor, duration: NSTimeInterval) {
        let image = images.first!
        let img = drawImage(size, tintColor: tintColor)
        image.setImage(img)
        image.setAlpha(1)
        image.setWidth(0)
        image.setHeight(0)
        image.setHorizontalAlignment(.Center)
        image.setVerticalAlignment(.Center)
        
        controller.animateWithDuration(duration) {
            image.setWidth(size.width)
            image.setHeight(size.height)
            image.setAlpha(0)
        }
    }
}


