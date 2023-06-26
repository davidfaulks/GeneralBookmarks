//
//  linkdelegates.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2020-05-28. (split from delegates.swift)
//  Copyright © 2020 dfaulks. All rights reserved.
//  delegates and related objects for the link tables

import Foundation
import Cocoa
//=================================================================================
/* When a link click notification is sent, some info needs to be sent with it, to be consistent
 I use a function to create it. Also, string keys are declared as constants here */
let unsortedKey = "from unsorted"
let indexKey = "source index"
let linkKey = "link pointer"
let groupNameKey = "group name"
let pageNameKey = "page name"

func makeLinkDisplayNotification(_ sourceIndex:Int, _ fromUnsorted:Bool, _ linkPointer:GB_SiteLink?, groupName:String?, pageName:String?) -> [String : AnyObject] {
    if sourceIndex < 0 {
        return [unsortedKey:fromUnsorted as AnyObject, indexKey:-1 as AnyObject]
    }
    else if fromUnsorted {
        return [unsortedKey:true as AnyObject, indexKey:sourceIndex as AnyObject, linkKey:linkPointer!]
    }
    else {
        return [unsortedKey:false as AnyObject, indexKey:sourceIndex as AnyObject, linkKey:linkPointer!, groupNameKey:groupName! as AnyObject, pageNameKey:pageName! as AnyObject]
    }
}

let LinkClickedNotification = NSNotification.Name(rawValue: "LinkClickedNotification")
//*********************************************************************************
let MaroonCol = NSColor.init(red: 0.784, green: 0.220, blue: 0.353, alpha: 1.0)
// pasteboard type, needed for row-reordering and drag and drop
let GBSiteLinkPBoardType = NSPasteboard.PasteboardType(rawValue:"GBSiteLinkPBoardType")
/*
 We need a pair of delegate/datasource classes for the two link-data-showing NSTableViews,
 but they share a great deal of functionality, so we implement a common base class first
 */
class GB_LinkTableDelegate: NSObject, NSTableViewDelegate, NSTableViewDataSource,GB_LinkTableCustomDelegate {
    // +++ [ Misc Core Stuff ] ++++++++++++++++++++++++++++++++++++++++++++++++
    fileprivate var mutex = pthread_mutex_t()
    override init() {
        super.init()
        pthread_mutex_init(&mutex, nil)
    }
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    // property that points to the table this object is a delegate of, must be set
    var attachedTable:GB_LinkTableView? = nil
    
    // +++ [ Basic Delegate/Datasource Methods, Helpers ] ++++++++++++++++++++++++
    // data source properties
    fileprivate var collectionLink:GB_LinkCollection? = nil
    
    // (required delegate) number of rows, MUST BE OVERRIDDEN
    func numberOfRows(in tableView: NSTableView) -> Int { return 0 }
    
