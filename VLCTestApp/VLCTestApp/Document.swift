//
//  Document.swift
//  VLCTestApp
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

import Cocoa
import VLCKit

public class Document: NSDocument {
    public override func windowControllerDidLoadNib(aController: NSWindowController) {
        super.windowControllerDidLoadNib(aController)
        // Add any code here that needs to be executed once the windowController has loaded the document's window.
    }

    public override class func autosavesInPlace() -> Bool {
        return false
    }

    public override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: "Main", bundle: nil)
        let windowController = storyboard.instantiateControllerWithIdentifier("Document Window Controller") as! NSWindowController
        self.addWindowController(windowController)
    }

    public override func dataOfType(typeName: String) throws -> NSData {
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    public override func readFromData(data: NSData, ofType typeName: String) throws {
        throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

    internal(set) public var vlc: VLC?;
    internal(set) public var media: VLCMedia?;

    public override func readFromURL(url: NSURL, ofType typeName: String) throws {
        self.vlc   = try VLC(arguments: ["--verbose=4", "--no-color", "--vout=iosurface"]);
        self.media = try VLCMedia(path: url.path!, withVLC: vlc!);
    }
}
