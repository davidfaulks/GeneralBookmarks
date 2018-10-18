//
//  LinkEditViewController.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-05-09.
//  Copyright © 2016-2018 dfaulks. All rights reserved.
//
// Last updated Dec 15, 2017

import Cocoa
//************************************************************************
// notification related comstants
let LinkTextChangedNotification = NSNotification.Name(rawValue: "LinkTextChangedNotification")
let fromLabelEditKey = "From Label Edit"
let newTextKey = "The New Text"
let LinkDataChangedNotification = NSNotification.Name(rawValue: "LinkDataChangedNotification")
//========================================================================

// custom table view cell for displaying (editable) link Label and URL
class GB_LabelUrlTableCellView : NSTableCellView, NSTextFieldDelegate {
    @IBOutlet weak var linkLabelEdit: NSTextField!
    @IBOutlet weak var linkURLEdit: NSTextField!
    
    // when text has changed, we dispatch a notification, to be handled by LinkEditViewController
    override func controlTextDidChange(_ obj: Notification) {
        // which of the text edits does the change come from?
        let sender = obj.object! as! NSTextField
        let fromLabel:Bool
        if sender === linkLabelEdit { fromLabel = true }
        else if sender === linkURLEdit { fromLabel = false }
        else { return }
        // getting the changed text
        let changedText = (fromLabel) ? (linkLabelEdit.stringValue) : (linkURLEdit.stringValue)
        // building the user info
        let messageInfo:[String:AnyObject] = [fromLabelEditKey:fromLabel as AnyObject,newTextKey:changedText as AnyObject]
        // sending the notification
          NotificationCenter.default.post(name: LinkTextChangedNotification, object: self, userInfo: messageInfo)
    }
    
    // because there is no viewDidLoad for table cell views
    func setup() {
        linkLabelEdit.delegate = self
        linkURLEdit.delegate = self
    }
    
}
//==========================================================================================
// the view controller, embedded in the main view, it is used to view and edit link details
class LinkEditViewController: NSViewController,NSTableViewDelegate, NSTableViewDataSource {
    
    // +++ [ Widgets ] ++++++++++++++++++++++++
    
    @IBOutlet weak var locationLabel: NSTextField!
    
    @IBOutlet weak var majorLinkCheckbox: NSButton!
    @IBOutlet weak var depreciatedCheckbox: NSButton!
    @IBOutlet weak var beingCheckedLabel: NSTextField!
    @IBOutlet weak var checkURLButton: NSButton!
    
    @IBOutlet weak var linksDisplayTable: NSTableView!
    
    // +++ [ The data being displayed ] +++++++++++++++++++
    fileprivate(set) var displayedSite:GB_SiteLink? = nil
    fileprivate(set) var displayedLinkIndex:Int = -1
    fileprivate(set) var fromUnsorted = false
    // extra pointer
    let checker = (NSApplication.shared.delegate as! AppDelegate).linkChecker
    // ------------------------------------------------------
    // when we get a notification to change the site, we unpack and handle it here
    func changeSiteUsingData(_ notificationData:[String : AnyObject]) -> Bool {
        // basic info: what index is the link, where does the notification come from?
        let sIndex = notificationData[indexKey]! as! Int
        displayedLinkIndex = sIndex
        fromUnsorted = notificationData[unsortedKey]! as! Bool
        // here, we are to display nothing!
        if sIndex < 0 {
            locationLabel.stringValue = "No Site Displayed"
            return changeDisplayedSite(nil)
        }
        // we are displaying something, but most of the code here just updates the origin label
        else {
            let newSite = notificationData[linkKey]! as! GB_SiteLink
            if fromUnsorted { locationLabel.stringValue = "From Unsorted Links :" }
            else {
                let fromPage = notificationData[pageNameKey]! as! String
                let fromGroup = notificationData[groupNameKey]! as! String
                locationLabel.stringValue = " From the Group \(fromGroup), in the Page \(fromPage) :"
            }
            // changeDisplayedSite handles most of the GUI updates
            return changeDisplayedSite(newSite)
        }
    }
    