    // all I really need is text: cell based is simpler in this case
    func tableView(_ tableView: NSTableView, objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        // handling some nil cases
        if tableColumn == nil { return nil }
        guard let columnIndex = tableView.tableColumns.index(of: tableColumn!) else { return nil }
        // getting the link to display (unless we cannot)
        guard let linkItem = getLinkForRow(row) else { return nil  }
        pthread_mutex_lock(&mutex)
        // I will not check if the link item is empty
        
        // checks if the link to be shown is also supposed to be shown in the link editing panel
        let displayedLink = attachedTable!.rowIsDisplayedLink(row)
        // creating the cell
        let outputCell:NSTextFieldCell = NSTextFieldCell()
        
        // setting the value based on the column index
        // column 0 has a checkmark if the link is being displayed in the link editing panel
        if (columnIndex == 0) && displayedLink { outputCell.stringValue = "✔" }
        else if (columnIndex == 0) { outputCell.stringValue = " " }
            // column 1 is the link label
        else if columnIndex == 1 {
            // important links are in bold
            if linkItem.important {
                outputCell.font = NSFont.boldSystemFont(ofSize: NSFont.systemFontSize)
            }
            else {
                outputCell.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
            }
            // depreciated links are grey
            if linkItem.depreciated {
                outputCell.textColor = NSColor.gray
            }
            else {
                outputCell.textColor = NSColor.black
            }
            if linkItem.isEmpty { outputCell.stringValue = "⟨EMPTY LINK⟩" }
            else {
                let displayLabel = linkItem.getLinkLabelAtIndex(0)
                outputCell.stringValue = displayLabel
            }
        }
        // column 2 is the link status
        else if columnIndex == 2 {
            if linkItem.isEmpty { outputCell.stringValue = "??" }
            else if linkItem.checking {
                outputCell.textColor = MaroonCol
                outputCell.stringValue = "...Checking"
            }
            else {
                let mainStatus = linkItem.status
                outputCell.textColor = getColourForStatus(mainStatus)
                outputCell.stringValue = mainStatus.rawValue
                
            }
        }
        // column 3 is link count (currently not used)
        else if columnIndex == 3 {
            outputCell.stringValue = String(linkItem.linkCount)
        }
        // column 4 is the url (currently not used)
        else if columnIndex == 4 {
            if (linkItem.isEmpty) { outputCell.stringValue = "⟨NO URL⟩" }
            else { outputCell.stringValue = linkItem.getUrlAtIndex(0) }
        }
        pthread_mutex_unlock(&mutex)
        return outputCell
        
    }
    
    // +++ [ Methods for dragging and dropping ] +++++++++++++++++++++++++++++
    // helper stuff
    
    // (optional delegate) dragging started
    func tableView(_ tableView: NSTableView, writeRowsWith writeRowsWithIndexes: IndexSet, to toPasteboard: NSPasteboard) -> Bool {
        toPasteboard.declareTypes([GBSiteLinkPBoardType], owner:self)
        let data = NSKeyedArchiver.archivedData(withRootObject: writeRowsWithIndexes)
        toPasteboard.setData(data, forType:GBSiteLinkPBoardType)
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
        guard let rowData = pasteboard.data(forType: GBSiteLinkPBoardType) else { return nil }
        guard let dataIndexes = NSKeyedUnarchiver.unarchiveObject(with: rowData) as! IndexSet? else { return nil }
        // exit if no row data
        if dataIndexes.count == 0 { return nil }
        else { return dataIndexes }
    }
    
    /* When dropping from another table, we need to check it comes from the other table.
       so, the property below should be set to the other table when setting up.  */
    var otherTable:GB_LinkTableView? = nil
    
    // helper method to re-order source data links upon drop. MUST BE OVERRIDDEN
    fileprivate func reorderSourceLinks(_ fromIndexes:IndexSet, toIndex:Int) { return }
    
    // helper method to get the links when dragging from another table. MUST BE OVERRIDDEN
    fileprivate func getDraggedLinks(_ sourceIndexes:IndexSet, otherDelegate:GB_LinkTableDelegate) -> Array<GB_SiteLink>? {
        return nil
    }
    // the other side of getDraggedLinks, MUST BE OVERRIDDEN
    func linksForDragging(indexes:IndexSet) -> [GB_SiteLink]? {
        return nil;
    }
    
    // helper method to insert dragged links inside the data source. MUST BE OVERRIDDEN
    fileprivate func insertLinks(_ linksToInsert:Array<GB_SiteLink>,toRow:Int) { return }
    
    // helper method to find out if we can recieve extral drag and drop. SHOULD BE OVERRIDEN
    fileprivate func okayToDrop() -> Bool { return true }
    
