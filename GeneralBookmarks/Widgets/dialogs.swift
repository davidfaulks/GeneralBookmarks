//
//  dialogs.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-05-20.
//  Copyright © 2016-2019 dfaulks. All rights reserved.

import Foundation
import Cocoa
//*************************************************************************
// opens an open file dialog, non-threadsafe
func openFileDialog(_ inTitle:String, filetypes:[String]) -> String? {
    let dialog = NSOpenPanel();
    
    dialog.title                   = inTitle
    dialog.showsResizeIndicator    = true
    dialog.showsHiddenFiles        = false
    dialog.canChooseDirectories    = false;
    dialog.canCreateDirectories    = true;
    dialog.allowsMultipleSelection = false;
    dialog.allowedFileTypes        = filetypes
    
    if (dialog.runModal() == NSApplication.ModalResponse.OK) {
        let result = dialog.url // Pathname of the file
        if (result != nil) { return result!.path }
        else { return nil }
    }
    else { return nil }
}
//---------------------------------------------------
// opens a file open dialog, allows multiple selection and retusn urls
func openFileDialogMulti(_ inTitle:String, filetypes:[String]) -> [URL]? {
    let dialog = NSOpenPanel();
    
    dialog.title                   = inTitle
    dialog.showsResizeIndicator    = true
    dialog.showsHiddenFiles        = false
    dialog.canChooseDirectories    = false;
    dialog.canCreateDirectories    = true;
    dialog.allowsMultipleSelection = true;
    dialog.allowedFileTypes        = filetypes
    
    if (dialog.runModal() == NSApplication.ModalResponse.OK) {
        return dialog.urls
    }
    else { return nil }
}
//================================================================
// opens a dialog to pick a directory
func pickDirectoryDialog(title inTitle:String, startDirectory:URL?) -> String? {
    let dialog = NSOpenPanel();
    
    dialog.title = inTitle
    dialog.showsResizeIndicator = true
    dialog.canChooseDirectories = true
    dialog.canChooseFiles = false
    dialog.allowsMultipleSelection = false
    dialog.canCreateDirectories = true
    if startDirectory != nil {
        dialog.directoryURL = startDirectory
    }
    
    if (dialog.runModal() == NSApplication.ModalResponse.OK) {
        let result = dialog.directoryURL
        if (result != nil) { return result!.path }
        else { return nil }
    }
    else { return nil }
}
//================================================================
// opens an save file dialog, non-threadsafe
func saveFileDialog(_ inTitle:String, filetypes:[String]) -> String? {
    let dialog = NSSavePanel();
    
    dialog.title                   = inTitle
    dialog.showsResizeIndicator    = true
    dialog.showsHiddenFiles        = false
    dialog.canCreateDirectories    = true;
    dialog.allowedFileTypes        = filetypes
    
    if (dialog.runModal() == NSApplication.ModalResponse.OK) {
        let result = dialog.url // Pathname of the file
        if (result != nil) { return result!.path }
        else { return nil }
    }
    else { return nil }
}
//================================================================
// one-line NSAlerts are aparrently depreciated. Too Bad!
func showModalMessage(_ message:String, info:String, style:NSAlert.Style, btnLabel:String) {
    let alertBox = NSAlert()
    alertBox.messageText = message
    alertBox.informativeText = info
    alertBox.alertStyle = style
    alertBox.addButton(withTitle: btnLabel)
    alertBox.runModal()
}
//=================================================================
// text entry popups are NSAlerts with ‘accesory views’
func showModalTextEntry(_ message:String, info:String, defaultText:String, nonEmpty:Bool) -> String? {
    // initial setup
    let textEntryDialog = NSAlert()
    textEntryDialog.messageText = message
    textEntryDialog.informativeText = info
    textEntryDialog.alertStyle = .informational
    textEntryDialog.addButton(withTitle: "Done")
    textEntryDialog.addButton(withTitle: "Cancel")
    // the text entry
    let inputBox = NSTextField(frame: NSMakeRect(0, 0, 200, 24))
    // the loop is here because if nonEmpty is true, we might pop the dialog again
    while true {
        inputBox.stringValue = defaultText
        textEntryDialog.accessoryView = inputBox
        // finishing
        let result = textEntryDialog.runModal()
        if result == NSApplication.ModalResponse.alertFirstButtonReturn {
            inputBox.validateEditing()
            let resString = inputBox.stringValue
            if nonEmpty {
                let trimmedString = resString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                if trimmedString.isEmpty { continue }
                else { return trimmedString }
            }
            else { return resString }
        }
        else if result == NSApplication.ModalResponse.alertSecondButtonReturn {
            return nil
        }
    }    
}
//==================================================================
// a 'Yes' or 'No' popup dialog
func showModalYesOrNoDialog(_ message:String, info:String, style:NSAlert.Style) -> Bool {
    // setting it up
    let yesNoDialog = NSAlert()
    yesNoDialog.messageText = message
    yesNoDialog.informativeText = info
    yesNoDialog.alertStyle = style
    yesNoDialog.addButton(withTitle: "Yes")
    yesNoDialog.addButton(withTitle: "No")
    // running
    let result = yesNoDialog.runModal()
    return (result == NSApplication.ModalResponse.alertFirstButtonReturn)   
}
//=================================================================
// a popup dialog for creating a new link from input
func showModalNewLinkDialog(_ accesory_view:GB_LinkEntryView) -> GB_SiteLink? {
    
    // basic setup for the dialog
    let linkEntryDialog = NSAlert()
    linkEntryDialog.messageText = "Entering Link information"
    linkEntryDialog.informativeText = "Please enter the Link label and the Link URL in the text boxes below:\n"
    linkEntryDialog.alertStyle = .informational
    linkEntryDialog.addButton(withTitle: "Done")
    linkEntryDialog.addButton(withTitle: "Cancel")
    accesory_view.clearText()
    linkEntryDialog.accessoryView = accesory_view
    
    // the loop is here because if nonEmpty is true, we might pop the dialog again
    while true {

        // finishing
        let result = linkEntryDialog.runModal()
        if result == NSApplication.ModalResponse.alertFirstButtonReturn {
            accesory_view.validateEditing()
            if accesory_view.hasEmpty { continue }
            else {
                let result:GB_SiteLink = GB_SiteLink(url: accesory_view.linkURL, linkLabel: accesory_view.linkLabel)
                return result;
            }
        }
        else if result == NSApplication.ModalResponse.alertSecondButtonReturn {
            return nil
        }
        
    }
    
}
//++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// a helper to check if a directory exists
func doesDirExist(path:String) -> Bool {
    var directoryTest:ObjCBool = ObjCBool(false)
    let fexists = FileManager.default.fileExists(atPath: path, isDirectory: &directoryTest)
    return fexists && directoryTest.boolValue
}
//*************************************************************************


