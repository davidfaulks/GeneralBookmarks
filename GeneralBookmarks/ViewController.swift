//
//  ViewController.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-08-11.
//  Copyright © 2016-2019 dfaulks. All rights reserved.
//

import Cocoa

class ViewController: NSViewController,NSTextFieldDelegate {

    // GUI elements
    @IBOutlet weak var progressWidget: NSProgressIndicator!
    @IBOutlet weak var messageDisplay: NSTextField!
    
    // link tables
    @IBOutlet weak var unsortedLinksLabel: NSTextField!
    @IBOutlet weak var unsortedLinksTable: GB_LinkTableView!
    @IBOutlet weak var currentGroupLinksLabel: NSTextField!
    @IBOutlet weak var currentGroupLinksTable: GB_LinkTableView!
    
    // page and group pickers
    @IBOutlet weak var groupPickerList: GBListBox!
    @IBOutlet weak var pagePickerList: GBListBox!
    @IBOutlet weak var leaveOffNavCheckBox: NSButton!
    // the site links editor container
    let siteEditorID = NSStoryboardSegue.Identifier("EMBEDDED_SITE_LINK_EDITOR")
    @IBOutlet weak var siteEditorContainer: NSView!
    var siteEditorPointer:LinkEditViewController? = nil
    
    @IBOutlet weak var collectionNameEdit: NSTextField!
    
    // popup menu objects
    var pagePickerPopupMenu:NSMenu? = nil
    var groupPickerPopupMenu:NSMenu? = nil
    var unsortedLinksPopupMenu:NSMenu? = nil
    var currentGroupLinksPopupMenu:NSMenu? = nil
    
    
    // +++ [ Non-GUI delegates and data ] +++++++++++++++++++++++++
    
    fileprivate var docPointer:GBDocument? = nil
    fileprivate var appPtr:AppDelegate!
    
    // customized delegates for the link views, and page and group pickers
    fileprivate var unsortedLinksDelegate:GB_UnsortedLinksDelegate? = nil
    fileprivate var groupLinksDelegate:GB_CurrentGroupLinksDelegate? = nil
    fileprivate var groupListDelegate:GB_GroupNamesDelegate? = nil
    fileprivate var pageListDelegate:GB_PageNamesDelegate? = nil
    
    
    // +++ [ Helper Methods ] +++++++++++++++++++++++++++++++++++++
    fileprivate func GetDocument() -> GBDocument? {
        let doc = NSDocumentController.shared.document(for: view.window!)
        return (doc as? GBDocument)
    }
    
    // sets up the link tables and list boxes
    fileprivate func setupTablesAndLists() {
        
        // link tables and thier delegates
        unsortedLinksDelegate = GB_UnsortedLinksDelegate()
        groupLinksDelegate = GB_CurrentGroupLinksDelegate()
        attachLinkTable(unsortedLinksTable, toDelegate: unsortedLinksDelegate!)
        attachLinkTable(currentGroupLinksTable, toDelegate: groupLinksDelegate!)
        unsortedLinksDelegate!.otherTable = currentGroupLinksTable
        groupLinksDelegate!.otherTable = unsortedLinksTable
        unsortedLinksTable.registerForDraggedTypes([GBSiteLinkPBoardType])
        currentGroupLinksTable.registerForDraggedTypes([GBSiteLinkPBoardType])

        // listviews for groups (with delegates)
        groupListDelegate = GB_GroupNamesDelegate()
        groupListDelegate!.attachedListBox = groupPickerList
        groupPickerList!.delegate = groupListDelegate!

        groupPickerList.labelString = "Groups"
        groupPickerList.allowDragReordering = true
        groupListDelegate!.currGroupLinksTable = currentGroupLinksTable
        groupListDelegate!.unsortedLinksTable = unsortedLinksTable
        groupPickerList.allowExternalDragDrop = true
        _ = groupPickerList.addExternalDragTypes([GBSiteLinkPBoardType])
        
        // listviews for pages (with delegates)
        pageListDelegate = GB_PageNamesDelegate()
        pageListDelegate!.attachedListBox = pagePickerList
        pagePickerList!.delegate = pageListDelegate!

        pagePickerList.labelString = "Pages"
        pagePickerList.allowDragReordering = true
        pagePickerList.allowExternalDragDrop = true
        pageListDelegate!.sourceListFromDrop = groupPickerList
    }
    
    // to shorten things
    private func NAdd(sel:Selector, name:NSNotification.Name, source: Any?) {
        NotificationCenter.default.addObserver(self, selector: sel, name: name, object: source)
    }
    
