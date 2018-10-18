//
//  GB_LinkEntryView.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-08-06.
//  Copyright © 2016-2018 dfaulks. All rights reserved.
//

import Cocoa

class GB_LinkEntryView: NSView {
    @IBOutlet weak var linkLabelEdit: NSTextField!
    @IBOutlet weak var linkURLEdit: NSTextField!
    
    // custom set and get text
    var linkLabel:String {
        set(inlabel) { linkLabelEdit.stringValue = inlabel }
        get { return linkLabelEdit.stringValue}
    }
    var linkURL:String {
        set(inURL) { linkURLEdit.stringValue = inURL }
        get { return linkURLEdit.stringValue }
    }
    
    // empty property
    var hasEmpty:Bool {
        get {
            let fstring = linkLabelEdit.stringValue
            let fstring2 = fstring.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            if fstring2.isEmpty { return true }
            let xstring = linkURLEdit.stringValue
            let xstring2 = xstring.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            return xstring2.isEmpty
        }
    }
    
    // validate editing
    func validateEditing() {
        linkLabelEdit.validateEditing()
        linkURLEdit.validateEditing()        
    }
    // clearing data
    func clearText() {
        linkLabelEdit.stringValue = ""
        linkURLEdit.stringValue = ""
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
}