    // (optional delegate) drop
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableView.DropOperation) -> Bool {
        // let fname = "tableView Accept Drop "
        // initial data which might be nil or bad
        guard let dragSource = info.draggingSource() as! NSTableView? else { return false }
        guard let sourceIndexes = getIndexesFromInfo(info) else { return false }
        if row < 0 { return false }
        // starting...
        pthread_mutex_lock(&mutex)
        if collectionLink == nil {
            pthread_mutex_unlock(&mutex)
            return false
        }
        // if the source is the same table, we have a drag and drop re-order
        if dragSource === tableView {
            // re-ordering the source
            reorderSourceLinks(sourceIndexes, toIndex: row)
            // moving the selection indexes to the newly inserted values
            let newSelected = makeNewSelectionAfterReorder(sourceIndexes, toRow: row)
            let newDisplLink = attachedTable!.calcDisplLinkIdxAfterReorder(sourceIndexes, newRow: newSelected.min()!)
            pthread_mutex_unlock(&mutex)
            attachedTable!.changeSelection(newSelected, newDisplayedLink: newDisplLink, reload:true)
            // done
            return true
        }
        // checking and casting, for dragging from another table of links
        guard let sourceTable = dragSource as? GB_LinkTableView else {
            pthread_mutex_unlock(&mutex)
            return false
        }
        let is_other_table = sourceTable === otherTable
        guard let sourceDelg = sourceTable.dataSource as? GB_LinkTableDelegate else {
            pthread_mutex_unlock(&mutex)
            return false
        }
        if !okayToDrop() {
            pthread_mutex_unlock(&mutex)
            return false
        }
        // if we get this far, we have confirmed that we can go ahead
        // pulling from the source
        guard let linksToMove = sourceDelg.linksForDragging(indexes: sourceIndexes) else {
            pthread_mutex_unlock(&mutex)
            return false
        }
        let othDisplLink = sourceTable.reloadDeslect()
        if !is_other_table { sourceTable.changeDisplayedLink(nil) }
        // inserting in the unsorted links and reloading data
        insertLinks(linksToMove, toRow: row)
        // recalculating selection data
        let newSelected = IndexSet(integersIn:row..<(row + sourceIndexes.count))
        let newDisplayedLinkIndex = calcDisplLinkIdxAfterDrop(sourceIndexes, sourceDisplayLink: othDisplLink, toRow: row)
        pthread_mutex_unlock(&mutex)
        attachedTable!.changeSelection(newSelected, newDisplayedLink: newDisplayedLinkIndex, reload:true)
        // done
        return true
        
        /*
        // the other option this app supports is a drag and drop from the otherlinks table
        else if dragSource === otherTable {
            if !okayToDrop() {
                pthread_mutex_unlock(&mutex)
                return false
            }
            guard let otherDelegate = (otherTable!.dataSource as! GB_LinkTableDelegate?) else {
                pthread_mutex_unlock(&mutex)
                return false
            }
            // pulling from the source
            guard let linksToMove = getDraggedLinks(sourceIndexes, otherDelegate: otherDelegate) else {
                pthread_mutex_unlock(&mutex)
                return false
            }
            let othDisplLink = otherTable!.reloadDeslect()
            // inserting in the unsorted links and reloading data
            insertLinks(linksToMove, toRow: row)
            // recalculating selection data
            let newSelected = IndexSet(integersIn:row..<(row + sourceIndexes.count))
            let newDisplayedLinkIndex = calcDisplLinkIdxAfterDrop(sourceIndexes, sourceDisplayLink: othDisplLink, toRow: row)
            pthread_mutex_unlock(&mutex)
            attachedTable!.changeSelection(newSelected, newDisplayedLink: newDisplayedLinkIndex, reload:true)
            // done
            return true
        }
            // no other source currently supported
        else { return false } */
    }
    
    // +++ [ Selection Related properties and methods ] ++++++++++++++++++++++++++++++++
    
    // helper method to calculate new selected indexes after row-reorder
    fileprivate func makeNewSelectionAfterReorder(_ sourceIndexes:IndexSet, toRow:Int) -> IndexSet {
        let newRow = toRow - sourceIndexes.count(in:0..<toRow)
        return IndexSet(integersIn: newRow..<(newRow+sourceIndexes.count))
    }
    //--------------------------
    // helper method to calculate new value for displayedLinkIndex after drag from other table
    fileprivate func calcDisplLinkIdxAfterDrop(_ sourceIndexes:IndexSet, sourceDisplayLink:UInt?, toRow:Int) -> UInt {
        // assert here (just in case)
        assert(toRow>=0,"Row must be non-negative!")
        // is the other displayed link in the dragged selection?
        let indrag = (sourceDisplayLink != nil) && sourceIndexes.contains(Int(sourceDisplayLink!))
        // if indrag is false, the result is simple
        if !indrag { return UInt(toRow) }
        // otherwise, finding the index of the display in the source indexes
        var currentIndex = sourceIndexes.first
        var indexPosition = 0
        while (currentIndex != nil) && (currentIndex != NSNotFound) {
            if currentIndex == Int(sourceDisplayLink!) { break }
            currentIndex = sourceIndexes.integerGreaterThan(currentIndex!)
            indexPosition += 1
        }
        // return the result
        return UInt(toRow+indexPosition)
    }
    
    
    // selection changed handler
    func tableViewSelectionDidChange(_ notification: Notification) {
        if !(attachedTable!.useSelectionChangeHander) { return }
         if let thisTable = notification.object as! NSTableView? {
            // new selection info info
            let newSelected = thisTable.selectedRowIndexes
            // surprising, the following does happen!
            if newSelected == attachedTable!.selectedIndexes as IndexSet { return }
            // a deselction occurs when one of the previous indexes in deselected
            let deselection = attachedTable!.selectedIndexes.contains(integersIn: newSelected)
            if (deselection) {
                // is the deselected item the displayed link?
                if attachedTable!.indexesContainDisplayedLink() {
                    attachedTable!.changeDisplayedLink(nil)
                }
            }
            // here, a new index has been selected, this is simpler
            else {
                let addedSelection = thisTable.selectedRow
                otherTable?.reloadNoSelect()
                attachedTable!.changeDisplayedLink(UInt(addedSelection))
            }
            // updating
            attachedTable!.updateSelection()
        }
        else { NSLog("SelectionDidn'tChange!\n") }
    }
    
    // handler for link clicked notifications
    func linkClickedHandler(_ notification : Notification) {
        // getting the table which sent it
        guard let sourceTable = notification.object as! NSTableView? else { return }
        // making sure it comes from the other table
        if sourceTable !== otherTable { return }
        // confirmed!
        if let uData = notification.userInfo as? [String : AnyObject] {
            if let tIndex = uData[indexKey] as? Int {
                if (tIndex>=0) { attachedTable!.clearDisplayedLinkIndex() }
            }
        }
    }
    
    // +++ delegate methods for the GB_LinkTableCustomDelegate protocol ++++
    
    // ALL OF THESE MUST BE OVERRIDEN
    func deleteRowFromData(_ rowToDelete:UInt) -> Bool { return false }
    func deleteFromDataTheseRows(_ rows:IndexSet) -> Bool { return false }
    func getPageName() -> String { return "" }
    func getGroupName() -> String { return "" }
    func isForUnsorted() -> Bool { return false }
    func getLinkForRow(_ row:Int) -> GB_SiteLink? { return nil }
    
    
}
//++++++++++++++++++++++++++++++++++++++++++++++++++++
// procedure to one-line attaching a table to its delegate
func attachLinkTable(_ theTable:GB_LinkTableView, toDelegate:GB_LinkTableDelegate) {
    toDelegate.attachedTable = theTable
    theTable.dataSource = toDelegate
    theTable.delegate = toDelegate
    theTable.specialDelegate = toDelegate
}

