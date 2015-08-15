//
//  ScrubbingBar.swift
//  VLCTestApp
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

import Cocoa

@objc
public class ScrubbingBar : NSView {
    dynamic var doubleValue: Double = 0;

    public override var intrinsicContentSize: NSSize {
        get {
            return NSSize(width: 32, height: 12);
        }
    }
    
    public override func updateTrackingAreas() {
        self.addTrackingArea(NSTrackingArea(rect: self.bounds, options: [NSTrackingAreaOptions.MouseMoved, NSTrackingAreaOptions.ActiveInActiveApp], owner: self, userInfo: nil))
    }
    
    public override func mouseMoved(ev: NSEvent) {
        let point = self.convertPoint(ev.locationInWindow, fromView: nil);
        self.doubleValue = Double(point.x) / Double(self.bounds.width);
        self.needsDisplay = true;
    }
    
    public override var allowsVibrancy: Bool {
        get {
            return true;
        }
    }

    public override func drawRect(dirtyRect: NSRect) {
        let b = self.bounds;
    
        NSColor(calibratedWhite: 0.8, alpha: 0.5).setFill();
        NSRectFill(NSRect(x: 0, y: b.size.height / 2, width: b.size.width, height: 1));
        NSColor(calibratedWhite: 0.8, alpha: 0.75).setFill();
        NSRectFill(NSRect(x: CGFloat(self.doubleValue) * b.size.width, y: 0, width: 1, height: b.size.height));
    }
}
