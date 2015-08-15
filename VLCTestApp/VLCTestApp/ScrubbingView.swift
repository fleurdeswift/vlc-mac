//
//  ScrubbingView.swift
//  VLCTestApp
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

import Cocoa

@objc
public class ScrubbingView : NSView {
    public override var intrinsicContentSize: NSSize {
        get {
            return NSSize(width: 32, height: 80);
        }
    }
}
