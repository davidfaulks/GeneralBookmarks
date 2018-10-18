//
//  GB_PageNavEdit.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2018-01-12.
//  Copyright © 2018 dfaulks. All rights reserved.
//

import Cocoa

class GB_PageNavEdit: NSView {
    @IBOutlet var contents: NSView!
    //=============================================================
    @IBOutlet weak var linkInfoLabel: NSTextField!
    
    
    @IBOutlet weak var pageLinkLabel: NSTextField!
    @IBOutlet weak var pageLinkTemplate: NSTextField!
    @IBOutlet weak var samePageTreatmentLabel: NSTextField!
    @IBOutlet weak var samePageTreatmentPicker: NSPopUpButton!
    @IBOutlet weak var samePageLinkLabel: NSTextField!
    @IBOutlet weak var samePageLinkTemplate: NSTextField!
    @IBOutlet weak var separatorLabel: NSTextField!
    @IBOutlet weak var separatorEdit: NSTextField!
    @IBOutlet weak var overallLabel: NSTextField!
    @IBOutlet weak var overallTemplate: NSTextField!
    
    let incompleteColour = NSColor(calibratedRed: 1.0, green: 0.0, blue: 0.0, alpha: 0.2)
    private var defaultBackgroundColour:NSColor? = nil
    
    //=============================================================
    private func pageLinkComplete() -> Bool {
        let q1 = pageLinkTemplate.stringValue.contains("&#0#")
        let q2 = pageLinkTemplate.stringValue.contains("&#1#")
        return q1 && q2
    }
    private func samePageComplete() -> Bool {
        return samePageLinkTemplate.stringValue.contains("&#1#")
    }
    
    private func overallComplete() -> Bool {
        return overallTemplate.stringValue.contains("&#0#")
    }
    
    func isComplete() -> Bool {
        if !( pageLinkComplete() && overallComplete() ) { return false }
        if samePageTreatmentPicker.indexOfSelectedItem == 1 {
            return samePageComplete()
        }
        else { return true }
    }
    
    private func pageLinkColour() {
        if pageLinkComplete() { pageLinkTemplate.backgroundColor = defaultBackgroundColour }
        else { pageLinkTemplate.backgroundColor = incompleteColour }
    }
    
    private func samePageColour() {
        if samePageComplete() { samePageLinkTemplate.backgroundColor = defaultBackgroundColour }
        else { samePageLinkTemplate.backgroundColor = incompleteColour }
    }
    private func overallColour() {
        if overallComplete() { overallTemplate.backgroundColor = defaultBackgroundColour }
        else { overallTemplate.backgroundColor = incompleteColour }
    }
    
    //------------------------------------------------------
    func loadPageNav(source:GB_PageNavOutputter) -> Bool {
        // loading
        pageLinkTemplate.stringValue = source.page_link
        samePageLinkTemplate.stringValue = source.currentPage
        samePageColour()
        switch (source.navOption) {
            case .allSame   : samePageTreatmentPicker.selectItem(at: 0)
            case .current   : samePageTreatmentPicker.selectItem(at: 1)
            case .noCurrent : samePageTreatmentPicker.selectItem(at: 2)
        }
        separatorEdit.stringValue = source.separator
        overallTemplate.stringValue = source.overall
        // setting the colours
        pageLinkColour()
        overallColour()
        // finished
        return isComplete()
    }
    func savePageNav(target:GB_PageNavOutputter) -> Bool {
        let result = isComplete() // record whether is seems the contents are good enough for output
        target.page_link = pageLinkTemplate.stringValue
        target.currentPage = samePageLinkTemplate.stringValue
        let pickDex = samePageTreatmentPicker.indexOfSelectedItem
        switch pickDex {
            case 0: target.navOption = .allSame
            case 1: target.navOption = .allSame
            case 2: target.navOption = .allSame
            default: break;
        }
        target.separator = separatorEdit.stringValue
        target.overall = overallTemplate.stringValue
        return result
    }
    
    //------------------------------------------------------
    @IBAction func pageLinkTemplateChanged(_ sender: Any) {
        pageLinkColour()
    }
    
    @IBAction func samePageTreatmentPickerChanged(_ sender: Any) {
        let index = samePageTreatmentPicker.indexOfSelectedItem
        samePageLinkTemplate.isEnabled = (index == 1)
    }
    
    @IBAction func samePageTemplateChanged(_ sender: Any) {
        samePageColour()
    }
    
    @IBAction func separatorChanged(_ sender: Any) {
    }
    
    @IBAction func overallTemplateChanged(_ sender: Any) {
        overallColour()
    }
    //=============================================================
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
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
        let ok = Bundle.main.loadNibNamed(NSNib.Name(rawValue: "GB_PageNavEdit"), owner: self, topLevelObjects: &objs)
        assert(ok)
        addSubview(contents)
        contents.frame = self.bounds
        contents.autoresizingMask = [NSView.AutoresizingMask.height,NSView.AutoresizingMask.width]
        
        defaultBackgroundColour = pageLinkTemplate.backgroundColor
        
    }
    
}
