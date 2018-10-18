//
//  GB_TemplateLinkEdit.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2017-12-31.
//  Copyright © 2017-2018 dfaulks. All rights reserved.
//

import Cocoa

class GB_TemplateLinkEdit: NSView {

    @IBOutlet var container: NSView!
    // widgets
    @IBOutlet weak var linkExplainLabel: NSTextField!
    @IBOutlet weak var firstLinkLabel: NSTextField!
    
    @IBOutlet weak var firstLinkTemplateEdit: NSTextField!
    @IBOutlet weak var otherLinkLabe: NSTextField!
    
    @IBOutlet weak var otherLinkTemplateEdit: NSTextField!
    
    @IBOutlet weak var separatorLabel: NSTextField!
    @IBOutlet weak var separatorEdit: NSTextField!
    @IBOutlet weak var overallExplainLabel: NSTextField!
    @IBOutlet weak var overallTemplateEdit: NSTextField!
    
    let incompleteColour = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: 0.2)
    private var defaultBackgroundColour:NSColor? = nil
    
    //==================================================
    // internal link output object
    private var data:GB_LinkOutputter = GB_LinkOutputter()
    
    // loading data
    func loadLinkOutputter(source:GB_LinkOutputter?) {
        data.first_link = source?.first_link ?? ""
        data.other_links = source?.other_links ?? ""
        data.separator = source?.separator ?? ""
        data.overall = source?.overall ?? ""
        
        firstLinkTemplateEdit.stringValue = data.first_link
        otherLinkTemplateEdit.stringValue = data.other_links
        separatorEdit.stringValue = data.separator
        overallTemplateEdit.stringValue = data.overall
        
        firstColour()
        otherColour()
        overallColour()
    }
    
    private func firstComplete() -> Bool {
        return data.first_link.contains("&#0#") && data.first_link.contains("&#1#")
    }
    
    private func otherComplete() -> Bool {
        return data.other_links.contains("&#0#") && data.other_links.contains("&#1#")
    }
    
    private func overallComplete() -> Bool {
        return data.overall.contains("&#0#")
    }
    private func firstColour() {
        if firstComplete() { firstLinkTemplateEdit.backgroundColor = defaultBackgroundColour }
        else { firstLinkTemplateEdit.backgroundColor = incompleteColour }
    }
    private func otherColour() {
        if otherComplete() { otherLinkTemplateEdit.backgroundColor = defaultBackgroundColour }
        else { otherLinkTemplateEdit.backgroundColor = incompleteColour }
    }
    private func overallColour() {
        if overallComplete() { overallTemplateEdit.backgroundColor = defaultBackgroundColour }
        else { overallTemplateEdit.backgroundColor = incompleteColour}
    }
    
    func isComplete() -> Bool {
        let okayfirst = firstComplete()
        let okayother = otherComplete()
        let okayoverall = overallComplete()
        return okayfirst && okayother && okayoverall
    }
       
    func saveToOutputter(target:GB_LinkOutputter) {
        target.first_link = data.first_link
        target.other_links = data.other_links
        target.separator = data.separator
        target.overall = data.overall
    }
    
    func getOutputterCopy() -> GB_LinkOutputter {
        return data.copyObject()
    }
    
    //==================================================
    @IBAction func firstLinkEndEditing(_ sender: Any) {
        data.first_link = firstLinkTemplateEdit.stringValue
        firstColour()
    }
    
    @IBAction func otherLinkEndEditing(_ sender: Any) {
        data.other_links = otherLinkTemplateEdit.stringValue
        otherColour()
    }
    
    @IBAction func separatorEndEditing(_ sender: Any) {
        data.separator = separatorEdit.stringValue
    }
    
    @IBAction func overallEndEditing(_ sender: Any) {
        data.overall = overallTemplateEdit.stringValue
        overallColour()
    }
    // ==================================================
    // init code below
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        commonInit()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        commonInit()
    }
    // setting up custom widgets is a pain...
    private func commonInit() {
        var objs:NSArray?
        let ok = Bundle.main.loadNibNamed(NSNib.Name(rawValue: "GB_TemplateLinkEdit"), owner: self, topLevelObjects: &objs)
        assert(ok)
        addSubview(container)
        container.frame = self.bounds
        container.autoresizingMask = [NSView.AutoresizingMask.height,NSView.AutoresizingMask.width]
        defaultBackgroundColour = firstLinkTemplateEdit.backgroundColor
    }
    
}
