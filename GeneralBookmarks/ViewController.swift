//
//  ViewController.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-08-11.
//  Copyright © 2016-2018 dfaulks. All rights reserved.
//

import Cocoa

class ViewController: NSViewController,NSTextFieldDelegate {

    // GUI elements
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
    
    fileprivate func setupNotificationObservers() {
        NotificationCenter.default.addObserver(self,selector: #selector(handleLinkClickedNotification),
                                                         name: LinkClickedNotification,object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleLinkDataChangedNotification),
                                                         name: LinkDataChangedNotification, object: nil)
        NotificationCenter.default.addObserver(self,selector: #selector(handleGroupChangeNotification),
                                                         name: GroupChangedNotification,object: nil)
        NotificationCenter.default.addObserver(self,selector: #selector(handlePageChangeNotification),
                                                         name: PageChangedNotification,object: nil)
        
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
    fileprivate let openLinkTitle = "Open Link in a browser"
    fileprivate let checkLinksTitle = "Start checking Links"
    
    
    // the tables and lists have right/ctrl click popup menus
    fileprivate func setupContextMenus() {
        // page picker popup menu
        pagePickerPopupMenu = NSMenu()
        
        let addPageMenuItem = NSMenuItem()
        addPageMenuItem.title = newPageTag
        addPageMenuItem.target = self
        addPageMenuItem.action = #selector(handleMenuNewPage)
        pagePickerPopupMenu!.addItem(addPageMenuItem)
        
        let renamePageMenuItem = NSMenuItem()
        renamePageMenuItem.title = renamePageTag
        renamePageMenuItem.target = self
        renamePageMenuItem.action = #selector(handleMenuRenamePage)
        pagePickerPopupMenu!.addItem(renamePageMenuItem)
        
        let deletePageMenuItem = NSMenuItem()
        deletePageMenuItem.title = deletePageTag
        deletePageMenuItem.target = self
        deletePageMenuItem.action = #selector(handleMenuDeletePage)
        pagePickerPopupMenu!.addItem(deletePageMenuItem)
        
        pagePickerList.tableMenu = pagePickerPopupMenu
        
        // group picker popup menu
        groupPickerPopupMenu = NSMenu()
        
        let addGroupMenuItem = NSMenuItem()
        addGroupMenuItem.title = newGroupTag
        addGroupMenuItem.target = self
        addGroupMenuItem.action = #selector(handleMenuNewGroup)
        groupPickerPopupMenu!.addItem(addGroupMenuItem)
        
        let renameGroupMenuItem = NSMenuItem()
        renameGroupMenuItem.title = renameGroupTag
        renameGroupMenuItem.target = self
        renameGroupMenuItem.action = #selector(handleMenuRenameGroup)
        groupPickerPopupMenu!.addItem(renameGroupMenuItem)
        
        let deleteGroupMenuItem = NSMenuItem()
        deleteGroupMenuItem.title = deleteGroupTag
        deleteGroupMenuItem.target = self
        deleteGroupMenuItem.action = #selector(handleMenuDeleteGroup)
        groupPickerPopupMenu!.addItem(deleteGroupMenuItem)
        
        groupPickerList.tableMenu = groupPickerPopupMenu
        
        // unsorted links popup menu
        unsortedLinksPopupMenu = NSMenu()
        
        let addSiteToUnsortedMenuItem = NSMenuItem()
        addSiteToUnsortedMenuItem.title = addLinkTitle
        addSiteToUnsortedMenuItem.target = self
        addSiteToUnsortedMenuItem.action = #selector(handleMenuUnsortedAddSite)
        unsortedLinksPopupMenu!.addItem(addSiteToUnsortedMenuItem)
        
        let deleteSiteFromUnsortedMenuItem = NSMenuItem()
        deleteSiteFromUnsortedMenuItem.title = deleteLinkTitle
        deleteSiteFromUnsortedMenuItem.target = self
        deleteSiteFromUnsortedMenuItem.action = #selector(handleMenuUnsortedDeleteSite)
        unsortedLinksPopupMenu!.addItem(deleteSiteFromUnsortedMenuItem)
        
        let openSiteinBrowserMenuItem = NSMenuItem()
        openSiteinBrowserMenuItem.title = openLinkTitle
        openSiteinBrowserMenuItem.target = self
        openSiteinBrowserMenuItem.action = #selector(handleMenuUnsortedOpenSite)
        unsortedLinksPopupMenu!.addItem(openSiteinBrowserMenuItem)
        
        let checkUnsortedLinksMenuItem = NSMenuItem()
        checkUnsortedLinksMenuItem.title = checkLinksTitle
        checkUnsortedLinksMenuItem.target = self
        checkUnsortedLinksMenuItem.action = #selector(handleMenuUnsortedCheckLinks)
        unsortedLinksPopupMenu!.addItem(checkUnsortedLinksMenuItem)
        
        unsortedLinksTable.menu = unsortedLinksPopupMenu
        
        // current group links popup menu
        currentGroupLinksPopupMenu = NSMenu()
        
        let addSiteToCurrentGroupMenuItem = NSMenuItem()
        addSiteToCurrentGroupMenuItem.title = addLinkTitle
        addSiteToCurrentGroupMenuItem.target = self
        addSiteToCurrentGroupMenuItem.action = #selector(handleMenuCurrGroupAddSite)
        currentGroupLinksPopupMenu!.addItem(addSiteToCurrentGroupMenuItem)
        
        let deleteSiteFromCurrentGroupMenuItem = NSMenuItem()
        deleteSiteFromCurrentGroupMenuItem .title = deleteLinkTitle
        deleteSiteFromCurrentGroupMenuItem .target = self
        deleteSiteFromCurrentGroupMenuItem .action = #selector(handleMenuCurrGroupDeleteSite)
        currentGroupLinksPopupMenu!.addItem(deleteSiteFromCurrentGroupMenuItem )
        
        let openSiteinBrowserMenuItem2 = NSMenuItem()
        openSiteinBrowserMenuItem2.title = openLinkTitle
        openSiteinBrowserMenuItem2.target = self
        openSiteinBrowserMenuItem2.action = #selector(handleMenuCurrentGroupOpenSite)
        currentGroupLinksPopupMenu!.addItem(openSiteinBrowserMenuItem2)
        
        let checkCurrentGroupMenuItem = NSMenuItem()
        checkCurrentGroupMenuItem.title = checkLinksTitle
        checkCurrentGroupMenuItem.target = self
        checkCurrentGroupMenuItem.action = #selector(handleMenuCurrentGroupCheckLinks)
        currentGroupLinksPopupMenu!.addItem(checkCurrentGroupMenuItem)
        
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
            let result = showModalTextEntry("Rename Page", info: "Enter a new, non-empty name for the page.",
                                            defaultText: "(new Page \(clickedRow))", nonEmpty: true)
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
            let result = showDeleteDialog(false, itemName: clickedPagePtr.pageName,
                                          activeLinkCount: clickedPagePtr.countNonDepreciatedLinks(), totalLinkCount: clickedPagePtr.countLinks)
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
            let result = showModalTextEntry("Rename Group", info: "Enter a new, non-empty name for the group.",
                                            defaultText: "(new Group \(clickedRow))", nonEmpty: true)
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
        unsortedLinksTable!.deleteRowInTable(UInt(clickedRow))
    }
    
