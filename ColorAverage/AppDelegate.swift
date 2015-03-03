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
class AppDelegate: NSObject, NSApplicationDelegate, DropViewDelegate {

    @IBOutlet weak var window: NSWindow!

    @IBOutlet weak var redLabel: NSTextField!
    @IBOutlet weak var greenLabel: NSTextField!
    @IBOutlet weak var blueLabel: NSTextField!
    @IBOutlet weak var alphaLabel: NSTextField!
    
    @IBOutlet weak var beforeImage: NSImageView!
    @IBOutlet weak var afterImage: NSImageView!
    
    @IBOutlet weak var imageColorWell: NSColorWell!
    
    func applicationDidFinishLaunching(aNotification: NSNotification) {

        let canvasDims = NSSize(width: window.frame.width, height: window.frame.height)
        let canvasPos = NSMakePoint(0,0)
        let canvas = DragView(frame: NSMakeRect(canvasPos.x, canvasPos.y, canvasDims.width, canvasDims.height))
        canvas.delegate = self
        canvas.wantsLayer = true

        
        window.contentView.addSubview(canvas)
    }

    func fastColorAvg(inputImage: CIImage) -> NSColor? {

        let avgFilter = CIFilter(name: "CIAreaAverage")
        avgFilter.setValue(inputImage, forKey: kCIInputImageKey)
        let imageRect = inputImage.extent()
        avgFilter.setValue(CIVector(CGRect: imageRect), forKey: kCIInputExtentKey)
        
        let newImage = NSImageFromCIImage(avgFilter.outputImage)
        let newCol = extractColor(newImage)
        return newCol
    }
    
    func NSImageFromCIImage(theCIImage: CIImage) -> NSImage {
        let rep = NSCIImageRep(CIImage:theCIImage)
        let newImage = NSImage(size: rep.size)
        newImage.addRepresentation(rep)
        return newImage
    }
    
    func CIImageFromNSImage(inputImage: NSImage) ->CIImage? {
        if let
            imageData = inputImage.TIFFRepresentation,
            bitmap = NSBitmapImageRep(data: imageData) {
            return CIImage(bitmapImageRep: bitmap)
        }
        return nil
    }
    
    func extractColor(theImage: NSImage) -> NSColor {
        var pixel = Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        if let imageData = theImage.TIFFRepresentation {
            var source = CGImageSourceCreateWithData(imageData as CFDataRef, nil)
            let maskRef = CGImageSourceCreateImageAtIndex(source, 0, nil)
            var colorSpace = CGColorSpaceCreateDeviceRGB()
            var bitmapInfo = CGBitmapInfo.ByteOrder32Big | CGBitmapInfo(CGImageAlphaInfo.PremultipliedLast.rawValue)
            var context = CGBitmapContextCreate(&pixel, 1, 1, 8, 4, colorSpace, bitmapInfo)
            
            CGContextDrawImage(context, CGRectMake(0, 0, 1, 1),maskRef)

            let r = CGFloat(pixel.red) / CGFloat(255.0)
            let g = CGFloat(pixel.green) / CGFloat(255.0)
            let b = CGFloat(pixel.blue) / CGFloat(255.0)
            let a = CGFloat(pixel.alpha) / CGFloat(255.0)
            return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
        }
        return NSColor()
    }
    
    func extractColorFromCIImage(theImage: CIImage) ->NSColor {
        var pixel = Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        let curCIContext = NSGraphicsContext.currentContext()?.CIContext
        let extent = theImage.extent()
        curCIContext?.render(theImage, toBitmap: &pixel, rowBytes: 4, bounds: theImage.extent() , format: kCIFormatARGB8, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        let r = CGFloat(pixel.green) / CGFloat(255.0)
        let g = CGFloat(pixel.blue) / CGFloat(255.0)
        let b = CGFloat(pixel.alpha) / CGFloat(255.0)
        let a = CGFloat(pixel.red) / CGFloat(255.0)
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    
    func makeSingleColorImage(theColor: NSColor, theSize: NSSize) ->NSImage {
        let theImage = NSImage(size: theSize)
        theImage.lockFocus()
        theColor.setFill()
        NSBezierPath.fillRect(NSMakeRect(0, 0, theSize.width, theSize.height))
        theImage.unlockFocus()
        return theImage
    }
    
    func applyOverlayFilter(theImage: CIImage, invColorAvgImage: CIImage) -> CIImage {
        
        let overlayFilter = CIFilter(name: "CIOverlayBlendMode")
        overlayFilter.setValue(invColorAvgImage, forKey: kCIInputImageKey)
        overlayFilter.setValue(theImage, forKey: kCIInputBackgroundImageKey)

        return overlayFilter.outputImage
    }
    
    func dropViewDidReceiveURL(theURL: NSURL) {
        let startCIImage = CIImage(contentsOfURL: theURL)
        beforeImage.image = NSImageFromCIImage(startCIImage)
        
        if let avgCol = fastColorAvg(startCIImage) {
            let complement = NSColor(calibratedRed: 1-avgCol.redComponent, green: 1-avgCol.greenComponent, blue: 1-avgCol.blueComponent, alpha: avgCol.alphaComponent)

            redLabel.stringValue = NSString(format:"0x%2x",UInt(avgCol.redComponent*255)) as! String
            greenLabel.stringValue = NSString(format:"0x%2x",UInt(avgCol.greenComponent*255)) as! String
            blueLabel.stringValue = NSString(format:"0x%2x",UInt(avgCol.blueComponent*255)) as! String
            alphaLabel.stringValue = NSString(format:"0x%2x",UInt(avgCol.alphaComponent*255)) as! String

            imageColorWell.color = avgCol
            
            //window.backgroundColor = complement
            let imageSize = startCIImage.extent().size

            let invImage = makeSingleColorImage(complement, theSize: imageSize)
            let correctedCIImage = applyOverlayFilter(startCIImage, invColorAvgImage: CIImageFromNSImage(invImage)!)
            
            afterImage.image = NSImageFromCIImage(correctedCIImage)// anImage
            saveCIImageAsPNG(correctedCIImage, toPath: "/Users/teo/tmp/notred.png")
        }
    }
    
    func saveCIImageAsPNG(theImage: CIImage, toPath: String) {
        let bitmap = NSBitmapImageRep(CIImage: theImage) as NSBitmapImageRep
        let pngData = bitmap.representationUsingType(NSBitmapImageFileType.NSPNGFileType, properties: [:])
        pngData?.writeToFile(toPath, atomically:false)
    }
}

protocol DropViewDelegate {
    func dropViewDidReceiveURL(theURL: NSURL)
}

class DragView: NSView, NSDraggingDestination {
    var delegate: DropViewDelegate?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        let types = [NSFilenamesPboardType]
        registerForDraggedTypes(types)
    }
    

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draggingEntered(sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.Copy
    }
    
    override func performDragOperation(sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard()
        let myArray = pboard.types! as NSArray
        
        if myArray.containsObject(NSURLPboardType),
            let fileURL = NSURL(fromPasteboard: pboard) {
                delegate?.dropViewDidReceiveURL(fileURL)
        }
        return true
    }
}