    // given a site object, updated the checkboxes and link tables to show the site
    func changeDisplayedSite(_ newDisplayedSite:GB_SiteLink?) -> Bool {
        if newDisplayedSite !== displayedSite {
            displayedSite = newDisplayedSite
            majorLinkCheckbox.state = (displayedSite?.important ?? false) ? .on : .off
            depreciatedCheckbox.state = (displayedSite?.depreciated ?? false) ? .on : .off
            linksDisplayTable.reloadData()
            if displayedSite != nil {
                majorLinkCheckbox.isEnabled = true
                depreciatedCheckbox.isEnabled = true
                let checkval = displayedSite!.checking
                setCheckingWidgets(isChecking: checkval)
            }
            else {
                majorLinkCheckbox.isEnabled = false
                depreciatedCheckbox.isEnabled = false
                beingCheckedLabel.stringValue = ""
                checkURLButton.isEnabled = false
            }
            
            return true
        }
        else { return false }        
    }
    // +++ [ Checkbox Actions ] +++++++++++++++++++++++++++++++++++
    
    @IBAction func majorLinkCheckboxChanged(_ sender: AnyObject) {
        let mlTrue = (majorLinkCheckbox.state == .on)
        displayedSite!.important = mlTrue
        sendLinkDataChangedNotification()
    }
    
    @IBAction func depreciatedCheckboxChanged(_ sender: AnyObject) {
        let depTrue = (depreciatedCheckbox.state == .on)
        displayedSite!.depreciated = depTrue
        sendLinkDataChangedNotification()
    }
    
    // +++ [ Notification Handlers ] +++++++++++++++++++++++++++++++
    
    // sending the link changed notification is pretty uniform, so we have a separate method
    fileprivate func sendLinkDataChangedNotification() {
        let sentUserInfo:[String:AnyObject] = [unsortedKey:fromUnsorted as AnyObject,indexKey:displayedLinkIndex as AnyObject]
        NotificationCenter.default.post(name: LinkDataChangedNotification, object: self, userInfo: sentUserInfo)
    }
    
    // notification from a table cell that the data has changed
    @objc func handleLinkTextChangedNotification(_ notification: Notification) {
        // extracting the notification data
        let cellFrom = notification.object as! GB_LabelUrlTableCellView
        let notifyDict = notification.userInfo as! [String:AnyObject]
        let labelChanged = notifyDict[fromLabelEditKey] as! Bool
        let newText = notifyDict[newTextKey] as! String
        // finding the index (row) of the link it the site
        let linkRow = linksDisplayTable.row(for: cellFrom)
        assert(linkRow>=0)
        let changeDone:Bool
        // updating the data
        if labelChanged {
            changeDone = displayedSite!.setLabelAtIndex(linkRow, inlabel: newText)
        }
        else {
            changeDone = displayedSite!.setUrlAtIndex(linkRow, inurl: newText)
            if changeDone {
                linksDisplayTable.reloadData(forRowIndexes: IndexSet(integer:linkRow), columnIndexes: IndexSet(integer:0))
            }
        }
        // in some cases, we also need to send a notification, so...
        if (linkRow == 0) && changeDone { sendLinkDataChangedNotification() }
        // done
    }
    
    // +++ [ Basic Table Delegates ] ++++++++++++++++++++++
    func numberOfRows(in tableView: NSTableView) -> Int {
        return displayedSite?.linkCount ?? 0
    }
    
