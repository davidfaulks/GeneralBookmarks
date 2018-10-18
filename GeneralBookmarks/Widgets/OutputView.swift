//
//  OutputView.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2018-02-09.
//  Copyright © 2018 dfaulks. All rights reserved.
//

import Cocoa

class OutputView: NSViewController,GBListBoxDelegate {
    
    @IBOutlet weak var pickTemplateList: GBListBox!
    @IBOutlet weak var loadTemplateButton: NSButton!
    @IBOutlet weak var templateStatusLabel: NSTextField!
    
    @IBOutlet weak var outputProgressLabel: NSTextField!
    @IBOutlet weak var outputProgressBar: NSProgressIndicator!
    @IBOutlet weak var progressDetailLabel: NSTextField!
    
    @IBOutlet weak var startOutputButton: NSButton!
    @IBOutlet weak var cancelButton: NSButton!
    @IBOutlet weak var outputDirectoryButton: NSButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        let dcount = loadTemplateDocumentList()
        pickTemplateList.delegate = self
        pickTemplateList.labelString = "Pick the Template to use:"
    }
    
    //=========================================================
    private var outputterTemplateList:[GBTemplateDocument] = []
    var itemCount:Int {
        print("List count:\(outputterTemplateList.count)")
        return outputterTemplateList.count
    }
    func getStringAtIndex(_ index:Int) -> String? {
        if index >= self.itemCount { return nil }
        else {
            let ostring = outputterTemplateList[Int(index)].document_data.templateName
            print("Template Name: \(ostring)")
            return ostring
            
        }
    }
    var attachedListBox:GBListBox? {
        get { return self.pickTemplateList }
        set(value) { /* do nothing */ }
    }
    //---------------------------------------------------------
    func selectionChange(_ newSelection: Int, oldSelection: Int) {
        if newSelection < 0 {
            startOutputButton.isEnabled = false
            templateStatusLabel.stringValue = "No Template Picked"
        }
        else if (!outputting) {
            startOutputButton.isEnabled = true
            let dataPointer = outputterTemplateList[newSelection].document_data
            templateStatusLabel.stringValue = dataPointer.templateName
        }
    }
    //=============================================================
    // private 'get a list of already loaded GBTemplateDocument'
    private func loadTemplateDocumentList() -> Int {
        let docControl = NSDocumentController.shared
        var dcount:Int = 0
        for document in docControl.documents {
            guard let outputDoc = document as? GBTemplateDocument else { continue }
            if outputterTemplateList.contains(outputDoc) { continue }
            dcount += 1
            outputterTemplateList.append(outputDoc)
            print("Dcount: \(dcount)")
        }
        pickTemplateList.reloadData(true)
        return dcount
    }
    private var outputting:Bool = false
    //=========================================================
    var outputPtr:GB_LinkCollection? = nil
    private var outputterPtr:GBTemplateOutputter? = nil
    private var outputDirectory:String = NSHomeDirectory()
    
    // when the output button is clicked
    @IBAction func OutputCollectionAction(_ sender: Any) {
        // getting the document to use...
        let sdoc = pickTemplateList.selectedIndex
        assert(sdoc >= 0)
        assert(outputPtr != nil)
        let useDoc = outputterTemplateList[sdoc]
        // initial GUI stuff
        startOutputButton.isEnabled = false
        outputProgressBar.doubleValue = 0.0
        progressDetailLabel.stringValue = "Starting..."
        // more document prep
        useDoc.saveActiveDocument()
        outputterPtr = useDoc.document_data
        // preparing for the output...
        let pageCount = outputPtr!.listOfPages.count
        outputProgressBar.maxValue = Double(pageCount+1)
        let ores = outputterPtr!.setupOutput(collection: outputPtr!, targetDirectory: outputDirectory)
        assert(ores)
        // making the page done block
        pageDoneBlock = { (okay:Bool,error:Error?) in
            DispatchQueue.main.async {
                if okay { self.pageOutputDone() }
                else {
                    self.progressDetailLabel.stringValue += " Failed! \(error?.localizedDescription)"
                    self.startOutputButton.isEnabled = true
                }
            }
        }
        // starting...
        DispatchQueue.global(qos: .utility).async {
            // building the page naviagtion
            _ = self.outputterPtr!.buildPageNav()
            DispatchQueue.main.async {
                self.outputProgressBar.doubleValue += 1.0
            }
            // now we start on the first page
            let nxPageInfo = self.outputterPtr!.outputNextPage(doWhenDone: self.pageDoneBlock)
            if nxPageInfo.0 {
                DispatchQueue.main.async {
                    self.progressDetailLabel.stringValue = "Outputting page '\(nxPageInfo.1!)'..."
                }
            }
            // here, starting the first page could not event be started
            else {
                DispatchQueue.main.async {
                    self.progressDetailLabel.stringValue = "Failed to start, missing pages to output!"
                    self.startOutputButton.isEnabled = true
                }
            }
        }
    }
    
    private var pageDoneBlock:((Bool,Error?)->Void)? = nil
    
    // when a page is finished outputting
    private func pageOutputDone() -> Bool {
        outputProgressBar.doubleValue += 1.0
        progressDetailLabel.stringValue += " Done"
        let nxPageInfo = outputterPtr!.outputNextPage(doWhenDone: pageDoneBlock)
        if nxPageInfo.0 {
            progressDetailLabel.stringValue = "Outputting page '\(nxPageInfo.1!)'..."
            return true
        }
        // this hsould only happen if there are no more pages done
        else {
            progressDetailLabel.stringValue += " and Finished."
            self.startOutputButton.isEnabled = true
            return false
        }
    }
    
    @IBAction func cancelAction(_ sender: Any) {
        self.dismissViewController(self)
    }
    //----------------------------------
    @IBAction func pickOutputDirectoryAction(_ sender: Any) {
        let odURL = URL(fileURLWithPath: self.outputDirectory, isDirectory: true)
        
        let newOutputDir = pickDirectoryDialog(title: "Pick the output directory", startDirectory: odURL)
        if newOutputDir != nil {
            outputDirectory = newOutputDir!
        }
    }
    
    //=========================================================
    
}
