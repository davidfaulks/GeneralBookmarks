//
//  AppDelegate.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-08-11.
//  Copyright © 2016-2019 dfaulks. All rights reserved.
//

import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    var linkChecker:GB_SingleLinkChecker = GB_SingleLinkChecker()
    var groupChecker:GB_GroupLinkChecker = GB_GroupLinkChecker(checkerCount: 3, autoHTTPS: true)

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Insert code here to initialize your application
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }
    //----------------------------------------------------------------------------------------------------------
    // replacement for default new menu handler
    @IBAction func newDocument(_ sender:Any?) {
        // lauch a dialog asking user to pick the doc type
        let pickResult = showModalPickDocumentType()
        print("PickResult value: \(pickResult)")
        if pickResult > 1 { return } // cancel was picked
        // calling the document controller
        let docControl = NSDocumentController.shared
        if pickResult == 0 {
            // making and launching a blank Link Collection
            var newLinkColl:GBDocument? = nil
            do {
                // makeUntitledDocument throws, but what? The Apple docs do not say.
                newLinkColl = try docControl.makeUntitledDocument(ofType: "LinkCollection") as! GBDocument
            }
            catch {
                showModalMessage("Creating Link Collection Failed!", info: "No idea why.", style: .critical, btnLabel: "Darn")
                return
            }
            // finishing off
            docControl.addDocument(newLinkColl!)
            newLinkColl!.makeWindowControllers()
            newLinkColl!.showWindows()
        }
        else {
            // making and launching a blank output template
            var newOutputTemplate:GBTemplateDocument? = nil
            print("GBTemplateDocument A")
            do {
                newOutputTemplate = try docControl.makeUntitledDocument(ofType: "OutputTemplate") as! GBTemplateDocument
            }
            catch {
                showModalMessage("Creating Output Template Failed!", info: "No idea why.", style: .critical, btnLabel: "Darn")
                return
            }
            print("GBTemplateDocument B")
            // finishing off
            docControl.addDocument(newOutputTemplate!)
            print("GBTemplateDocument C")
            newOutputTemplate!.makeWindowControllers()
            newOutputTemplate!.showWindows()
        }
        // done
    }
    
    // 
    private func showModalPickDocumentType() -> Int {
        // setting it up
        let doctypePickerDialog = NSAlert()
        doctypePickerDialog.messageText = "Please pick a document type:"
        doctypePickerDialog.informativeText = "Click on cancel to cancel creating a new 'document', or click the correct button for what you want to make."
        doctypePickerDialog.alertStyle = .informational
        doctypePickerDialog.addButton(withTitle: "Link Collection")
        doctypePickerDialog.addButton(withTitle: "Output Template")
        doctypePickerDialog.addButton(withTitle: "Cancel")
        // running
        let result = doctypePickerDialog.runModal()
        switch result {
            case NSApplication.ModalResponse.alertFirstButtonReturn : return 0
            case NSApplication.ModalResponse.alertSecondButtonReturn : return 1
            default: return 2
        }
    }

}

