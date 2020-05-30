//
//  delegates.swift
//  GeneralBookmarks
//  Delegates and other interface objects for lists of groups and pages
//  Created by David Faulks on 2016-05-01.
//  Copyright © 2016-2019 dfaulks. All rights reserved.

import Foundation
import Cocoa

//=================================================================================
// function to make changed index dictionary (for notifications)
func makeChangedIndexDict(_ fromRow:Int, toRow:Int) -> [String:Int] {
    return ["from row":fromRow,"to row":toRow]
    
}
//=================================================================================
let GroupChangedNotification = Notification.Name(rawValue: "GroupChangedNotification")


// the delegate that produces group names for a simple string list (aka GB_StringListView)
class GB_GroupNamesDelegate : NSObject, GBListBoxDelegate {
    
    // +++ [ properties and data ] +++++++++++++++++++++++++++++++++++++++++
    fileprivate var currentPage:GB_PageOfLinks? = nil
    fileprivate var collectionLink:GB_LinkCollection? = nil
    fileprivate var mutex = pthread_mutex_t()
    // the only public property
    var collection:GB_LinkCollection? {
        get { return collectionLink }
        set(inCollection) {
            pthread_mutex_lock(&mutex)
            collectionLink = inCollection
            if (collectionLink == nil) { currentPage = nil }
            else {
                if collectionLink!.listOfPages.count == 0 { currentPage = nil }
                else { currentPage = collectionLink!.listOfPages[0] }
            }
            pthread_mutex_unlock(&mutex)
        }
    }
    // semi public property
    var hasCurrentPage:Bool {
        return (currentPage != nil)
    }
    
    // +++ [ Initialization ] ++++++++++++++++++++++++++++++++++++++++++++++
    
    override init() {
        super.init()
        pthread_mutex_init(&mutex, nil)
    }
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    // +++ [ Delegate Methods ] ++++++++++++++++++++++++++++++++++++++++++++
    var itemCount:Int {
        get {
            pthread_mutex_lock(&mutex)
            let rResult = currentPage?.groups.count ?? 0
            pthread_mutex_unlock(&mutex)
            return rResult
        }
    }
    func getStringAtIndex(_ index:Int) -> String? {
        pthread_mutex_lock(&mutex)
        let rResult:String?
        if (currentPage == nil) || (index > currentPage!.groups.count) { rResult = nil}
        else { rResult = currentPage!.groups[index].groupName }
        pthread_mutex_unlock(&mutex)
        return rResult
    }
    
    var attachedListBox:GBListBox? = nil
    
    func moveRow(_ fromRow:Int, toRow:Int) -> Bool {
        return moveItemInArray(&(currentPage!.groups), fromIndex: fromRow, toIndex: toRow)
    }
    
    func selectionChange(_ newSelection:Int, oldSelection:Int) {
        let notificationData = makeChangedIndexDict(oldSelection, toRow: newSelection)
        NotificationCenter.default.post(name: GroupChangedNotification, object: self.attachedListBox!, userInfo: notificationData)
    }
    // pointers to the links tables
    var unsortedLinksTable:GB_LinkTableView? = nil
    var currGroupLinksTable:GB_LinkTableView? = nil
    
