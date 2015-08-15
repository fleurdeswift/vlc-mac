//
//  AppDelegate.swift
//  VLCTestApp
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

import Cocoa
import VLCKit

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {
    var mediaPlayer: VLCMediaPlayer?;


    func applicationDidFinishLaunching(aNotification: NSNotification) {
        dispatch_async(dispatch_get_main_queue()) {
            let documentController = NSDocumentController.sharedDocumentController();
        
            do {
                let doc = try documentController.makeDocumentWithContentsOfURL(NSURL(fileURLWithPath: "/Users/rhoule/Movies/Library/DropBox/29554_01_720p.mp4"), ofType: "DocumentType");
            
                doc.makeWindowControllers();
                doc.showWindows();

                for controller in doc.windowControllers {
                    if let window = controller.window {
                        window.makeKeyAndOrderFront(self);
                        window.minSize = NSSize(width: 160, height: 120);
                    }
                }
                
                documentController.addDocument(doc);
            }
            catch let error as NSError {
                NSAlert(error: error).runModal();
            }
            catch {
            }
        }
    }

    func applicationWillTerminate(aNotification: NSNotification) {
        // Insert code here to tear down your application
    }


}