    // unsorted links list: open site in browser (using the first url) {
    @objc func handleMenuUnsortedOpenSite(_ sender:AnyObject?) {
        unsortedLinksTable.launchClickedRowInBrowser()
    }
    
    // unsorted links list: starte checking all of the links
    @objc func handleMenuUnsortedCheckLinks(_ sender:AnyObject?) {
        _ = appPtr.groupChecker.setUnsortedToCheck(collection: docPointer!.document_data)
        messageDisplay.stringValue = "Checking unsorted links"
        _ = appPtr.groupChecker.startChecks()
    }
    
    // current group links list: open site in browser (using the first url) {
    @objc func handleMenuCurrentGroupOpenSite(_ sender:AnyObject?) {
        _ = currentGroupLinksTable.launchClickedRowInBrowser()
    }
    
    @objc func handleMenuCurrentGroupCheckLinks(_ sender:AnyObject?) {
        let currGroup = groupLinksDelegate!.currentGroupLink!
        _ = appPtr.groupChecker.setGroupToCheck(group: currGroup)
        messageDisplay.stringValue = "Checking links in \(currGroup.groupName)"
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
        if menuItem == unsortedLinksPopupMenu!.item(withTitle: deleteLinkTitle) {
            let clickedRow = unsortedLinksTable!.clickedRow
            return (clickedRow >= 0)
        }
        if menuItem == unsortedLinksPopupMenu!.item(withTitle: checkLinksTitle) {
            if docPointer == nil { return false }
            let unscount = docPointer!.document_data.unsortedLinkCount
            return (appPtr.groupChecker.notActive && (unscount > 0))
        }
        // current group validation
        if menuItem == currentGroupLinksPopupMenu!.item(withTitle: deleteLinkTitle) {
            let clickedRow = currentGroupLinksTable!.clickedRow
            return (clickedRow >= 0)
        }
        if menuItem == currentGroupLinksPopupMenu!.item(withTitle: checkLinksTitle) {
            guard let glink = groupLinksDelegate?.currentGroupLink else { return false }
            return (appPtr.groupChecker.notActive && (glink.count > 0))
        }
        return true
    }
    
    
    
