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
    
    @IBOutlet weak var beforeLabel: NSTextField!
    @IBOutlet weak var afterLabel: NSTextField!
    @IBOutlet weak var imageColorWell: NSColorWell!
    
    func applicationDidFinishLaunching(_ aNotification: Notification) {

        let canvasDims = NSSize(width: window.frame.width, height: window.frame.height)
        let canvasPos = NSMakePoint(0,0)
        let canvas = DragView(frame: NSMakeRect(canvasPos.x, canvasPos.y, canvasDims.width, canvasDims.height))
        canvas.delegate = self
        canvas.wantsLayer = true

        
        window.contentView!.addSubview(canvas)
    }

    func fastColorAvg(_ inputImage: CIImage) -> NSColor? {

        guard let avgFilter = CIFilter(name: "CIAreaAverage") else { return nil }
        avgFilter.setValue(inputImage, forKey: kCIInputImageKey)
        let imageRect = inputImage.extent
        avgFilter.setValue(CIVector(cgRect: imageRect), forKey: kCIInputExtentKey)
        
        let newImage = NSImageFromCIImage(avgFilter.outputImage!)
        let newCol = extractColor(newImage)
        return newCol
    }
    
    func NSImageFromCIImage(_ theCIImage: CIImage) -> NSImage {
        let rep = NSCIImageRep(ciImage:theCIImage)
        let newImage = NSImage(size: rep.size)
        newImage.addRepresentation(rep)
        return newImage
    }
    
    func CIImageFromNSImage(_ inputImage: NSImage) ->CIImage? {
        if let imageData = inputImage.tiffRepresentation,
            let bitmap = NSBitmapImageRep(data: imageData) {
            return CIImage(bitmapImageRep: bitmap)
        }
        return nil
    }
    
    func extractColor(_ theImage: NSImage) -> NSColor? {
        var pixel = Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        if let imageData = theImage.tiffRepresentation {
            guard let source = CGImageSourceCreateWithData(imageData as CFData, nil) else { return nil }
            let maskRef = CGImageSourceCreateImageAtIndex(source, 0, nil)
            let colorSpace = CGColorSpaceCreateDeviceRGB()
//            var bitmapInfo = CGBitmapInfo.ByteOrder32Big.union(CGBitmapInfo(rawValue: CGImageAlphaInfo.PremultipliedLast.rawValue))
            let context = CGContext(data: &pixel, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            
            context?.draw(maskRef!, in: CGRect(x: 0, y: 0,width: 1,height: 1))
//            context?.draw(in: CGRect(x: 0, y: 0,width: 1,height: 1),image: maskRef!)

            let r = CGFloat(pixel.red) / CGFloat(255.0)
            let g = CGFloat(pixel.green) / CGFloat(255.0)
            let b = CGFloat(pixel.blue) / CGFloat(255.0)
            let a = CGFloat(pixel.alpha) / CGFloat(255.0)
            return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
        }
        return nil
    }
    
    
    func extractColorFromCIImage(_ theImage: CIImage) ->NSColor {
        var pixel = Pixel(red: 0, green: 0, blue: 0, alpha: 0)
        let curCIContext = NSGraphicsContext.current()?.ciContext
        //let extent = theImage.extent
        curCIContext?.render(theImage, toBitmap: &pixel, rowBytes: 4, bounds: theImage.extent , format: kCIFormatARGB8, colorSpace: CGColorSpaceCreateDeviceRGB())
        
        let r = CGFloat(pixel.green) / CGFloat(255.0)
        let g = CGFloat(pixel.blue) / CGFloat(255.0)
        let b = CGFloat(pixel.alpha) / CGFloat(255.0)
        let a = CGFloat(pixel.red) / CGFloat(255.0)
        return NSColor(calibratedRed: r, green: g, blue: b, alpha: a)
    }
    
    func makeSingleColorImage(_ theColor: NSColor, theSize: NSSize) ->NSImage {
        let theImage = NSImage(size: theSize)
        theImage.lockFocus()
        theColor.setFill()
        NSBezierPath.fill(NSRect(x: 0, y: 0, width: theSize.width, height: theSize.height))
        theImage.unlockFocus()
        return theImage
    }
    
    func applyOverlayFilter(_ theImage: CIImage, invColorAvgImage: CIImage) -> CIImage? {
        
        guard let overlayFilter = CIFilter(name: "CIOverlayBlendMode") else { return nil }
        overlayFilter.setValue(invColorAvgImage, forKey: kCIInputImageKey)
        overlayFilter.setValue(theImage, forKey: kCIInputBackgroundImageKey)

        return overlayFilter.outputImage
    }
    
    func dropViewDidReceive(theURL: URL) {
        
        guard let startCIImage = CIImage(contentsOf: theURL) else { return }
        guard let avgCol = fastColorAvg(startCIImage) else { return }
        
        beforeImage.image = NSImageFromCIImage(startCIImage)
        beforeLabel.isHidden = false
        
        let complement = NSColor(calibratedRed: 1-avgCol.redComponent, green: 1-avgCol.greenComponent, blue: 1-avgCol.blueComponent, alpha: avgCol.alphaComponent)

        redLabel.stringValue = NSString(format:"0x%2x",UInt(avgCol.redComponent*255)) as String
        greenLabel.stringValue = NSString(format:"0x%2x",UInt(avgCol.greenComponent*255)) as String
        blueLabel.stringValue = NSString(format:"0x%2x",UInt(avgCol.blueComponent*255)) as String
        alphaLabel.stringValue = NSString(format:"0x%2x",UInt(avgCol.alphaComponent*255)) as String

        imageColorWell.color = avgCol
        
        //window.backgroundColor = complement
        let imageSize = startCIImage.extent.size

        let invImage = makeSingleColorImage(complement, theSize: imageSize)
        guard let correctedCIImage = applyOverlayFilter(startCIImage, invColorAvgImage: CIImageFromNSImage(invImage)!) else { return }
        
        afterImage.image = NSImageFromCIImage(correctedCIImage)// anImage
        afterLabel.isHidden = false
        
        saveCIImageAsPNG(correctedCIImage, toPath: "/Users/teo/tmp/notred.png")

    }
    
    func saveCIImageAsPNG(_ theImage: CIImage, toPath: String) {
        let bitmap = NSBitmapImageRep(ciImage: theImage) as NSBitmapImageRep
        let pngData = bitmap.representation(using: NSPNGFileType, properties: [:])
        do {
            try pngData?.write(to: URL(fileURLWithPath: toPath))
        } catch {
            print("Error writing PNG data to file path \(toPath): \(error)")
        }
    }
}

protocol DropViewDelegate {
    func dropViewDidReceive(theURL: URL)
}

class DragView: NSView {
    var delegate: DropViewDelegate?
    
    override init(frame: NSRect) {
        super.init(frame: frame)
        let types = [NSFilenamesPboardType]
        register(forDraggedTypes: types)
    }
    

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        return NSDragOperation.copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        let pboard = sender.draggingPasteboard()
        let myArray = pboard.types! as NSArray
        
        if myArray.contains(NSURLPboardType),
            let fileURL = NSURL(from: pboard) {
                delegate?.dropViewDidReceive(theURL: fileURL as URL)
        }
        return true
    }
}
