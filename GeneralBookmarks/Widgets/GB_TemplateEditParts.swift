//
//  GB_TemplateEditParts.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2017-12-29.
//  Copyright © 2017-2019 dfaulks. All rights reserved.
//

import Cocoa

class GB_TemplateEditParts: NSViewController, NSTextDelegate {
    
    @IBOutlet weak var templateLinkEditor: GB_TemplateLinkEdit!
    
    @IBOutlet weak var templateMajorLinkEditor: GB_TemplateLinkEdit!
    
    @IBOutlet weak var groupTemplateWrapper: NSBox!
    @IBOutlet weak var groupTemplateWrapInterior: NSView!
    
    @IBOutlet weak var siteSeparatorLabel: NSTextField!
    @IBOutlet weak var siteSeparatorEdit: NSTextField!
    @IBOutlet weak var siteNLSeparatorCheckbox: NSButton!
    
    @IBOutlet weak var groupOverallLabel: NSTextField!
    @IBOutlet var groupTemplateEdit: NSTextView!
    
    @IBOutlet weak var groupListWrapper: NSBox!
    @IBOutlet weak var groupListWrapInterior: NSView!
    
    @IBOutlet weak var groupSeparatorLabel: NSTextField!
    @IBOutlet weak var groupSeparatorEdit: NSTextField!
    
    @IBOutlet weak var groupListOverallLabel: NSTextField!
    @IBOutlet weak var groupListTemplateEdit: NSTextField!
    
    @IBOutlet weak var groupNavWrapper: NSBox!
    @IBOutlet weak var groupNavWrapInterior: NSView!
    
    @IBOutlet weak var groupNavLinkLabel: NSTextField!
    @IBOutlet weak var groupNavLikTemplateEdit: NSTextField!
    @IBOutlet weak var groupNavLinkSeparatorLabel: NSTextField!
    @IBOutlet weak var groupNavLinkSeparatorEdit: NSTextField!
    
    @IBOutlet weak var overallGroupNavLabel: NSTextField!
    @IBOutlet weak var overallGroupNavEdit: NSTextField!
    
    
    //===============================================
    @IBOutlet weak var majorLinkWrapper: NSBox!
    @IBOutlet weak var majorLinkWrapInterior: NSView!
    