//=================================================================================
// delegate class that gets link data for a table view from unsortedLinks in a GB_LinkCollection object
class GB_UnsortedLinksDelegate: GB_LinkTableDelegate {

    // externally visible collection property
    var collection:GB_LinkCollection? {
        get { return collectionLink }
        set(newValue) {
            pthread_mutex_lock(&mutex)
            if newValue !== collectionLink {
                /* When the collection is changed, the first unsorted link will always be the
                   displayed link (if there) */
                collectionLink = newValue
                pthread_mutex_unlock(&mutex)

                if (newValue == nil) || (newValue!.unsortedLinkCount == 0) {
                    attachedTable!.reloadNoSelect()
                    attachedTable!.updateSelection()
                    attachedTable!.changeDisplayedLink(nil)
                }
                else {
                    _ = attachedTable!.reloadAndSetIndex(0)
                }
            }
            else { pthread_mutex_unlock(&mutex) }
        }
    }
    
    // +++ [ Overridden basic delegate methods ] +++++++++++++++++++++++++++++++++++
    // (required delegate) number of rows, overridden
    override func numberOfRows(in tableView: NSTableView) -> Int {
        return collectionLink?.unsortedLinkCount ?? 0
    }
    
    // +++ [ Overridden helper methods for drag and drop ] +++++++++++++++++++++++++
    // helper method to re-order source data links upon drop. overridden
    override fileprivate func reorderSourceLinks(_ fromIndexes:IndexSet, toIndex:Int) {
        assert(collectionLink != nil)
        assert(fromIndexes.count>0)
        let reorderResult:Bool
        if fromIndexes.count == 1 {
            reorderResult = collectionLink!.moveLinkInUnsorted(fromIndexes.min()!, toIndex: toIndex)
        }
        else {
            reorderResult = collectionLink!.moveLinksInUnsorted(fromIndexes, toIndex: toIndex)
        }
        assert(reorderResult)
    }
    // helper method to get the links when dragging from another table. overriden
    override fileprivate func getDraggedLinks(_ sourceIndexes:IndexSet, otherDelegate:GB_LinkTableDelegate) -> Array<GB_SiteLink>? {
        let groupsDelegate = otherDelegate as! GB_CurrentGroupLinksDelegate
        let returnLinks = groupsDelegate.currentGroupLink?.extractLinksAtIndexes(sourceIndexes)
        return returnLinks
    }
    // the other side of getDraggedLinks
    override func linksForDragging(indexes:IndexSet) -> [GB_SiteLink]? {
        return collectionLink?.extractLinksAtIndexes(indexes)
    }
    
