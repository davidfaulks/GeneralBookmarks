//
//  GBTemplateEditView.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2017-12-29.
//  Copyright © 2017 dfaulks. All rights reserved.
//

import Cocoa

class GBTemplateEditView: NSTabViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        setTabPointers()
    }
    private var templateDocument:GBTemplateDocument? = nil
    
    private func GetDocument() -> GBTemplateDocument? {
        let doc = NSDocumentController.shared.document(for: view.window!)
        return (doc as? GBTemplateDocument)
    }
    
    override func viewWillAppear() {
        super.viewWillAppear()
        if templateDocument == nil {
            templateDocument = GetDocument()
            _ = loadDocument()
        }
    }
    //==========================================================================
    // child views and associated setup method...
    private var pageTabView:GB_TemplateEditPage!
    private var partsTabView:GB_TemplateEditParts!
    //------------------------------------------------
    private func setTabPointers() {
        pageTabView = self.tabViewItems[0].viewController as? GB_TemplateEditPage
        partsTabView = self.tabViewItems[1].viewController as? GB_TemplateEditParts
    }
    private func loadDocument() -> Bool {
        if templateDocument == nil { return false }
        let template = templateDocument!.document_data
        // loading page tab view stuff
        pageTabView.pageNameEdit.stringValue = template.templateName
        pageTabView.loadPageOutputter(source: template.pageOutputter)
        pageTabView.pageNavEditPanel.loadPageNav(source: template.pageNav)
        // for the parts, there is a convenience function to call the 6 lesser loaders
        partsTabView.loadFromPageOutputter(source: template.pageOutputter)
        // done
        return true
    }
    func saveDocument() -> Bool {
        if templateDocument == nil { return false }
        let template = templateDocument!.document_data
        // saving page tab view stuff
        template.templateName = pageTabView.pageNameEdit.stringValue
        pageTabView.savePageOutputter(target: template.pageOutputter)
        pageTabView.pageNavEditPanel.savePageNav(target: template.pageNav)
        // saving the parts (using a special function
        partsTabView.saveToPageEditor(target: template.pageOutputter)
        // done
        return true
    }
}