    fileprivate func setupNotificationObservers() {
        NAdd(sel: #selector(handleLinkClickedNotification), name: LinkClickedNotification, source: unsortedLinksTable)
        NAdd(sel: #selector(handleLinkClickedNotification), name: LinkClickedNotification, source: currentGroupLinksTable)
        // NAdd(sel: #selector(handleLinkDataChangedNotification), name: LinkDataChangedNotification, source: nil)
        NAdd(sel: #selector(handleGroupChangeNotification), name: GroupChangedNotification, source: groupPickerList)
        NAdd(sel: #selector(handlePageChangeNotification), name: PageChangedNotification, source: pagePickerList)
        
        // Notification sent for check updates
        NotificationCenter.default.addObserver(self, selector: #selector(handleSingleLinkCheckNotification), name: NotifSiteCheckSingle, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleALinkCheckNotification), name: NotifSiteCheckMultiple, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLinkListCheckingDone), name: NotifSiteChecksDone, object: nil)
        
    }
    
    fileprivate let newPageTag = "Add a New Page..."
    fileprivate let renamePageTag = "Rename this Page..."
    fileprivate let deletePageTag = "Delete this Page..."
    fileprivate let newGroupTag = "Add a New Group..."
    
    fileprivate let renameGroupTag = "Rename this Group..."
    fileprivate let deleteGroupTag = "Delete this Group"
    
    fileprivate let addLinkTitle = "Add a new Link..."
    fileprivate let deleteLinkTitle = "Delete this Link"
    private let deleteMLinksTitle = "Delete selected Links"
    fileprivate let openLinkTitle = "Open Link in a browser"
    fileprivate let checkLinksTitle = "Start checking Links"
    fileprivate let filterOrderTitle = "Order and Remove Duplicates"
    
    // shortener helper for popup menu
    private func makeMI(_ title:String, action:Selector) -> NSMenuItem {
        let res = NSMenuItem()
        res.title = title
        res.target = self
        res.action = action
        return res
    }
    
    // the tables and lists have right/ctrl click popup menus
    private func setupContextMenus() {
        // page picker popup menu
        pagePickerPopupMenu = NSMenu()
        // new page
        var nmi = makeMI(newPageTag, action: #selector(handleMenuNewPage))
        pagePickerPopupMenu!.addItem(nmi)
        // rename page
        nmi = makeMI(renamePageTag, action:#selector(handleMenuRenamePage))
        pagePickerPopupMenu!.addItem(nmi)
        // delete page
        nmi = makeMI(deletePageTag, action: #selector(handleMenuDeletePage))
        pagePickerPopupMenu!.addItem(nmi)
        
        pagePickerList.tableMenu = pagePickerPopupMenu
        
        // group picker popup menu
        groupPickerPopupMenu = NSMenu()
        // new group
        nmi = makeMI(newGroupTag, action: #selector(handleMenuNewGroup))
        groupPickerPopupMenu!.addItem(nmi)
        // rename group
        nmi = makeMI(renameGroupTag, action: #selector(handleMenuRenameGroup))
        groupPickerPopupMenu!.addItem(nmi)
        // delete group
        nmi = makeMI(deletePageTag, action: #selector(handleMenuDeleteGroup))
        groupPickerPopupMenu!.addItem(nmi)
        
        groupPickerList.tableMenu = groupPickerPopupMenu
        
        // unsorted links popup menu
        unsortedLinksPopupMenu = NSMenu()
        // add new link
        nmi = makeMI(addLinkTitle, action: #selector(handleMenuUnsortedAddSite))
        unsortedLinksPopupMenu!.addItem(nmi)
        // delete one site
        nmi = makeMI(deleteLinkTitle, action: #selector(handleMenuUnsortedDeleteSite))
        unsortedLinksPopupMenu!.addItem(nmi)
        // delete selected sites
        nmi = makeMI(deleteMLinksTitle, action:#selector(handleMenuUnsortedDeleteMultiple) )
        unsortedLinksPopupMenu!.addItem(nmi)
        // filter for duplicates and sort by first url
        nmi = makeMI(filterOrderTitle, action: #selector(handleMenuUnsortedFilerAndOrder))
        unsortedLinksPopupMenu!.addItem(nmi)
        unsortedLinksPopupMenu!.addItem(NSMenuItem.separator())
        // open link in browser
        nmi = makeMI(openLinkTitle, action: #selector(handleMenuUnsortedOpenSite))
        unsortedLinksPopupMenu!.addItem(nmi)
        // check all links
        nmi = makeMI(checkLinksTitle, action: #selector(handleMenuUnsortedCheckLinks))
        unsortedLinksPopupMenu!.addItem(nmi)
        
        
        unsortedLinksTable.menu = unsortedLinksPopupMenu
        
        // current group links popup menu
        currentGroupLinksPopupMenu = NSMenu()
        
        // add new link
        nmi = makeMI(addLinkTitle, action: #selector(handleMenuCurrGroupAddSite))
        currentGroupLinksPopupMenu!.addItem(nmi)
        // delete link in group
        nmi = makeMI(deleteLinkTitle, action: #selector(handleMenuCurrGroupDeleteSite))
        currentGroupLinksPopupMenu!.addItem(nmi)
        // delete selected sites
        nmi = makeMI(deleteMLinksTitle, action: #selector(handleMenuGroupLinksDeleteMultiple))
        currentGroupLinksPopupMenu!.addItem(nmi)
        unsortedLinksPopupMenu!.addItem(NSMenuItem.separator())
        // open in browser
        nmi = makeMI(openLinkTitle, action: #selector(handleMenuCurrentGroupOpenSite))
        currentGroupLinksPopupMenu!.addItem(nmi)
        // check links in group
        nmi = makeMI(checkLinksTitle, action: #selector(handleMenuCurrentGroupCheckLinks))
        currentGroupLinksPopupMenu!.addItem(nmi)
        
        currentGroupLinksTable.menu = currentGroupLinksPopupMenu
   
    }
    
    // loads the link collection into the delegates
    fileprivate func collectionIntoDelegates(_ collection:GB_LinkCollection?) {
        unsortedLinksDelegate!.collection = collection
        groupLinksDelegate!.collection = collection
        groupListDelegate!.collection = collection
        pageListDelegate!.collection = collection
        // also, load the collection name
        collectionNameEdit.stringValue = collection!.collectionName
    }
    
    // +++ [ Popup Menu Handlers ] ++++++++++++++++++++++++++++++++
    
    /* A helper function for deleting pages or groups. The result is nil if
     cancel, true if delete and move links, and false if just delete. */
    fileprivate func showDeleteDialog(_ delGroups:Bool, itemName:String, activeLinkCount:UInt, totalLinkCount:UInt) ->Bool? {
        // building the string messages
        let delType = delGroups ? "Group" : "Page"
        let delInfo = "The \(delType) \(itemName) has \(activeLinkCount)  active links " +
            "(\(totalLinkCount) total).\nDo you want to move these links to Unsorted Links?"
        let delMsg = "Delete \(delType) Confirmation"
        // building the dialog
        let deleteDialog = NSAlert()
        deleteDialog.messageText = delMsg
        deleteDialog.informativeText = delInfo
        deleteDialog.alertStyle = .warning
        deleteDialog.addButton(withTitle: "Move Links and Delete")
        deleteDialog.addButton(withTitle: "Delete including Links")
        deleteDialog.addButton(withTitle: "Cancel")
        // running
        let result = deleteDialog.runModal()
        if result == NSApplication.ModalResponse.alertFirstButtonReturn { return true }
        else if result == NSApplication.ModalResponse.alertSecondButtonReturn { return false }
        else { return nil }
    }
    
    // page picker list : menu handler to add a new empty page
    @objc func handleMenuNewPage(_ sender:AnyObject?) {
        let clickedRow = pagePickerList.clickedRow
        let result = showModalTextEntry("New Page", info: "Enter a non-empty name for the new page.",
                                        defaultText: "(new Page \(clickedRow))", nonEmpty: true)
        if result != nil {
            let newPage = GB_PageOfLinks(inName:result!)
            // insert at end
            if clickedRow < 0 {
                docPointer!.document_data.listOfPages.append(newPage)
                let newIndex = docPointer!.document_data.listOfPages.count - 1
                _ = pagePickerList.reloadAndSelect(newIndex, true)
            }
                // insert at a specific spot
            else {
                docPointer!.document_data.listOfPages.insert(newPage, at: clickedRow)
                _ = pagePickerList.reloadAndSelect(clickedRow, true)
            }
        }
    }
    // page picker list : menu handler to rename an existing page
    @objc func handleMenuRenamePage(_ sender:AnyObject?) {
        let clickedRow = pagePickerList.clickedRow
        if clickedRow >= 0 {
            let oname = pageListDelegate!.getStringAtIndex(clickedRow)!
            let result = showModalTextEntry("Rename Page", info: "Enter a new, non-empty name for the page.",defaultText: oname, nonEmpty: true)
            if result != nil {
                docPointer!.document_data.listOfPages[clickedRow].pageName = result!
                _ = pagePickerList.reloadRow(clickedRow)
            }
        }
    }
    // delete page
    @objc func handleMenuDeletePage(_ sender:AnyObject?) {
        let clickedRow = pagePickerList.clickedRow
        if clickedRow >= 0 {
            let clickedPagePtr = docPointer!.document_data.listOfPages[clickedRow]
            // getting confirmation
            let result = showDeleteDialog(false, itemName: clickedPagePtr.pageName, activeLinkCount: clickedPagePtr.countNonDepreciatedLinks(), totalLinkCount: clickedPagePtr.countLinks)
            if result != nil {
                // we are going ahead...
                // need to pick the index to select afterwards
                let pageCount = docPointer!.document_data.listOfPages.count
                let afterIndex:Int
                if pageCount == 1 { afterIndex = -1 }
                else if clickedRow == (pageCount-1) { afterIndex = pageCount - 2 }
                else { afterIndex = clickedRow }
                // we might need to save the links and insert them in unsorted links
                if result! {
                    // saving the links
                    var siteHolder:[GB_SiteLink] = []
                    for currGroup in clickedPagePtr.groups {
                        siteHolder += currGroup.extractAllLinks()
                    }
                    // inserting them
                    docPointer!.document_data.appendLinkArray(siteHolder)
                }
                // deleting
                docPointer!.document_data.listOfPages.remove(at: clickedRow)
                // reloading and selecting...
                _ = pagePickerList!.reloadAndSelect(afterIndex, true)
                // and, if need be, reloading the unsorted links table...
                if result! {
                    currentGroupLinksTable!.reloadAfterAppend()
                }
            }
        }
    }
    //---------------------------------------------
    // group picker list : menu handler to add a new empty group
    @objc func handleMenuNewGroup(_ sender:AnyObject?) {
        let clickedRow = groupPickerList.clickedRow
        let result = showModalTextEntry("New Group", info: "Enter a non-empty name for the new group.",
                                        defaultText: "(new Group \(clickedRow))", nonEmpty: true)
        if result != nil {
            // insert at end
            if clickedRow < 0 {
                let newIndex = groupListDelegate!.itemCount
                _ = groupListDelegate!.appendNewGroup(result!)
                _ = groupPickerList.reloadAndSelect(Int(newIndex), true)
            }
                // insert at a specific spot
            else {
                _ = groupListDelegate!.insertNewGroup(result!, atIndex: UInt(clickedRow))
                _ = groupPickerList.reloadAndSelect(clickedRow, true)
            }
        }
    }
    // group picker list : menu handler to rename an existing group in the current page
    @objc func handleMenuRenameGroup(_ sender:AnyObject?) {
        let clickedRow = groupPickerList.clickedRow
        if clickedRow >= 0 {
            let oname = groupListDelegate!.groupAtIndex(UInt(clickedRow))!.groupName
            let result = showModalTextEntry("Rename Group",
                            info: "Enter a new, non-empty name for the group.",
                            defaultText: oname, nonEmpty: true)
            if result != nil {
                _ = groupListDelegate!.renameGroup(UInt(clickedRow), toName: result!)
                _ = groupPickerList.reloadRow(clickedRow)
            }
        }
    }
    // deleting a group
    @objc func handleMenuDeleteGroup(_ sender:AnyObject?) {
        let clickedRow = groupPickerList.clickedRow
        if clickedRow >= 0 {
            let groupPtr = groupListDelegate!.groupAtIndex(UInt(clickedRow))
            // getting confirmation
            let result = showDeleteDialog(true, itemName: groupPtr!.groupName,
                                          activeLinkCount: UInt(groupPtr!.countNonDepreciatedLinks), totalLinkCount: UInt(groupPtr!.count))
            if result != nil {
                // we are going ahead...
                // need to pick the index to select afterwards
                let groupCount = Int(groupListDelegate!.itemCount)
                let afterIndex:Int
                if groupCount == 1 { afterIndex = -1 }
                else if clickedRow == (groupCount-1) { afterIndex = groupCount - 2 }
                else { afterIndex = clickedRow }
                // we might need to take the links and insert them in unsorted links
                if result! {
                    docPointer!.document_data.appendLinkArray(groupPtr!.extractAllLinks())
                }
                // deleting
                _ = groupListDelegate!.deleteGroup(UInt(clickedRow))
                // reloading and selecting...
                _ = groupPickerList!.reloadAndSelect(afterIndex, true)
                // and, if need be, reloading the unsorted links table...
                if result! {
                    currentGroupLinksTable!.reloadAfterAppend()
                }
            }
        }
    }
    //--------------------------------------------
    // unsorted links list: add a new site
    @objc func handleMenuUnsortedAddSite(_ sender:AnyObject?) {
        let clickedRow = unsortedLinksTable.clickedRow
        let result = showModalNewLinkDialog(linkEntryAccessoryView!)
        if result != nil {
            // insert at end
            if clickedRow < 0 {
                let newIndex = UInt(unsortedLinksTable!.numberOfRows)
                docPointer!.document_data.appendLink(result!)
                _ = unsortedLinksTable!.reloadAndSetIndex(newIndex)
            }
                // insert at a specific spot
            else {
                _ = docPointer!.document_data.insertLink(result!, atIndex: clickedRow )
                _ = unsortedLinksTable!.reloadAndSetIndex(UInt(clickedRow))
            }
        }
    }
    
    // unsorted links list: delete a site
    @objc func handleMenuUnsortedDeleteSite(_ sender:AnyObject?) {
        let clickedRow = unsortedLinksTable.clickedRow
        if (clickedRow<0) { return }
        // deleting...
        _ = unsortedLinksTable!.deleteRowInTable(UInt(clickedRow))
    }
    @objc func handleMenuUnsortedDeleteMultiple(_ sender:AnyObject?) {
        _ = unsortedLinksTable!.deleteSelectedRows()
    }
    
    // unsorted links list: open site in browser (using the first url) {
    @objc func handleMenuUnsortedOpenSite(_ sender:AnyObject?) {
        _ = unsortedLinksTable.launchClickedRowInBrowser()
    }
    
    // unsorted links list: start checking all of the links
    @objc func handleMenuUnsortedCheckLinks(_ sender:AnyObject?) {
        _ = appPtr.groupChecker.setUnsortedToCheck(collection: docPointer!.document_data)
        startProgress(message: "Checking unsorted links...")
        _ = appPtr.groupChecker.startChecks()
    }
    
    private var usort_active = false
    // unsorted links list: remove duplicates and order (sort)
    @objc func handleMenuUnsortedFilerAndOrder(_ sender:AnyObject?) {
        // before we start, disable the unsorted links
        usort_active = true
        unsortedLinksTable.isEnabled = false
        unsortedLinksTable.alphaValue = 0.7
        startProgress(message: "Filtering and Ordering unsorted Links..." )
        // launch the filer and order process
        DispatchQueue.global(qos: .userInitiated).async {
            self.docPointer!.document_data.filterAndOrderUnsortedLinks()
            DispatchQueue.main.async {
                self.unsortedLinksTable.alphaValue = 1.0
                self.unsortedLinksTable.isEnabled = true
                self.usort_active = false
                self.stopProgress(message:"Unsorted Links have been Filtered and Ordered." )
                _ = self.unsortedLinksTable.reloadAndSetIndex(0)
            }
        }
        
        
    }
    
    // current group links list: open site in browser (using the first url) {
    @objc func handleMenuCurrentGroupOpenSite(_ sender:AnyObject?) {
        _ = currentGroupLinksTable.launchClickedRowInBrowser()
    }
    
    @objc func handleMenuCurrentGroupCheckLinks(_ sender:AnyObject?) {
        let currGroup = groupLinksDelegate!.currentGroupLink!
        _ = appPtr.groupChecker.setGroupToCheck(group: currGroup,source: docPointer!.document_data)
        startProgress(message: "Checking links in \(currGroup.groupName)")
        _ = appPtr.groupChecker.startChecks()
    }
    
    //--------------------------------------------
    // current group links list: add a new site
    @objc func handleMenuCurrGroupAddSite(_ sender:AnyObject?) {
        let clickedRow = currentGroupLinksTable.clickedRow
        let result = showModalNewLinkDialog(linkEntryAccessoryView!)
        if result != nil {
            // insert at end
            if clickedRow < 0 {
                let newIndex = UInt(currentGroupLinksTable!.numberOfRows)
                _ = groupLinksDelegate!.appendToCurrentGroupLink(result!)
                _ = currentGroupLinksTable!.reloadAndSetIndex(newIndex)
            }
                // insert at a specific spot
            else {
                _ = groupLinksDelegate!.insertInCurrentGroupLink(result!, at: UInt(clickedRow))
                _ = currentGroupLinksTable!.reloadAndSetIndex(UInt(clickedRow))
            }
        }
    }
    
    // current group links list: delete a site
    @objc func handleMenuCurrGroupDeleteSite(_ sender:AnyObject?) {
        let clickedRow = currentGroupLinksTable.clickedRow
        if (clickedRow<0) { return }
        // deleting...
        _ = currentGroupLinksTable!.deleteRowInTable(UInt(clickedRow))
    }
    @objc func handleMenuGroupLinksDeleteMultiple(_ sender:AnyObject?) {
        _ = currentGroupLinksTable.deleteSelectedRows()
    }
    //--------------------------------------------
    // validator
    override func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        // page picker list validation
        if menuItem === pagePickerPopupMenu!.item(withTitle: renamePageTag) {
            let clickedRow = pagePickerList.clickedRow
            return (clickedRow >= 0)
        }
        if menuItem === pagePickerPopupMenu!.item(withTitle: deletePageTag) {
            let clickedRow = pagePickerList.clickedRow
            return (clickedRow >= 0)
        }
        // group picker list validation
        if menuItem === groupPickerPopupMenu!.item(withTitle: newGroupTag) {
            return groupListDelegate!.hasCurrentPage
        }
        if menuItem === groupPickerPopupMenu!.item(withTitle: renameGroupTag) {
            let clickedRow = groupPickerList.clickedRow
            return (clickedRow >= 0)
        }
        if menuItem === groupPickerPopupMenu!.item(withTitle: deleteGroupTag) {
            let clickedRow = groupPickerList.clickedRow
            return (clickedRow >= 0)
        }
        // unsorted links validation
        if menuItem === unsortedLinksPopupMenu!.item(withTitle: deleteLinkTitle) {
            let clickedRow = unsortedLinksTable!.clickedRow
            return (clickedRow >= 0)
        }
        if menuItem === unsortedLinksPopupMenu!.item(withTitle: deleteMLinksTitle) {
            return unsortedLinksTable.selectedIndexes.count > 0
        }
        if menuItem === unsortedLinksPopupMenu!.item(withTitle: checkLinksTitle) {
            if docPointer == nil { return false }
            let unscount = docPointer!.document_data.unsortedLinkCount
            return (appPtr.groupChecker.notActive && (unscount > 0))
        }
        if menuItem === unsortedLinksPopupMenu!.item(withTitle: filterOrderTitle) {
            if docPointer == nil { return false }
            if usort_active { return false }
            let unscount = docPointer!.document_data.unsortedLinkCount
            return (appPtr.groupChecker.notActive && (unscount > 1))
        }
        if menuItem === unsortedLinksPopupMenu!.item(withTitle: openLinkTitle) {
            if docPointer == nil { return false }
            let clickedRow = unsortedLinksTable!.clickedRow
            return (clickedRow >= 0)
        }
        // current group validation
        if menuItem === currentGroupLinksPopupMenu!.item(withTitle: deleteLinkTitle) {
            let clickedRow = currentGroupLinksTable!.clickedRow
            return (clickedRow >= 0)
        }
        if menuItem === currentGroupLinksPopupMenu!.item(withTitle: deleteMLinksTitle) {
            return currentGroupLinksTable.selectedIndexes.count > 0
        }
        if menuItem === currentGroupLinksPopupMenu!.item(withTitle: checkLinksTitle) {
            guard let glink = groupLinksDelegate?.currentGroupLink else { return false }
            return (appPtr.groupChecker.notActive && (glink.count > 0))
        }
        if menuItem === currentGroupLinksPopupMenu!.item(withTitle: openLinkTitle) {
            if docPointer == nil { return false }
            let clickedRow = currentGroupLinksTable!.clickedRow
            return (clickedRow >= 0)
        }
        if menuItem === currentGroupLinksPopupMenu!.item(withTitle: addLinkTitle) {
            if docPointer == nil { return false }
            return groupLinksDelegate?.currentGroupLink != nil
        }
        return true
    }
    
    
    
    // +++ [ Notification Handlers ] ++++++++++++++++++++++++++++++
    
    @objc func handleLinkClickedNotification(_ notification: Notification) {
        guard let nsource = notification.object as? GB_LinkTableView else { return }
        if (nsource !== self.currentGroupLinksTable) && (nsource !== self.unsortedLinksTable) { return }
        if (siteEditorPointer != nil) {
            let notifyData = notification.userInfo as! [String:AnyObject]
            _ = siteEditorPointer!.changeSiteUsingData(notifyData)
            let fromUnsorted = notifyData[unsortedKey] as! Bool
            if (fromUnsorted) { unsortedLinksTable!.reloadAfterAppend() }
            else { currentGroupLinksTable!.reloadAfterAppend() }
        }
    }
    
    @objc func handleGroupChangeNotification(_ notification: Notification) {
        let changeIndexes = notification.userInfo as! [String:Int]
        let toIndex = changeIndexes["to row"]
        _ = groupLinksDelegate!.changeGroup(UInt(toIndex!))
    }
    
    @objc func handlePageChangeNotification(_ notification: Notification) {
        let changeIndexes = notification.userInfo as! [String:Int]
        let toIndex = changeIndexes["to row"]!
        _ = groupListDelegate!.changePage(UInt(toIndex))
        _ = groupLinksDelegate!.changePage(UInt(toIndex))
        let pagelist = docPointer!.document_data.listOfPages
        if (pagelist.count == 0) { return }
        let currentPage = pagelist[toIndex]
        leaveOffNavCheckBox.state = (currentPage.notInNav) ? .on : .off
    }
    
    @IBAction func leavePageOffNavCheckboxChange(_ sender: Any) {
        guard let pageIndex = pagePickerList.selectedUIndex else { return }
        let currentPage = docPointer!.document_data.listOfPages[pageIndex]
        currentPage.notInNav = (leaveOffNavCheckBox.state == .on)
    }
    
    
    @objc func handleLinkDataChangedNotification(_ notification:Notification) {
        // checking the source
        guard let source = notification.object as? LinkEditViewController else { return }
        if (siteEditorPointer !== source) { return }
        // unpacking data
        let notifData = notification.userInfo as! [String:AnyObject]
        let fromUnsorted = notifData[unsortedKey] as! Bool
        let sourceIndex = notifData[indexKey] as! Int
        // quick sanity check
        assert(sourceIndex>=0)
        // ordering a table update
        DispatchQueue.main.async {
            if fromUnsorted { _ = self.unsortedLinksTable!.reloadRow(UInt(sourceIndex)) }
            else { _ = self.currentGroupLinksTable!.reloadRow(UInt(sourceIndex)) }
        }
    }
    
    // +++ [ Checking URLs ] ++++++++++++++++++++++++
    
    // used to update a given link in the displayed links table
    func checkUpdateLink(_ objectChanged:GB_SiteLink) -> Bool {
        // looking in unsorted links
        let unsortedIndex = docPointer!.document_data.indexForLink(objectChanged)
        if unsortedIndex >= 0 {
            // let checko = docPointer!.document_data.linkAtIndex(unsortedIndex).getLinkLabelAtIndex(0)
            DispatchQueue.main.async {
                let qres = self.unsortedLinksTable!.reloadRow(UInt(unsortedIndex))
                if self.unsortedLinksTable!.rowIsDisplayedLink(unsortedIndex) {
                    self.siteEditorPointer?.reloadCheckDone()
                }
            }
            return true
        }
        // looking in the displayed group
        let currentIndex = groupLinksDelegate!.getIndexForLink(objectChanged)
        if currentIndex >= 0 {
            DispatchQueue.main.async {
                _ = self.currentGroupLinksTable!.reloadRow(UInt(currentIndex))
                if self.currentGroupLinksTable!.rowIsDisplayedLink(currentIndex) {
                    self.siteEditorPointer?.reloadCheckDone()
                }
            }
            return true
        }
        // the link is not in unsorted or displayed group (not an error)
        return false
    }
    
    @objc func handleSingleLinkCheckNotification(_ notification:Notification) {
        // extracting the link data, we exit if there is an error or no changes happened
        let linkData = notification.userInfo as! [String:Any]
        // checking that the message is for this collection
        guard let collection = linkData[SourceCollectionKey] as? GB_LinkCollection else { return }
        if (collection !== docPointer?.document_data) { return }
        // ignore if no change in the link status
        guard let changeCount = linkData[ChangeCountKey] as? Int else { return }
        if changeCount < 1 { return }
        // we try and locate the link object in the currently displayed groups
        guard let objectChanged = linkData[LinkObjectKey] as? GB_SiteLink else { return }
        _ = checkUpdateLink(objectChanged)
    }
    
    @objc func handleALinkCheckNotification(_ notification:Notification) {
        // extracting the link data, we exit if there is an error or no changes happened
        let linkData = notification.userInfo as! [String:Any]
        // checking that the message is for this collection
        guard let collection = linkData[SourceCollectionKey] as? GB_LinkCollection else { return }
        if (collection !== docPointer?.document_data) { return }
        // ignore if no change in the link status
        guard let changeCount = linkData[ChangeCountKey] as? Int else { return }
        if changeCount < 1 { return }
        // we try and locate the link object in the currently displayed groups
        guard let objectChanged = linkData[LinkObjectKey] as? GB_SiteLink else { return }
        _ = checkUpdateLink(objectChanged)
    }
    
    @objc func handleLinkListCheckingDone(_ notification:Notification) {
        let linkData = notification.userInfo as! [String:Any]
        // checking that the message is for this collection
        guard let collection = linkData[SourceCollectionKey] as? GB_LinkCollection else { return }
        if (collection !== docPointer?.document_data) { return }
        // displaying the completed gui changes
        guard let gname = linkData["listName"] as? String else { return }
        DispatchQueue.main.async {
            self.stopProgress(message: "Link check done for \(gname)")
        }
    }
    
    // +++ [ Menu handlers ] ++++++++++++++++++++++++
    
    // first responder to the menu item
    @IBAction func ImportLinksFromHTML(_ sender:AnyObject) {
        let importPath = openFileDialog("Pick an HTML file to get links from.", filetypes: ["htm","html"])
        if importPath != nil {
            startProgress(message: "Loading File: " + importPath!)
            let loadData = loadHTMLFileToString(importPath!)
            // if loading the HTML file fails, we display an error popup
            if !(loadData.0) {
                stopProgress(message: "Loading file failed!")
                let infoMsg = "Loading the file: \(loadData) failed,\n" + "Error : \(loadData.1)"
                showModalMessage("Loading File Failed", info:infoMsg , style: .warning, btnLabel: "Sorry")
            }
                // otherwise, we try to parse the data
            else {
                // parsing for links
                messageDisplay.stringValue = "File loaded. Now extracting links..."
                let resLinks = extractLinksFromHTML(loadData.1)
                // displaying the results
                let linkCountStr:String
                if resLinks.count == 0 { linkCountStr = "No Links" }
                else if resLinks.count == 1 { linkCountStr = "One Link" }
                else { linkCountStr = "\(resLinks.count) Links" }
                let infoMsg = "\(linkCountStr) have been extracted."
                stopProgress(message: infoMsg)
                showModalMessage("Link extraction done", info: infoMsg, style: .informational , btnLabel: "Ok")
                // inserting the results in the collection
                if resLinks.count > 0 {
                    startProgress(message: "Adding the new Links to Unsorted Links...")
                    docPointer!.document_data.appendLinkArray(resLinks)
                    unsortedLinksTable!.reloadAfterAppend()
                    stopProgress(message: "New links have been added to Unsorted Links.")
                }
            }
        }
    }
    
    @IBAction func ExportLinksUsingTemplate(_ sender:AnyObject) {
        let outputsheet = OutputView();
        outputsheet.outputPtr = docPointer!.document_data
        presentViewControllerAsSheet(outputsheet)
    }
    
    // +++ [ additional actions ] ++++++++++++++++++++++
    
    override func controlTextDidChange(_ notification: Notification) {
        guard let notifyObj = notification.object as? NSTextField else { return }
        if notifyObj === collectionNameEdit {
            let nameEdit = notification.object as! NSTextField
            if (docPointer != nil) {
                docPointer!.document_data.collectionName = nameEdit.stringValue
            }
        }
    }    
    
    // +++ [ Boilerplate setup code ] ++++++++++++++++++
    fileprivate var linkEntryAccessoryView:GB_LinkEntryView? = nil;
    
    // the standard view did load delegate
    override func viewDidLoad() {
        super.viewDidLoad()
        appPtr = (NSApplication.shared.delegate as! AppDelegate)
        // Do any additional setup after loading the view.
        setupTablesAndLists()
        linkEntryAccessoryView = loadLinkEntryAccesory()
        collectionNameEdit.delegate = self
        setupContextMenus()
        progressWidget.isIndeterminate = true
        progressWidget.isHidden = true
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        if (docPointer == nil) {
            docPointer = GetDocument()
            setupNotificationObservers()
            collectionIntoDelegates(docPointer!.document_data)
            _ = pagePickerList.loadPickZero(true)
            if siteEditorPointer != nil {
                _ = siteEditorPointer!.setLinkCollection(docPointer!.document_data)
            }
        }
        pagePickerList!.sizeColumn()
        groupPickerList!.sizeColumn()
    }
    
    // the link entry dialog box uses a nib based accessory view which sometimes fails to load...
    func loadLinkEntryAccesory() -> GB_LinkEntryView {
        // let accessoryViewID = String(describing: GB_LinkEntryView.self)
        let accessoryViewID = "GB_LinkEntryView"
        var objects:NSArray?
        var viewResult:GB_LinkEntryView? = nil;
        while (viewResult == nil) {
            Bundle.main.loadNibNamed(NSNib.Name(rawValue: accessoryViewID), owner: nil,topLevelObjects:&objects )
            viewResult = objects?.object(at: 0) as? GB_LinkEntryView
            print("loadLinkEntryAccesory")
        }
        return viewResult!
    }
    
    // ludicrously, this is apparently the best way to get a pointer to an embedded subview
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == siteEditorID {
            siteEditorPointer = segue.destinationController as? LinkEditViewController
            if (siteEditorPointer != nil) {
                if docPointer != nil {
                    _ = siteEditorPointer?.setLinkCollection(docPointer!.document_data)
                }
                NAdd(sel: #selector(handleLinkDataChangedNotification), name: LinkDataChangedNotification, source: siteEditorPointer!)
            }
        }
    }
    
    // to make starting and stopping the progress indicator one liners
    private func startProgress(message:String) {
        progressWidget.isHidden = false
        messageDisplay.stringValue = message
        progressWidget.startAnimation(nil)
    }
    
    private func stopProgress(message:String) {
        progressWidget.stopAnimation(nil)
        progressWidget.isHidden = true
        messageDisplay.stringValue = message
    }

}