    // helper method to insert dragged links inside the data source. overriden
    override fileprivate func insertLinks(_ linksToInsert:Array<GB_SiteLink>,toRow:Int) {
        assert(collectionLink != nil)
        assert(toRow<=collectionLink!.unsortedLinkCount)
        _ = collectionLink!.insertLinks(linksToInsert, atIndex: toRow)
    }

    
    // +++ delegate methods for the GB_LinkTableCustomDelegate protocol ++++
    override func deleteRowFromData(_ rowToDelete:UInt) -> Bool {
        if collectionLink == nil { return false }
        if rowToDelete > UInt(collectionLink!.unsortedLinkCount) { return false }
        _ = collectionLink!.deleteUnsortedSite(Int(rowToDelete))
        return true
    }
    override func deleteFromDataTheseRows(_ rows:IndexSet) -> Bool {
        if collectionLink == nil { return false }
        let stuffToDelete = collectionLink!.extractLinksAtIndexes(rows)
        if (stuffToDelete == nil) { return false }
        return true
    }
    // not used for unsorted links
    // func getPageName() -> String { return "" }
    // func getGroupName() -> String { return "" }
    override func isForUnsorted() -> Bool { return true }
    override func getLinkForRow(_ row:Int) -> GB_SiteLink? {
        if collectionLink == nil { return nil }
        if row >= (collectionLink!.unsortedLinkCount) { return nil }
        if row < 0 { return nil }
        return collectionLink!.linkAtIndex(row)
    }

}
//=================================================================================
/* Delegate class that gets link data for current group of current page.
•collection is the only external property, changing the group must be done via the
 changeGroup method, and the page via changePage method.
*/
class GB_CurrentGroupLinksDelegate: GB_LinkTableDelegate {

