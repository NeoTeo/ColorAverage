//
//  AppDelegate.swift
//  ColorAverage
//
//  Created by Teo on 08/02/15.
//  Copyright (c) 2015 Teo. All rights reserved.
//

import Cocoa

struct Pixel {
    var red: UInt8
    var green: UInt8
    var blue: UInt8
    var alpha: UInt8
}

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    @IBOutlet weak var window: NSWindow!

    func applicationDidFinishLaunching(aNotification: NSNotification) {
        // Insert code here to initialize your application
        let canvasDims = NSSize(width: 300, height: 300)
        let canvasPos = NSMakePoint(0,0)
        let canvas = NSView(frame: NSMakeRect(canvasPos.x, canvasPos.y, canvasDims.width, canvasDims.height))
        let label = NSTextField(frame: NSMakeRect(canvasPos.x+100, canvasPos.y+250, 100, 30))
        label.stringValue = "Hello Swift"
        
        canvas.wantsLayer = true

        if let newImage = fastColorAvg("marty") {
            var theImageView = NSImageView(frame: NSMakeRect(10, 0, 200, 200))
            theImageView.image = newImage
            canvas.addSubview(theImageView)
            
            let avgCol = extractColor(newImage)
            
            let complement = NSColor(calibratedRed: 1-avgCol.redComponent, green: 1-avgCol.greenComponent, blue: 1-avgCol.blueComponent, alpha: avgCol.alphaComponent)
            
            print("Red: \(avgCol.redComponent), ")
            print("green: \(avgCol.greenComponent), ")
            print("blue: \(avgCol.blueComponent), ")
            println("alpha: \(avgCol.alphaComponent)")
            println("The complement:")
            print("Red: \(complement.redComponent), ")
            print("green: \(complement.greenComponent), ")
            print("blue: \(complement.blueComponent), ")
            println("alpha: \(complement.alphaComponent)")
            
            window.backgroundColor = complement

        }
        
        //let avgCol = colorAvg("dontpanic")
        
        canvas.addSubview(label)
        

        window.contentView.addSubview(canvas)
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }

    func fastColorAvg(aFileURL: String)-> NSImage? {
        if let fileURL = NSURL(fileURLWithPath: "/Users/teo/source/Apple/OSX/ColorAverage/ColorAverage/toored.jpg") {
            
            var myCIImage = CIImage(contentsOfURL: fileURL)
            let avgFilter = CIFilter(name: "CIAreaAverage")
            avgFilter.setValue(myCIImage, forKey: kCIInputImageKey)
            let imageRect = myCIImage.extent()
            avgFilter.setValue(CIVector(CGRect: imageRect), forKey: kCIInputExtentKey)
            
            let rep = NSCIImageRep(CIImage:avgFilter.outputImage)
            let newImage = NSImage(size: rep.size)
            newImage.addRepresentation(rep)
            return newImage
//            NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
//            [nsImage addRepresentation:rep];

        }
        return nil
    }
    
    func extractColor(theImage: NSImage) -> NSColor {
        var pixel = Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        if let imageData = theImage.TIFFRepresentation {
            var source = CGImageSourceCreateWithData(imageData as CFDataRef, nil)
            let maskRef = CGImageSourceCreateImageAtIndex(source, UInt(0), nil)
            var colorSpace = CGColorSpaceCreateDeviceRGB()
            var bitmapInfo = CGBitmapInfo.ByteOrder32Big | CGBitmapInfo(CGImageAlphaInfo.PremultipliedLast.rawValue)
            var context = CGBitmapContextCreate(&pixel, 1, 1, 8, 4, colorSpace, bitmapInfo)
            
            CGContextDrawImage(context, CGRectMake(0, 0, 1, 1),maskRef)

            return NSColor(calibratedRed: CGFloat(pixel.red) / CGFloat(255.0),
                            green: CGFloat(pixel.green) / CGFloat(255.0),
                            blue: CGFloat(pixel.blue) / CGFloat(255.0),
                            alpha: CGFloat(pixel.alpha) / CGFloat(255.0))
        }
        return NSColor()
    }
    
//    func colorAvg(canvas: NSView) -> NSColor {
    func colorAvg(imageName: String) -> NSColor {
        //CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue)
        var rgba: [CGFloat] = [2.0,2,3,4]
        let theImage = NSImage(named: imageName)
        
        let imageRep = theImage?.representations[0] as NSImageRep?
        theImage?.representations.count
        if imageRep == nil { return NSColor(calibratedRed: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3]) }
        
        let imageW = imageRep!.pixelsWide
        let imageH = imageRep!.pixelsHigh
        
        var pixels = [Pixel](count: imageW*imageH, repeatedValue: Pixel(red: 0, green: 0, blue: 0, alpha: 0))
        //    var theImageView = NSImageView(frame: NSMakeRect(10, 0, 200, 200))
        //    theImageView.image = theImage
        //    canvas.addSubview(theImageView)
        
        if let imageData = theImage?.TIFFRepresentation {
            var source = CGImageSourceCreateWithData(imageData as CFDataRef, nil)
            let maskRef = CGImageSourceCreateImageAtIndex(source, UInt(0), nil)
            
            var colorSpace = CGColorSpaceCreateDeviceRGB()
            var bitmapInfo = CGBitmapInfo.ByteOrder32Big | CGBitmapInfo(CGImageAlphaInfo.PremultipliedLast.rawValue)
            var context = CGBitmapContextCreate(&pixels, UInt(imageW), UInt(imageH), 8, 4*UInt(imageW), colorSpace, bitmapInfo)
            
            CGContextDrawImage(context, CGRectMake(0, 0, CGFloat(imageW), CGFloat(imageH)),maskRef)
            
            var pixelData = CGDataProviderCopyData(CGImageGetDataProvider(maskRef))
            var data: UnsafePointer<UInt8> = CFDataGetBytePtr(pixelData)
            
            let yPos = 0
            let xPos = 0
            for yPos in 0..<imageH {
                for xPos in 0..<imageW {
                    let pixPos = (imageW * yPos) + xPos
                    let aPixel = pixels[pixPos]
                    rgba[0] += CGFloat(aPixel.red) / CGFloat(255.0)
                    rgba[1] += CGFloat(aPixel.green) / CGFloat(255.0)
                    rgba[2] +=  CGFloat(aPixel.blue) / CGFloat(255.0)
                    rgba[3] += CGFloat(aPixel.alpha) / CGFloat(255.0)
                }
            }
            let total = CGFloat(imageW*imageH)
            rgba[0] = rgba[0] / total
            rgba[1] = rgba[1] / total
            rgba[2] = rgba[2] / total
            rgba[3] = rgba[3] / total
            //        var theImageView = NSImageView(frame: NSMakeRect(20, 0, 200, 200))
            //        theImageView.image = NSImage(CGImage: maskRef, size: NSZeroSize)
            //        canvas.addSubview(theImageView)
        }
        return NSColor(calibratedRed: rgba[0], green: rgba[1], blue: rgba[2], alpha: rgba[3])
    }

}

