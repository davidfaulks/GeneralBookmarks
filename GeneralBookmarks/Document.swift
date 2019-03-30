//
//  Document.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-08-11.
//  Copyright © 2016-2019 dfaulks. All rights reserved.
//

import Cocoa

class GBDocument: NSDocument {

    override init() {
        document_data = GB_LinkCollection()
        super.init()

    }

    override class var autosavesInPlace: Bool {
        return true
    }

    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "Main"), bundle: nil)
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "LinkCollection_WC")) as! NSWindowController
        self.addWindowController(windowController)
    }
    //=============================================================
    var document_data:GB_LinkCollection

        // convert to data
    override func data(ofType typeName: String) throws -> Data {
        return NSKeyedArchiver.archivedData(withRootObject: document_data)
        // throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }

        // convert from data
    override func read(from data: Data, ofType typeName: String) throws {
        let tempCollection = NSKeyedUnarchiver.unarchiveObject(with: data) as? GB_LinkCollection
        if (tempCollection == nil) {
            throw NSError(domain: NSOSStatusErrorDomain, code: kPOSIXErrorEFTYPE , userInfo: nil)
        }
        else { document_data = tempCollection! }
    }
}
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// a new document type for output templates
class GBTemplateDocument: NSDocument {
    override init() {
        document_data = GBTemplateOutputter()
        super.init()
    }
    
    override class var autosavesInPlace: Bool {
        return true
    }
    
    override func makeWindowControllers() {
        // Returns the Storyboard that contains your Document window.
        Swift.print("GBTemplateDocument.makeWindowControllers A")
        let storyboard = NSStoryboard(name: NSStoryboard.Name(rawValue: "TemplateEdit"), bundle: nil)
        Swift.print("GBTemplateDocument.makeWindowControllers B")
        let windowController = storyboard.instantiateController(withIdentifier: NSStoryboard.SceneIdentifier(rawValue: "OutputTemplateWC")) as! NSWindowController
        Swift.print("GBTemplateDocument.makeWindowControllers C")
        self.addWindowController(windowController)
        Swift.print("GBTemplateDocument.makeWindowControllers D")
    }
    //=============================================================
    var document_data:GBTemplateOutputter
    
    // convert to data
    override func data(ofType typeName: String) throws -> Data {
        if !saveActiveDocument() {
            fatalError("Could not get view controller while trying to save!")
        }
        return NSKeyedArchiver.archivedData(withRootObject: document_data)
        // throw NSError(domain: NSOSStatusErrorDomain, code: unimpErr, userInfo: nil)
    }
    
    // convert from data
    override func read(from data: Data, ofType typeName: String) throws {
        let tempCollection = NSKeyedUnarchiver.unarchiveObject(with: data) as? GBTemplateOutputter
        if (tempCollection == nil) {
            throw NSError(domain: NSOSStatusErrorDomain, code: kPOSIXErrorEFTYPE , userInfo: nil)
        }
        else { document_data = tempCollection! }
    }
    
    // saves the temple editor contents, if any
    func saveActiveDocument() -> Bool {
        // here, the document is loaded but has no window (nothing to save)
        if self.windowControllers.isEmpty { return false }
        // getting the editor view, this should always work
        guard let vc = self.windowControllers[0].contentViewController as? GBTemplateEditView else {
            return false
        }
        // saving
        _ = vc.saveDocument()
        return true
    }
    
    
}