    // changing the link collection
    var collection:GB_LinkCollection? {
        get { return collectionLink }
        set(inCollection) {
            pthread_mutex_lock(&mutex)
            if (inCollection !== collectionLink) {
                /* The unsorted links collection will be set at the same time, it
                    will take the displayed link, whatever else happens  */
                if inCollection == nil {
                    currentPage = nil;
                    currentGroupLink = nil;
                    collectionLink = nil
                }
                else {
                    collectionLink = inCollection
                    if collectionLink!.listOfPages.count == 0 {
                        currentPage = nil;
                        currentGroupLink = nil;
                    }
                    else {
                        currentPage = collectionLink!.listOfPages[0]
                        if currentPage!.groups.count == 0 { currentGroupLink = nil }
                        else { currentGroupLink = currentPage!.groups[0] }
                    }
                }
                attachedTable!.reloadNoSelect()
            }
            pthread_mutex_unlock(&mutex)
        }
    }
    // page and group pointers (cannot be changed from outside)
    fileprivate var currentPage:GB_PageOfLinks? = nil
    fileprivate(set) var currentGroupLink:GB_LinkGroup? = nil
    
    // +++ [ Overridden basic delegate methods ] +++++++++++++++++++++++++++++++++++
    // (required delegate) number of rows, overridden
    override func numberOfRows(in tableView: NSTableView) -> Int {
        return currentGroupLink?.count ?? 0
    }
    
    // +++ [ Overridden helper methods for drag and drop ] +++++++++++++++++++++++++
    // helper method to re-order source data links upon drop. overridden
    override fileprivate func reorderSourceLinks(_ fromIndexes:IndexSet, toIndex:Int) {
        assert(collectionLink != nil)
        assert(fromIndexes.count>0)
        assert(currentGroupLink != nil)
        let reorderResult:Bool
        if fromIndexes.count == 1 {
            reorderResult = currentGroupLink!.moveLinkInternally(fromIndexes.min()!, toIndex: toIndex)
        }
        else {
            reorderResult = currentGroupLink!.moveLinksInternally(fromIndexes, toIndex: toIndex)
        }
        assert(reorderResult)
    }
    // helper method to find out if we can recieve extral drag and drop. overridden
    override fileprivate func okayToDrop() -> Bool {
        return (currentGroupLink != nil)
    }
    // helper method to get the links when dragging from another table. overriden
    override fileprivate func getDraggedLinks(_ sourceIndexes:IndexSet, otherDelegate:GB_LinkTableDelegate) -> Array<GB_SiteLink>? {
        if collectionLink == nil { return nil }
        let returnLinks = collectionLink!.extractLinksAtIndexes(sourceIndexes)
        return returnLinks
    }
    // the other side of getDraggedLinks
    override func linksForDragging(indexes:IndexSet) -> [GB_SiteLink]? {
        return currentGroupLink?.extractLinksAtIndexes(indexes)
    }
    // helper method to insert dragged links inside the data source. overriden
    override fileprivate func insertLinks(_ linksToInsert:Array<GB_SiteLink>,toRow:Int) {
        assert(currentGroupLink != nil)
        assert(toRow <= currentGroupLink!.count)
        _ = currentGroupLink!.insertLinks(linksToInsert, atIndex: toRow)
    }
    
    // +++ [Changing the Group/Page] ++++++++++++++++++++++++++++++++++++
    
