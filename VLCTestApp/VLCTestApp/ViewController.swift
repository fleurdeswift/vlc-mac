//
//  ViewController.swift
//  VLCTestApp
//
//  Copyright © 2015 Fleur de Swift. All rights reserved.
//

import Cocoa
import VLCKit

func CGImageWriteToFile(image: CGImageRef, _ path: String) -> Bool {
    let url = NSURL(fileURLWithPath: path);
    let mdestination = CGImageDestinationCreateWithURL(url, kUTTypePNG, 1, nil);

    if let destination = mdestination {
        CGImageDestinationAddImage(destination, image, nil);
        return CGImageDestinationFinalize(destination);
    }

    return false;
}

public class ViewController: NSViewController {
    @IBOutlet weak var vlcView: VLCView?;
    @IBOutlet weak var scrubbingBar: ScrubbingBar?;
    @IBOutlet weak var scrubbingView: ScrubbingView?;

    var playerMediaPlayer: VLCMediaPlayer?;
    var scrubberMediaPlayer: VLCMediaPlayer?;

    @IBAction
    public func playMedia(sender: AnyObject?) {
        if let mediaPlayer = self.playerMediaPlayer {
            mediaPlayer.play();
        }
    }

    @IBAction
    public func pauseMedia(sender: AnyObject?) {
        if let mediaPlayer = self.playerMediaPlayer {
            mediaPlayer.pause();
        }
    }

    @IBAction
    public func rewindMedia(sender: AnyObject?) {
    }

    @IBAction
    public func forwardMedia(sender: AnyObject?) {
    }

    @objc
    public override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String: AnyObject]?, context: UnsafeMutablePointer<Void>) -> Void {
        if object === scrubbingBar {
            let doubleValue = scrubbingBar!.doubleValue;
            
            if let mediaPlayer = self.playerMediaPlayer {
                mediaPlayer.time = NSTimeInterval(doubleValue) * mediaPlayer.duration;
            }
        }
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.scrubbingBar?.addObserver(self, forKeyPath: "doubleValue", options: NSKeyValueObservingOptions.New, context: nil)
        
        dispatch_async(dispatch_get_main_queue()) {
            if let document = self.view.window?.windowController?.document as? Document {
                if let media = document.media, let view = self.vlcView {
                    do {
                        self.playerMediaPlayer = try VLCMediaPlayer(media: media);
                        self.scrubberMediaPlayer = try VLCMediaPlayer(media: media);
                        view.mediaPlayer = self.playerMediaPlayer!;
                    }
                    catch let error as NSError {
                        NSAlert(error: error).runModal();
                    }
                    catch {
                    }
                }
            }
        }

            /*
        do {
            let vlc   = try VLC(arguments: ["--verbose=4", "--no-color", "--vout=iosurface"]);
            let media = try VLCMedia(path: "/Users/rhoule/Movies/Library/DropBox/29554_01_720p.mp4", withVLC: vlc);
            
            print("\(vlc.audioModules)");
            
            media.parse();
            
            media.generatePreviewImagesAtStart(NSTimeInterval(0), end: media.duration, count: 16) { (images: [AnyObject]?, error: NSError?) in
                var index = 0;
            
                print("\(images) \(error)");
                
                for image in images! {
                    CGImageWriteToFile(image as! CGImageRef, "/Users/rhoule/t-\(index).png");
                    index++;
                }
            };
            
            let state = media.state;
            
            print ("\(media.debugDescription)");
            
            let mediaPlayer = try VLCMediaPlayer(media: media);

            print ("\(mediaPlayer.playing)");
            print ("\(media.url) \(state) \(media.duration)");
            
            if let vlcView = self.vlcView {
                vlcView.mediaPlayer = mediaPlayer;
            }
            
            mediaPlayer.play();
        }
        catch {
        }*/
    }
}