    // +++ [ Notification Handlers ] ++++++++++++++++++++++++++++++
    
    @objc func handleLinkClickedNotification(_ notification: Notification) {
        if (siteEditorPointer != nil) {
            let notifyData = notification.userInfo as! [String:AnyObject]
            siteEditorPointer!.changeSiteUsingData(notifyData)
            let fromUnsorted = notifyData[unsortedKey] as! Bool
            if (fromUnsorted) { unsortedLinksTable!.reloadAfterAppend() }
            else { currentGroupLinksTable!.reloadAfterAppend() }
        }
    }
    
    @objc func handleGroupChangeNotification(_ notification: Notification) {
        let changeIndexes = notification.userInfo as! [String:Int]
        let toIndex = changeIndexes["to row"]
        groupLinksDelegate!.changeGroup(UInt(toIndex!))
    }
    
    @objc func handlePageChangeNotification(_ notification: Notification) {
        let changeIndexes = notification.userInfo as! [String:Int]
        let toIndex = changeIndexes["to row"]!
        groupListDelegate!.changePage(UInt(toIndex))
        groupLinksDelegate!.changePage(UInt(toIndex))
        let currentPage = docPointer!.document_data.listOfPages[toIndex]
        leaveOffNavCheckBox.state = (currentPage.notInNav) ? .on : .off
    }
    
