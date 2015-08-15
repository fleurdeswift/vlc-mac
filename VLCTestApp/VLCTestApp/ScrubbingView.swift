//
//  ScrubbingView.swift
//  VLCTestApp
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

import Cocoa
import VLCKit

@objc
public class ScrubbingView : NSView {
    public override var intrinsicContentSize: NSSize {
        get {
            return NSSize(width: 32, height: 80);
        }
    }

    public var mediaPlayer: VLCMediaPlayer? {
        didSet {
            if let m = mediaPlayer {
                let layer = VLCOpenGLLayer();

                layer.mediaPlayer  = m;
                layer.asynchronous = true;
                self.wantsLayer    = true;
                self.layer         = layer;
                layer.bounds = NSRect(x: 0, y: 0, width: 64, height: 64);
            }
            else {
                self.layer = nil;
            }
        }
    }
}