    // changing the page (and the group with it)
    func changePage(_ newPageIndex:UInt) -> Bool {
        NSLog("GL changePage 01")
        pthread_mutex_lock(&mutex)
        var result = false
        NSLog("GL changePage 02")
        if (collectionLink != nil) && (newPageIndex < UInt(collectionLink!.listOfPages.count)) {
            currentPage = collectionLink!.listOfPages[Int(newPageIndex)]
            NSLog("GL changePage 03")
            if (currentPage!.groups.count > 0) {
                pthread_mutex_unlock(&mutex)
                NSLog("GL changePage 04")
                return changeGroup(0)
            }
            else {
                pthread_mutex_unlock(&mutex)
                attachedTable!.reloadNoSelect()
                attachedTable!.changeDisplayedLink(nil)
                NSLog("GL changePage 05")
                result = true
            }
        }
        else { pthread_mutex_unlock(&mutex) }
        NSLog("GL changePage 06")
        return result
    }
    
    // changing the group
    func changeGroup(_ newGroupIndex:UInt) -> Bool {
        pthread_mutex_lock(&mutex)
        var result = false
        if (currentPage != nil) && (newGroupIndex < UInt(currentPage!.groups.count)) {
            currentGroupLink = currentPage!.groups[Int(newGroupIndex)]
            if attachedTable!.hasLinkIndex() {
                let newdispl:UInt? = ((currentGroupLink!.count < 1) ? nil : 0 )
                pthread_mutex_unlock(&mutex)
                attachedTable!.reloadAndPickIndex(newdispl)
            }
            else {
                pthread_mutex_unlock(&mutex)
                _ = attachedTable!.reloadDeslect()
            }
            result = true
        }
        else { pthread_mutex_unlock(&mutex) }
        return result
    }
    
    // +++ [ Some overriden methods ] ++++++++++++++++++++++++++++++++++++++++++++++

    // insert link
    func insertInCurrentGroupLink(_ newLink:GB_SiteLink, at:UInt) -> Bool {
        if currentGroupLink == nil { return false }
        if at > UInt(currentGroupLink!.count) { return false }
        _ = currentGroupLink!.insertLink(newLink, atIndex: Int(at))
        return true
    }
    // append link
    func appendToCurrentGroupLink(_ newLink:GB_SiteLink) -> Bool {
        if currentGroupLink == nil { return false }
        currentGroupLink!.appendLink(newLink)
        return true
    }
    
    // +++ delegate methods for the GB_LinkTableCustomDelegate protocol ++++
    

    override func deleteRowFromData(_ rowToDelete:UInt) -> Bool {
        if (currentGroupLink == nil) { return false }
        if rowToDelete >= UInt(currentGroupLink!.count) { return false }
        _ = currentGroupLink!.deleteLink(Int(rowToDelete))
        return true
    }
    //-------------------------
    override func deleteFromDataTheseRows(_ rows:IndexSet) -> Bool {
        if collectionLink == nil { return false }
        if (currentGroupLink == nil) { return false }
        let stuffToDelete = currentGroupLink!.extractLinksAtIndexes(rows)
        if (stuffToDelete == nil) { return false }
        return true
    }
    //-------------------------
    override func getPageName() -> String {
        return currentPage?.pageName ?? ""
    }
    //-------------------------
    override func getGroupName() -> String {
        return currentGroupLink?.groupName ?? ""
    }
    //-------------------------
    // func isForUnsorted() -> Bool { return false }
    //-------------------------
    override func getLinkForRow(_ row:Int) -> GB_SiteLink? {
        pthread_mutex_lock(&mutex)
        if (currentGroupLink == nil) || (row<0) || (row>=currentGroupLink!.count) {
            pthread_mutex_unlock(&mutex)
            return nil
        }
        else {
            let result = currentGroupLink!.linkAtIndex(row)
            pthread_mutex_unlock(&mutex)
            return result
        }
    }
    
    // helpful to find (and reload) links that have changed
    func getIndexForLink(_ inLink:GB_SiteLink) -> Int {
        pthread_mutex_lock(&mutex)
        defer { pthread_mutex_unlock(&mutex) }
        if currentGroupLink == nil { return -1 }
        else { return currentGroupLink!.getIndexForLink(inLink) }
    }
    
}