    // external drag drop
    func handleExternalDrop(_ dropSource:AnyObject, typePaste:NSPasteboard.PasteboardType, sourceIndexes:IndexSet, toRow:Int) -> Bool {
        if toRow < 0 { return false }
        // getting the current group link
        guard let cGroupDelegate = currGroupLinksTable?.specialDelegate as? GB_CurrentGroupLinksDelegate else {
            return false;
        }
        let currentGroup = cGroupDelegate.currentGroupLink
        
        // two types of drop
        // dropping links into a group
        if (typePaste == GBSiteLinkPBoardType) {
            // cast source into the proper type
            guard let sourceTable = dropSource as? GB_LinkTableView else {
                return false
            }
            // calling the handler function
            return handleLinksDrop(source: sourceTable, sourceIndexes: sourceIndexes,
                                   toRow: toRow, currentGroup: currentGroup)
        }
        // dropping groups into this list of groups
        if (typePaste == NSPasteboard.PasteboardType.string) {
            // getting the various pointers we need
            guard let sourceTable = groupTableFromDropSource(dropSource) else {
                return false
            }
            let sourceDelegate = sourceTable.delegate as! GB_GroupNamesDelegate

            // currently, the groups table does not allow multiple selection
            let sourceIndex = sourceIndexes.first!
            let newSourceSelection = sourceTable.getNewSelectionAfterRowDelete(sourceIndex)
            // extracting the group
            guard let groupToMove = sourceDelegate.currentPage?.groups.remove(at: sourceIndex) else {
                return false;
            }
            // inserting the group
            currentPage?.groups.insert(groupToMove, at: toRow)
            // reloading and selecting
            _ = sourceTable.reloadAndSelect(newSourceSelection, true)
            attachedListBox?.reloadAndSelect(toRow, true)
            // done
            return true
        }
        // other
        else { return false }
        

        
        
        /*
        // preventing dragging into the same group
        if (sourceTable === currGroupLinksTable) {
            if (currentPage!.groups[toRow]) === currentGroup { return false }
        }
        // we'll extract links from the delegate
        guard let sourceDelegate = sourceTable.dataSource as? GB_LinkTableDelegate else {
            return false;
        }
        // gathering some index info for later
        let afterIndex = sourceTable.calcIndexesAfterDrag(sourceIndexes)
        let nIndex:UInt? = (afterIndex.0 < 0) ? nil : UInt(afterIndex.0)
        // getting the links
        guard let linksToMove = sourceDelegate.linksForDragging(indexes: sourceIndexes) else {
            return false;
        }
        // inserting them
        currentPage!.groups[toRow].appendLinkArray(linksToMove)
        // handling post move reloads and selecting
        sourceTable.reloadAndPickIndex(nIndex)
        if afterIndex.1 { sourceTable.changeDisplayedLink(nIndex) }
        
        // we might need to reload current groups as well
        if (currentPage!.groups[toRow]) === currentGroup {
            currGroupLinksTable!.reloadAfterAppend()
        }
        
        return true */
    }
    
    // handles dragging links into the group
    fileprivate func handleLinksDrop(source:GB_LinkTableView, sourceIndexes:IndexSet,
                        toRow:Int, currentGroup:GB_LinkGroup?) -> Bool {
        // preventing dragging into the same group
        if (source === currGroupLinksTable) {
            if (currentPage!.groups[toRow]) === currentGroup { return false }
        }
        // we'll extract links from the delegate
        guard let sourceDelegate = source.dataSource as? GB_LinkTableDelegate else {
            return false;
        }
        // gathering some index info for later
        let afterIndex = source.calcIndexesAfterDrag(sourceIndexes)
        let nIndex:UInt? = (afterIndex.0 < 0) ? nil : UInt(afterIndex.0)
        // getting the links
        guard let linksToMove = sourceDelegate.linksForDragging(indexes: sourceIndexes) else {
            return false;
        }
        // inserting them
        currentPage!.groups[toRow].appendLinkArray(linksToMove)
        // handling post move reloads and selecting
        source.reloadAndPickIndex(nIndex)
        if afterIndex.1 { source.changeDisplayedLink(nIndex) }
        
        // we might need to reload current groups as well
        if (currentPage!.groups[toRow]) === currentGroup {
            currGroupLinksTable!.reloadAfterAppend()
        }
        
        return true
    }
    
    // is the drop coming from a listbox of groups? returns it if it is.
    fileprivate func groupTableFromDropSource(_ dropsSrc:Any?) -> GBListBox? {
        guard let lTable = dropsSrc as? GB_DragDisablable_TableView else {
            return nil
        }
        guard let lbox = lTable.delegate as? GBListBox else {
            return nil
        }
        guard let gdel = lbox.delegate as? GB_GroupNamesDelegate else {
            return nil
        }
        return lbox
    }
    
    // validates external drop
    func validateExternalDrop(_ table:NSTableView, info:NSDraggingInfo, toRow:Int) -> NSDragOperation {
        // dragging links into a group
        if let linkTable = info.draggingSource() as? GB_LinkTableView {
            table.setDropRow(toRow, dropOperation: .on)
            return NSDragOperation.generic
        }
        // dragging groups into the list of groups (from another collection)
        else if let lbox = groupTableFromDropSource(info.draggingSource()) {
            table.setDropRow(toRow, dropOperation: .above)
            return NSDragOperation.generic
        }
        else {
            return NSDragOperation();
        }
              
    }
    
