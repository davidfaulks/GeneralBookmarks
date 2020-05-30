//
//  GB_TemplateEditPage.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2019-01-04.
//  Copyright © 2019 dfaulks. All rights reserved.
//

import Cocoa

class GB_TemplateEditPage: NSViewController {
    
    let incompleteColour = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: 0.2)
    private var defaultBackgroundColour:NSColor? = nil
    
    @IBOutlet weak var pageNameLabel: NSTextField!
    @IBOutlet weak var pageNameEdit: NSTextField!
    
    @IBOutlet weak var pageTemplateWrapper: NSBox!
    @IBOutlet weak var pageTemplateWrapInterior: NSView!
    
    @IBOutlet weak var pageTemplateLabel: NSTextField!
    @IBOutlet var pageTemplateEdit: NSTextView!
    
    @IBOutlet weak var groupSplitWrapper: NSBox!
    @IBOutlet weak var groupSplitWrapInterior: NSView!
    @IBOutlet weak var groupSplitEditPanel: GB_PageSplitData!
    
    @IBOutlet weak var pageNavWrapper: NSBox!
    @IBOutlet weak var pageNavWrapInterior: NSView!
    @IBOutlet weak var pageNavEditPanel: GB_PageNavEdit!
    //=======================================================
    var trimmedName:String {
        return pageNameEdit.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    private func pageNameComplete() -> Bool {
        return !trimmedName.isEmpty
    }
    private func pageTemplateIsComplete() -> Bool {
        
        let testString = pageTemplateEdit.string
        // the fixed substitutions
        if !(testString.contains("&#1#") && testString.contains("&#2#")) { return false }
        if !testString.contains("&#3#") { return false }
        // group columns/lists/sets
        let columnCount = groupSplitEditPanel.groupListsCount
        for columnIndex in 0..<columnCount {
            let findString = "&#0\(columnIndex)#"
            if !testString.contains(findString) { return false }
        }
        return true
    }
    private func pageNameColour() {
        if pageNameComplete() { pageNameEdit.backgroundColor = defaultBackgroundColour }
        else { pageNameEdit.backgroundColor = incompleteColour }
    }
    private func pageTemplateColour() {
        if pageTemplateIsComplete() { pageTemplateEdit.backgroundColor = defaultBackgroundColour! }
        else { pageTemplateEdit.backgroundColor = incompleteColour }
    }
    //=======================================================
    func loadPageOutputter(source:GB_PageOutputter) {
        pageTemplateEdit.string = source.overall
        _ = groupSplitEditPanel.loadDataFromOutputter(source)
    }
    func savePageOutputter(target:GB_PageOutputter) {
        target.overall = pageTemplateEdit.string
        groupSplitEditPanel.saveDataToPageOutputter(target)
    }
    
    
    //======================================================
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        defaultBackgroundColour = pageTemplateEdit.backgroundColor
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: NSText.didChangeNotification, object: nil)
        textViewRFix(textview: pageTemplateEdit)
    }
    //=======================================================
    @IBAction func pageNameChanged(_ sender: Any) {
        pageNameColour()
    }
    
    @objc func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        if (textView === pageTemplateEdit) {
            pageTemplateColour()
        }
    }
    
}