    // (required delegate) returns the view for each column
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        // handling some nil cases relating to the column
        if tableColumn == nil { return nil }
        guard let columnIndex = tableView.tableColumns.index(of: tableColumn!) else { return nil }
        // checking the row (because I am paranoid)
        assert(row >= 0)
        assert( row < (displayedSite?.linkCount ?? 0))
        // we have two types of cell, one for the status, and the other for displaying/editing label and URL
        let StatusCellIdent = "StatusTableCell"
        let EditCellIdent = "LabelAndURLTableCell"
        // column 0 is for the status
        if columnIndex == 0 {
            var outputStatusView:NSTableCellView? = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: StatusCellIdent), owner: self) as? NSTableCellView
            if outputStatusView == nil {
                outputStatusView = NSTableCellView(frame: NSRect())
                outputStatusView!.identifier = NSUserInterfaceItemIdentifier(rawValue: StatusCellIdent)
            }
            let status = displayedSite!.getStatusAtIndex(row)
            let scolour = getColourForStatus(status)
            outputStatusView!.textField!.textColor = scolour
            outputStatusView!.textField!.stringValue = status.rawValue
            return outputStatusView
        }
        // column 1 is the editor for Label and URL
        else if columnIndex == 1 {
            var outputEditView:GB_LabelUrlTableCellView? = tableView.makeView(withIdentifier: NSUserInterfaceItemIdentifier(rawValue: EditCellIdent), owner: self) as? GB_LabelUrlTableCellView
            if outputEditView == nil {
                outputEditView = GB_LabelUrlTableCellView(frame: NSRect())
                outputEditView!.identifier = NSUserInterfaceItemIdentifier(rawValue: EditCellIdent)
            }
            outputEditView!.linkLabelEdit.stringValue = displayedSite!.getLinkLabelAtIndex(row)
            outputEditView!.linkURLEdit.stringValue = displayedSite!.getUrlAtIndex(row)
            outputEditView!.setup()
            return outputEditView
        }
        else { return nil }
       
    }
    
    // +++ [ Drag and drop row re-ordering ] +++++++++++++++++++++++++++++++++++
    let GBLinkDataPBoardType = "GBLinkDataPBoardType"
    
    // (optional delegate) dragging started
    func tableView(_ tableView: NSTableView, writeRowsWith writeRowsWithIndexes: IndexSet, to toPasteboard: NSPasteboard) -> Bool {
        toPasteboard.declareTypes([NSPasteboard.PasteboardType(rawValue: GBLinkDataPBoardType)], owner:self)
        let data = NSKeyedArchiver.archivedData(withRootObject: writeRowsWithIndexes)
        toPasteboard.setData(data, forType:NSPasteboard.PasteboardType(rawValue: GBLinkDataPBoardType))
        return true
    }
    // (optional delegate) dragging ongoing
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        tableView.setDropRow(row, dropOperation: NSTableView.DropOperation.above)
        return NSDragOperation.move
    }
    
    // helper method to get the source indexes when dragging and dropping
    fileprivate func getIndexesFromInfo(_ dragInfo:NSDraggingInfo) -> IndexSet? {
        // gathering initial data
        let pasteboard = dragInfo.draggingPasteboard()
        guard let rowData = pasteboard.data(forType: NSPasteboard.PasteboardType(rawValue: GBLinkDataPBoardType)) else { return nil }
        guard let dataIndexes = NSKeyedUnarchiver.unarchiveObject(with: rowData) as! IndexSet? else { return nil }
        // exit if no row data
        if dataIndexes.count == 0 { return nil }
        else { return dataIndexes }
    }
    // (optional delegate) drop
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        // initial data which might be nil or bad
        guard let dragSource = info.draggingSource() as! NSTableView? else { return false }
        guard let sourceIndexes = getIndexesFromInfo(info) else { return false }
        if row < 0 { return false }
        // starting...

        // if the source is the same table, we have a drag and drop re-order
        if dragSource === tableView {
            // re-ordering the source
            displayedSite!.moveLinkAtIndex(sourceIndexes.min()!, toIndex: row)
            // reloading, and moving the selection indexe to the newly inserted value
            let newSelected = (sourceIndexes.first! < row) ? (row-1) : row
            linksDisplayTable!.reloadData()
            linksDisplayTable!.selectRowIndexes(IndexSet(integer:newSelected), byExtendingSelection: false)
            // done
            sendLinkDataChangedNotification()
            return true
        }
        // no other source currently supported
        else { return false }
    }    

    // +++ [ Popup menu related methods ] +++++++++++++++++++
    fileprivate var linkTablePopupMenu:NSMenu? = nil
    fileprivate let addLinkTag = "Add a Link to the Site..."
    fileprivate let deleteLinkTag = "Delete this Link"
    
    // creating the menu and attaching it to the tablelinkTablePopupMenu
    fileprivate func setupPopupMenu() {
        // page picker popup menu
        linkTablePopupMenu = NSMenu()
        
        let addLinkMenuItem = NSMenuItem()
        addLinkMenuItem.title = addLinkTag
        addLinkMenuItem.target = self
        addLinkMenuItem.action = #selector(handleAddLinkToSite)
        linkTablePopupMenu!.addItem(addLinkMenuItem)
        
        let deleteLinkMenuItem = NSMenuItem()
        deleteLinkMenuItem.title = deleteLinkTag
        deleteLinkMenuItem.target = self
        deleteLinkMenuItem.action = #selector(handleDeleteLinkFromSite)
        linkTablePopupMenu!.addItem(deleteLinkMenuItem)
        
        linksDisplayTable.menu = linkTablePopupMenu
    }
    // appending a new link for the site
    @objc func handleAddLinkToSite(_ sender:AnyObject?) {
        let result = showModalTextEntry("Additional Link", info: "Enter a non-empty label for the new link.",
                                        defaultText: "(new Link)", nonEmpty: true)
        if result != nil {
            // making up a fake url
            let fakeUrl = "http://www.zog.qx/"
            displayedSite!.appendUrlAndLabel(url: fakeUrl, label: result!)
            reloadLink()
        }
        
    }
    // deleting a link from the site
    @objc func handleDeleteLinkFromSite(_ sender:AnyObject?) {
        let clickedRow = linksDisplayTable!.clickedRow
        if clickedRow >= 0 {
            displayedSite!.deleteLinkAtIndex(clickedRow)
            sendLinkDataChangedNotification()
        }
    }
    // validating the menu items
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem === linkTablePopupMenu!.item(withTitle: deleteLinkTag) {
            return (displayedSite!.linkCount > 1)
        }
        return true
    }
    // ++++ [ Checking the URL stuff ] ++++++++++++++++++++++
    private func setCheckingWidgets(isChecking:Bool) {
        // setting the button...
        beingCheckedLabel.stringValue = displayedSite!.checking ? "Being checked" : ""
        // when checking, we disable changing the link data
        linksDisplayTable.isEnabled = !isChecking
        // also, the button
        checkURLButton.isEnabled = !isChecking
        // the checkboxes are okay because they only affect writing the output
    }
    
    @IBAction func checkButtonAction(_ sender: Any) {
        checker.launchCheck(urldata: displayedSite!)
        setCheckingWidgets(isChecking: true)
    }
    
    // helper method for re-loading some data
    private func reloadLink() -> Bool {
        if displayedSite == nil { return false }
        let checking = displayedSite!.checking
        linksDisplayTable.reloadData()
        setCheckingWidgets(isChecking: checking)
        return true
    }
    
    // handler for the notification that a single link check is done...
    @objc func handleLinkCheckSingleNotification(_ notification: Notification) {
        let data = notification.userInfo as! [String:Any]
        guard let objectChecked = data[LinkObjectKey] as? GB_SiteLink else { return }
        if objectChecked === displayedSite {
            DispatchQueue.main.async { self.reloadLink() }
        }
    }
    
    
    // +++ [ the usual setup methods ] ++++++++++++++++++++++
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do view setup here.
        linksDisplayTable.dataSource = self
        linksDisplayTable.delegate = self
        NotificationCenter.default.addObserver(self,selector: #selector(handleLinkTextChangedNotification),
                                                         name: LinkTextChangedNotification,object: nil)
        
        // Notification sent for check updates
        NotificationCenter.default.addObserver(self, selector: #selector(handleLinkCheckSingleNotification), name: NotifSiteCheckSingle, object: nil)
        
        majorLinkCheckbox.isEnabled = false
        depreciatedCheckbox.isEnabled = false
        linksDisplayTable.registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: GBLinkDataPBoardType)])
        beingCheckedLabel.stringValue = ""
        checkURLButton.isEnabled = false
        
        setupPopupMenu()
    }
    
   
    
}