    // +++ [ Other Methods ] ++++++++++++++++++++++++++++++++++++++++++++++++
    // changes the page, the list of groups is changed
    func changePage(_ newPageIndex:UInt) -> Bool {
        pthread_mutex_lock(&mutex)
        var result = false
        /**/NSLog("changePage 01 : \(newPageIndex)")
        if (collectionLink != nil) && (newPageIndex < UInt(collectionLink!.listOfPages.count)) {
            currentPage = collectionLink!.listOfPages[Int(newPageIndex)]
            /**/NSLog("changePage 02 \(currentPage!.groups.count)")
            // next, we have to reload the list box
            pthread_mutex_unlock(&mutex)
            attachedListBox!.reloadData(true)
            if currentPage!.groups.count > 0 {
                _ = attachedListBox!.changeSelection(0, true)
            }
            result = true
        }
        else { pthread_mutex_unlock(&mutex) }
        return result
    }
    // creates a new empty group and appends it to the current page
    func appendNewGroup(_ groupName:String) -> Bool {
        pthread_mutex_lock(&mutex)
        let okay:Bool
        if currentPage != nil {
            let newGroup = GB_LinkGroup(inName: groupName)
            currentPage!.groups.append(newGroup)
            okay = true
        }
        else { okay = false }
        pthread_mutex_unlock(&mutex)
        return okay
    }
    // creates a new empty group and inserts it to the current page
    func insertNewGroup(_ groupName:String, atIndex:UInt) -> Bool {
        pthread_mutex_lock(&mutex)
        let okay:Bool
        if (currentPage != nil) && (atIndex < UInt(currentPage!.groups.count)) {
            let newGroup = GB_LinkGroup(inName: groupName)
            currentPage!.groups.insert(newGroup, at: Int(atIndex))
            okay = true
        }
        else { okay = false }
        pthread_mutex_unlock(&mutex)
        return okay
    }
    // renames a group in the current page
    func renameGroup(_ atIndex:UInt, toName:String) -> Bool {
        pthread_mutex_lock(&mutex)
        let okay:Bool
        if (currentPage != nil) && (atIndex < UInt(currentPage!.groups.count)) {
            currentPage!.groups[Int(atIndex)].groupName = toName
            okay = true
        }
        else { okay = false }
        pthread_mutex_unlock(&mutex)
        return okay
    }
    // returns a group at the index (please do not delete)
    func groupAtIndex(_ index:UInt) -> GB_LinkGroup? {
        pthread_mutex_lock(&mutex)
        let result:GB_LinkGroup?
        if (currentPage != nil) && (index < UInt(currentPage!.groups.count)) {
            result = currentPage!.groups[Int(index)]
        }
        else { result = nil }
        pthread_mutex_unlock(&mutex)
        return result
    }
    // deletes group at the Index
    func deleteGroup(_ atIndex:UInt) -> Bool {
        pthread_mutex_lock(&mutex)
        let okay:Bool
        if (currentPage != nil) && (atIndex < UInt(currentPage!.groups.count)) {
            currentPage!.groups.remove(at: Int(atIndex))
            okay = true
        }
        else { okay = false }
        pthread_mutex_unlock(&mutex)
        return okay
    }
}

//======================================================================================
//======================================================================================

let PageChangedNotification = Notification.Name(rawValue: "PageChangedNotification")

// the delegate that produces page names for a simple string list (aka GB_StringListView)
class GB_PageNamesDelegate : NSObject, GBListBoxDelegate {
    
    // +++ [ properties and data ] +++++++++++++++++++++++++++++++++++++++++
    fileprivate var collectionLink:GB_LinkCollection? = nil
    fileprivate var mutex = pthread_mutex_t()
    // the only public property
    var collection:GB_LinkCollection? {
        get { return collectionLink }
        set(inCollection) {
            pthread_mutex_lock(&mutex)
            collectionLink = inCollection
            pthread_mutex_unlock(&mutex)
        }
    }
    
    // +++ [ Initialization ] ++++++++++++++++++++++++++++++++++++++++++++++
    
    override init() {
        super.init()
        pthread_mutex_init(&mutex, nil)
    }
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    
    // +++ [ Delegate Methods ] ++++++++++++++++++++++++++++++++++++++++++++
    var itemCount:Int {
        get {
            pthread_mutex_lock(&mutex)
            let rResult = collectionLink?.listOfPages.count ?? 0
            pthread_mutex_unlock(&mutex)
            return rResult
        }
    }
    
