//
//  OutputView.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2019-02-09.
//  Copyright © 2019 dfaulks. All rights reserved.

/*
 To Fix:
 • implement add template from file
 • when output is done, either close immedialty or change cancel button to 'Done'
 • Fix problem when trying to output more than once
 • Display output directory
*/

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
    @IBOutlet weak var outputDirectoryLabel: NSTextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        let dcount = loadTemplateDocumentList()
        pickTemplateList.delegate = self
        pickTemplateList.labelString = "Pick the Template to use:"
        outputDirectoryLabel.stringValue = "To: " + self.outputDirectory
        startOutputButton.isEnabled = (pickTemplateList.selectedIndex >= 0)
    }
    
    //=========================================================
    private var outputterTemplateList:[GBTemplateDocument] = []
    var itemCount:Int {
        return outputterTemplateList.count
    }
    func getStringAtIndex(_ index:Int) -> String? {
        if index >= self.itemCount { return nil }
        else {
            let ostring = outputterTemplateList[Int(index)].document_data.templateName
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
    //========================================================
    // enabling / disabling widgets (disable to prevent action when something else is going on)
    private func bulkEnabled(_ setEn:Bool) {
        pickTemplateList.isEnabled = setEn
        loadTemplateButton.isEnabled = setEn
        startOutputButton.isEnabled = setEn
        cancelButton.isEnabled = setEn
        outputDirectoryButton.isEnabled = setEn
    }
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
        bulkEnabled(false)
        outputProgressBar.doubleValue = 0.0
        progressDetailLabel.stringValue = "Starting..."
        print("OutputCollectionAction A")
        // more document prep
        useDoc.saveActiveDocument() // might do nothing if the template has no window
        print("OutputCollectionAction B")
        outputterPtr = useDoc.document_data
        // preparing for the output...
        let pageCount = outputPtr!.listOfPages.count
        print("OutputCollectionAction C \(pageCount)")
        outputProgressBar.maxValue = Double(pageCount+1)
        let ores = outputterPtr!.setupOutput(collection: outputPtr!, targetDirectory: outputDirectory)
        print("OutputCollectionAction D \(ores)")
        assert(ores)
        // making the page done block
        pageDoneBlock = { (okay:Bool,error:Error?) in
            DispatchQueue.main.async {
                if okay { self.pageOutputDone() }
                else {
                    self.progressDetailLabel.stringValue += " Failed! \(error?.localizedDescription)"
                    self.bulkEnabled(true)
                }
            }
        }
        print("OutputCollectionAction E")
        // starting...
        DispatchQueue.global(qos: .utility).async {
            // building the page naviagtion
            _ = self.outputterPtr!.buildPageNav()
            print("OutputCollectionAction F")
            DispatchQueue.main.async {
                self.outputProgressBar.doubleValue += 1.0
            }
            print("OutputCollectionAction G")
            // now we start on the first page
            let nxPageInfo = self.outputterPtr!.outputNextPage(doWhenDone: self.pageDoneBlock)
            print("OutputCollectionAction H \(nxPageInfo)")
            if nxPageInfo.0 {
                DispatchQueue.main.async {
                    self.progressDetailLabel.stringValue = "Outputting page '\(nxPageInfo.1!)'..."
                }
            }
            // here, starting the first page could not event be started
            else {
                DispatchQueue.main.async {
                    self.progressDetailLabel.stringValue = "Failed to start, missing pages to output!"
                    self.bulkEnabled(true)
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
        // this sould only happen if there are no more pages done
        else {
            progressDetailLabel.stringValue += " and Finished."
            self.cancelButton.title = "Close"
            self.bulkEnabled(true)
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
            outputDirectoryLabel.stringValue = "To: " + self.outputDirectory
        }
    }
    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // when loading mulriple templates, keep track of the counts
    private var to_open:Int = 0
    private var handled:Int = 0
    private var was_open:Int = 0
    private var failed_open:Int = 0
    private let flock = NSLock();
    
    // lauches the dialog and loads template files
    @IBAction func addTemplateFromFileAction(_ sender: Any) {
        let picks = openFileDialogMulti("Pick template files to add.", filetypes:["outtempl"])
        if picks == nil { return }
        if (picks!.count == 0) { return }
        // preparing to open the specified URLs
        bulkEnabled(false)
        let docControl = NSDocumentController.shared
        flock.lock()
        to_open = picks!.count
        handled = 0
        was_open =  0
        failed_open = 0
        flock.unlock()
        // lauching the opens in a loop, this triggers callbacks
        for fileURL in picks! {
            // opening via callback
            docControl.openDocument(withContentsOf: fileURL, display: false, completionHandler: openDocCompletion)
        }
    }
    /* handles a template document being loaded. once all of them are, we reload the template select
        listbox and enable the buttons, done. */
    private func openDocCompletion(docfile:NSDocument?, wasOpen:Bool, err:Error?) {
        flock.lock()
        handled += 1;
        if (wasOpen) { was_open += 1 }
        else if (err != nil) { failed_open += 1 }
        // if the open was successful, the document is already in the list of open documents
        if (handled == to_open) {
            flock.unlock()
            loadTemplateDocumentList();
            bulkEnabled(true)
            startOutputButton.isEnabled = (pickTemplateList.selectedIndex >= 0)
        }
        else { flock.unlock() }
    }
    //=========================================================
    
}
