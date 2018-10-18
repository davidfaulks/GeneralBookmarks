//
//  GeneralBookmarksApp.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2018-06-25.
//  Copyright © 2018 dfaulks. All rights reserved.
//
// needed to enable keyboard shortcuts in NSTextFields

import Foundation
import Cocoa

class GeneralBookmarksApp : NSApplication {
    
    override func sendEvent(_ event: NSEvent) {
        if event.type == NSEvent.EventType.keyDown {
            if event.modifierFlags.contains(NSEvent.ModifierFlags.command) {
                if let checkchar = event.charactersIgnoringModifiers?.lowercased() {
                    switch checkchar {
                    case "c": if NSApp.sendAction(#selector(NSText.copy(_:)), to:nil, from:self) { return }
                    case "v": if NSApp.sendAction(#selector(NSText.paste(_:)), to:nil, from:self) { return }
                    case "x": if NSApp.sendAction(#selector(NSText.cut(_:)), to:nil, from:self) { return }
                    case "a": if NSApp.sendAction(#selector(NSText.selectAll(_:)), to:nil, from:self) { return }
                    default: break
                    }
                }
            }
        }
        return super.sendEvent(event)
    }
}