    func getStringAtIndex(_ index:Int) -> String? {
        pthread_mutex_lock(&mutex)
        let rResult:String?
        if (collectionLink == nil) || (index > collectionLink!.listOfPages.count) { rResult = nil}
        else { rResult = collectionLink!.listOfPages[index].pageName }
        pthread_mutex_unlock(&mutex)
        return rResult
    }
    
    var attachedListBox:GBListBox? = nil
    
    func moveRow(_ fromRow:Int, toRow:Int) -> Bool {
        return moveItemInArray(&(collectionLink!.listOfPages), fromIndex: fromRow, toIndex: toRow)
    }
    func selectionChange(_ newSelection:Int, oldSelection:Int) {
        let notificationData = makeChangedIndexDict(oldSelection, toRow: newSelection)
        NotificationCenter.default.post(name: PageChangedNotification, object: self.attachedListBox!, userInfo: notificationData)

    }
    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // drag and drop
    var sourceListFromDrop:GBListBox? = nil
    
    // external drag drop
    func handleExternalDrop(_ dropSource:AnyObject, typePaste:NSPasteboard.PasteboardType, sourceIndexes:IndexSet, toRow:Int) -> Bool {
        // currently, we only handle dropping groups and pages
        if (typePaste != .string) { return false }
        if toRow < 0 { return false }
        guard let drag_info = checkDragSource(dropSource) else { return false }
        // the pages/groups table do not allow multiple selection
        let sourceIndex = sourceIndexes.first!
        
        // dragging groups
        if drag_info.0 {
            let sourceDelegate = drag_info.1.delegate as! GB_GroupNamesDelegate
            let within_collection = (sourceListFromDrop === drag_info.1)
            // no dragging group to the same page it comes from
            let currentPageIndex = attachedListBox!.selectedIndex
            if within_collection && (currentPageIndex == toRow) { return false }
            // taking the group
            let newSourceSelection = drag_info.1.getNewSelectionAfterRowDelete(sourceIndex)
            guard let groupToMove = sourceDelegate.currentPage?.groups.remove(at: sourceIndex) else {
                return false;
            }
            // inserting
            collectionLink!.listOfPages[toRow].groups.append(groupToMove)

            // reloading and selecting
            _ = drag_info.1.reloadAndSelect(newSourceSelection, true)
            if (currentPageIndex == toRow) {
                attachedListBox?.reloadData(false)
            }
            return true
        }
        // dragging pages (from another collection)
        else {
            let pagesDelegate = drag_info.1.delegate as! GB_PageNamesDelegate
            guard let scoll = pagesDelegate.collection else { return false }
            let newSourceSelection = drag_info.1.getNewSelectionAfterRowDelete(sourceIndex)
            let pageToMove = scoll.listOfPages.remove(at: sourceIndex)
            collectionLink!.listOfPages.insert(pageToMove, at: toRow)
            // reloading and selecting
            _ = drag_info.1.reloadAndSelect(newSourceSelection, true)
            _ = attachedListBox?.reloadAndSelect(toRow, true)
            return true
        }
    }
    // validates external drop
    func validateExternalDrop(_ table:NSTableView, info:NSDraggingInfo, toRow:Int) -> NSDragOperation {
        if let drag_res = checkDragSource(info.draggingSource()) {
            if collectionLink == nil { return NSDragOperation() }
            if drag_res.0 { table.setDropRow(toRow, dropOperation: .on) }
            else { table.setDropRow(toRow, dropOperation: .above) }
            return NSDragOperation.generic
        }
        else { return NSDragOperation() }
    }
    
    /* For external drops, we allow group drags into a page, and page drags into
       the collection. */
    private func checkDragSource(_ src:Any?) -> (Bool,GBListBox)? {
        guard let xsrc = src as? GB_DragDisablable_TableView else {
            return nil
        }
        guard let ptable = xsrc.delegate as? GBListBox else {
            return nil
        }
        if let gdel = ptable.delegate as? GB_GroupNamesDelegate {
            return (true,ptable)
        }
        if let pdel = ptable.delegate as? GB_PageNamesDelegate {
            return (false,ptable)
        }
        return nil
    }
    
    
}
//=================================================================================