    @IBAction func leavePageOffNavCheckboxChange(_ sender: Any) {
        guard let pageIndex = pagePickerList.selectedUIndex else { return }
        let currentPage = docPointer!.document_data.listOfPages[pageIndex]
        currentPage.notInNav = (leaveOffNavCheckBox.state == .on)
    }
    
    
    @objc func handleLinkDataChangedNotification(_ notification:Notification) {
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
            }
            return true
        }
        // looking in the displayed group
        let currentIndex = groupLinksDelegate!.getIndexForLink(objectChanged)
        if currentIndex >= 0 {
            DispatchQueue.main.async {
                _ = self.currentGroupLinksTable!.reloadRow(UInt(currentIndex))
            }
            return true
        }
        // the link is not in unsorted or displayed group (not an error)
        return false
    }
    
    @objc func handleSingleLinkCheckNotification(_ notification:Notification) {
        // extracting the link data, we exit if there is an error or no changes happened
        let linkData = notification.userInfo as! [String:Any]
        guard let changeCount = linkData[ChangeCountKey] as? Int else { return }
        if changeCount < 1 { return }
        guard let objectChanged = linkData[LinkObjectKey] as? GB_SiteLink else { return }
        // we try and locate the link object in the currently displayed groups
        _ = checkUpdateLink(objectChanged)
    }
    
    @objc func handleALinkCheckNotification(_ notification:Notification) {
        // extracting the link data, we exit if there is an error or no changes happened
        let linkData = notification.userInfo as! [String:Any]
        guard let changeCount = linkData[ChangeCountKey] as? Int else { return }
        if changeCount < 1 { return }
        guard let objectChanged = linkData[LinkObjectKey] as? GB_SiteLink else { return }
        // we try and locate the link object in the currently displayed groups
        _ = checkUpdateLink(objectChanged)
    }
    
    @objc func handleLinkListCheckingDone(_ notification:Notification) {
        let linkData = notification.userInfo as! [String:Any]
        guard let gname = linkData["listName"] as? String else { return }
        DispatchQueue.main.async {
            self.messageDisplay.stringValue = "Link check done for \(gname)"
        }
    }
    
    // +++ [ Menu handlers ] ++++++++++++++++++++++++
    
    // first responder to the menu item
    @IBAction func ImportLinksFromHTML(_ sender:AnyObject) {
        let importPath = openFileDialog("Pick an HTML file to get links from.", filetypes: ["htm","html"])
        if importPath != nil {
            messageDisplay.stringValue = "Loading File: " + importPath!
            let loadData = loadHTMLFileToString(importPath!)
            // if loading the HTML file fails, we display an error popup
            if !(loadData.0) {
                messageDisplay.stringValue = "Loading file failed!"
                let infoMsg = "Loading the file: \(loadData) failed,\n" + "Error : \(loadData.1)"
                showModalMessage("Loading File Failed", info:infoMsg , style: .warning, btnLabel: "Sorry")
            }
                // otherwise, we try to parse the data
            else {
                // parsing for links
                messageDisplay.stringValue = "File loaded. Now extracting links..."
                print("ImportLinkFromHTML A")
                let resLinks = extractLinksFromHTML(loadData.1)
                // displaying the results
                messageDisplay.stringValue += " Done."
                let linkCountStr:String
                if resLinks.count == 0 { linkCountStr = "No Links" }
                else if resLinks.count == 1 { linkCountStr = "One Link" }
                else { linkCountStr = "\(resLinks.count) Links" }
                let infoMsg = "\(linkCountStr) have been extracted."
                showModalMessage("Link extraction done", info: infoMsg, style: .informational , btnLabel: "Ok")
                // inserting the results in the collection
                if resLinks.count > 0 {
                    messageDisplay.stringValue = "Adding the new Links to Unsorted Links..."
                    docPointer!.document_data.appendLinkArray(resLinks)
                    unsortedLinksTable!.reloadAfterAppend()
                    messageDisplay.stringValue += " Done."
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
        appPtr = NSApplication.shared.delegate as! AppDelegate
        // Do any additional setup after loading the view.
        setupTablesAndLists()
        linkEntryAccessoryView = loadLinkEntryAccesory()
        collectionNameEdit.delegate = self
        setupContextMenus()
    }
    override func viewWillAppear() {
        super.viewWillAppear()
        if (docPointer == nil) {
            docPointer = GetDocument()
            setupNotificationObservers()
            collectionIntoDelegates(docPointer!.document_data)
            pagePickerList.loadPickZero(true)
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
            NSLog("loadLinkEntryAccesory")
        }
        return viewResult!
    }
    
    // ludicrously, this is apparently the best way to get a pointer to an embedded subview
    override func prepare(for segue: NSStoryboardSegue, sender: Any?) {
        if segue.identifier == siteEditorID {
            siteEditorPointer = segue.destinationController as? LinkEditViewController
        }
    }

}