    @IBOutlet weak var majorLinkNavLinkLabel: NSTextField!
    @IBOutlet weak var majorLinkNavLinkTemplate: NSTextField!
    @IBOutlet weak var MajorLinkNavSeparatorLabel: NSTextField!
    @IBOutlet weak var majorLinkSeparatorEdit: NSTextField!
    @IBOutlet weak var majorLinkNavOverallLabel: NSTextField!
    @IBOutlet var majorLinkNavOverallEdit: NSTextView!
    //==============================================================
    let incompleteColour = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: 0.2)
    private var defaultBackgroundColour:NSColor? = nil
    //-------------------------------------------------------
    func majorLinkNavLinkIsComplete() -> Bool {
        let urlC = majorLinkNavLinkTemplate.stringValue.contains("&#0#")
        let labelC = majorLinkNavLinkTemplate.stringValue.contains("&#1#")
        return urlC && labelC
    }
    func majorLinkNavOverallIsComplete() -> Bool {
        return majorLinkNavOverallEdit.string.contains("&#0#")
    }
    func majorLinkNavIsComplete() -> Bool {
        return majorLinkNavLinkIsComplete() && majorLinkNavOverallIsComplete()
    }
    
    private func majorLinkNavLinkColour() {
        if !majorLinkNavLinkIsComplete() {
            majorLinkNavLinkTemplate.backgroundColor = incompleteColour
        }
        else {
            majorLinkNavLinkTemplate.backgroundColor = defaultBackgroundColour
        }
    }
    private func majorLinkNavOverallColour() {
        if !majorLinkNavOverallIsComplete() {
            majorLinkNavOverallEdit.backgroundColor = incompleteColour
        }
        else {
            majorLinkNavOverallEdit.backgroundColor = defaultBackgroundColour!
        }
    }
    //-------------------------------------------------------
    func loadMajorLinkNav(source:GB_MajorLinksOutputter?) {
        majorLinkNavLinkTemplate.stringValue = source?.major_link ?? ""
        majorLinkSeparatorEdit.stringValue = source?.separator ?? ""
        majorLinkNavOverallEdit.string = source?.overall ?? ""
        majorLinkNavLinkColour()
        majorLinkNavOverallColour()
    }
    func saveMajorLinkNav(target:GB_MajorLinksOutputter) -> Bool {
        target.major_link = majorLinkNavLinkTemplate.stringValue
        target.separator = majorLinkSeparatorEdit.stringValue
        target.overall = majorLinkNavOverallEdit.string
        return majorLinkNavLinkIsComplete()
    }
    //-------------------------------------------------------
    @IBAction func majorLinkNavLinkChanged(_ sender: Any) {
        majorLinkNavLinkColour()
    }
    @IBAction func majorLinkNavSeparatorChanged(_ sender: Any) {
    }
    
    @IBAction func majorLinkNavOverallChanged(_ sender: Any) {
        majorLinkNavOverallColour()
    }
    
    //================================================================================
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        self.defaultBackgroundColour = groupTemplateEdit.backgroundColor
        NotificationCenter.default.addObserver(self, selector: #selector(textDidChange), name: NSText.didChangeNotification, object: nil)
        textViewRFix(textview: groupTemplateEdit)
        textViewRFix(textview: majorLinkNavOverallEdit)
    }
    //===============================================================================
    // group template
    private func loadGroupOutputter(source:GB_GroupOutputter) {
        siteSeparatorEdit.stringValue = source.separator
        groupTemplateEdit.string = source.overall
        // siteNLSeparatorCheckbox.state
        let checkState:NSControl.StateValue = (source.addLineSeparator) ? .on : .off
        siteNLSeparatorCheckbox.state = checkState
        groupTemplateColour()
    }
    private func saveToGroupOutputter(target:GB_GroupOutputter) {
        target.separator = siteSeparatorEdit.stringValue
        target.overall = groupTemplateEdit.string
        let xCheckState = siteNLSeparatorCheckbox.state
        target.addLineSeparator = (xCheckState == NSControl.StateValue.on )
    }
    
    func groupIsComplete() -> Bool {
        let nameOkay = groupTemplateEdit.string.contains("&#1#")
        let listOkay = groupTemplateEdit.string.contains("&#2#")
        return nameOkay && listOkay
    }
    private func groupTemplateColour() {
        if !groupIsComplete() {
            groupTemplateEdit.backgroundColor = incompleteColour
        }
        else {
            groupTemplateEdit.backgroundColor = defaultBackgroundColour!
        }
    }
    //-------------------------------------
    // list of groups template
    private func loadGroupListOutputter(source:GB_GroupSequenceOutputter) {
        groupSeparatorEdit.stringValue = source.separator
        groupListTemplateEdit.stringValue = source.overall
        groupListTemplateColour()
    }
    private func saveToGroupListOutputter(target:GB_GroupSequenceOutputter) {
        target.separator = groupSeparatorEdit.stringValue
        target.overall = groupListTemplateEdit.stringValue
    }
    func groupListIsComplete() -> Bool {
        return groupListTemplateEdit.stringValue.contains("&#1#");
    }
    private func groupListTemplateColour() {
        if groupListIsComplete() {
            groupListTemplateEdit.backgroundColor = defaultBackgroundColour
        }
        else {
            groupListTemplateEdit.backgroundColor = incompleteColour
        }
    }
    //--------------------------------------
    // group nav bar template
    private func loadGroupNavOutputter(source:GB_GroupListOutputter?) {
        groupNavLikTemplateEdit.stringValue = source?.group_link ?? ""
        groupNavLinkSeparatorEdit.stringValue = source?.separator ?? ""
        overallGroupNavEdit.stringValue = source?.overall ?? ""
        groupNavLinkColour()
        groupNavColour()
    }

    private func saveToGroupNavOutputter(target:GB_GroupListOutputter) {
        target.group_link = groupNavLikTemplateEdit.stringValue
        target.separator = groupNavLinkSeparatorEdit.stringValue
        target.overall = overallGroupNavEdit.stringValue
    }
    func groupNavLinkIsComplete() -> Bool {
        let fragOkay = groupNavLikTemplateEdit.stringValue.contains("&#0#")
        let nameOkay = groupNavLikTemplateEdit.stringValue.contains("&#1#")
        return fragOkay && nameOkay
    }
    func groupNavIsComplete() -> Bool {
        return overallGroupNavEdit.stringValue.contains("&#0#")
    }
    private func groupNavLinkColour() {
        if groupNavLinkIsComplete() {
            groupNavLikTemplateEdit.backgroundColor = defaultBackgroundColour
        }
        else {
            groupNavLikTemplateEdit.backgroundColor = incompleteColour
        }
    }
    private func groupNavColour() {
        if groupNavIsComplete() {
            overallGroupNavEdit.backgroundColor = defaultBackgroundColour
        }
        else {
            overallGroupNavEdit.backgroundColor = incompleteColour
        }
    }
    //------------------------------------------------------------------------
    func loadFromPageOutputter(source:GB_PageOutputter) {
        loadGroupOutputter(source: source.groupFormatter)
        loadGroupListOutputter(source: source.groupListFormatter)
        loadGroupNavOutputter(source: source.groupBarFormatter)
        loadMajorLinkNav(source: source.bigLinksFormatter)
        templateLinkEditor.loadLinkOutputter(source: source.linkFormatter)
        templateMajorLinkEditor.loadLinkOutputter(source: source.majorLinkFormat)
    }
    
    func dataIsComplete() -> Bool {
        let linkComplete = templateLinkEditor.isComplete()
        let groupComplete = groupIsComplete()
        let listComplete = groupListIsComplete()
        return linkComplete && groupComplete && listComplete
    }
    
    func saveToPageEditor(target:GB_PageOutputter) -> Bool {
        templateLinkEditor.saveToOutputter(target: target.linkFormatter)
        if templateMajorLinkEditor.isComplete() {
            if target.majorLinkFormat == nil { target.majorLinkFormat = GB_LinkOutputter() }
            templateMajorLinkEditor.saveToOutputter(target: target.majorLinkFormat!)
        }
        else {
           if target.majorLinkFormat != nil { target.majorLinkFormat = nil }
        }
        
        saveToGroupOutputter(target: target.groupFormatter)
        saveToGroupListOutputter(target: target.groupListFormatter)
        
        if majorLinkNavIsComplete() {
            if target.bigLinksFormatter == nil { target.bigLinksFormatter = GB_MajorLinksOutputter() }
            _ = saveMajorLinkNav(target: target.bigLinksFormatter!)
        }
        else {
            if target.bigLinksFormatter != nil { target.bigLinksFormatter = nil }
        }
        
        if groupNavLinkIsComplete() && groupNavIsComplete() {
            if target.groupBarFormatter == nil { target.groupBarFormatter = GB_GroupListOutputter() }
            saveToGroupNavOutputter(target: target.groupBarFormatter!)
        }
        
        return dataIsComplete()
    }
    
    //===============================================================================
    @IBAction func siteSeparatorChanged(_ sender: Any) {
    }
    
    
    @IBAction func siteNLSeparatorCBClicked(_ sender: Any) {
    }
    
    @objc func textDidChange(_ notification: Notification) {
        guard let textView = notification.object as? NSTextView else { return }
        if (textView === groupTemplateEdit) {
            groupTemplateColour()
        }
    }
    
    @IBAction func groupSeparatorChanged(_ sender: Any) {
    }
    
    @IBAction func groupListTemplateEditorChanged(_ sender: Any) {
        groupListTemplateColour()
    }
    
    @IBAction func groupNavLinkEditChanged(_ sender: Any) {
        groupNavLinkColour()
    }
    
    @IBAction func groupNavLinkSeparatorChanged(_ sender: Any) {
    }
    
    @IBAction func groupNavTemplateChanged(_ sender: Any) {
        groupNavColour()
    }
    
    
    
}
