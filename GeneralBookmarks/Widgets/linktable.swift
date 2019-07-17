//
//  linktable.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-08-09.
//  Copyright © 2016-2019 dfaulks. All rights reserved.
//

import Foundation
import Cocoa

// custom NSTableView subclass, for viewing and manipulating the list of links
// In the end, I had to subclass NSTableView because it seems to be the only non-kludgy way to delete rows using keypresses
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// protocol for the custom subclass, used to get data and some basic info
@objc protocol GB_LinkTableCustomDelegate {
    func deleteRowFromData(_ rowToDelete:UInt) -> Bool
    func deleteFromDataTheseRows(_ rows:IndexSet) -> Bool
    func getPageName() -> String
    func getGroupName() -> String
    func isForUnsorted() -> Bool
    func getLinkForRow(_ row:Int) -> GB_SiteLink?
}
//+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

class GB_LinkTableView : NSTableView {
    
    var specialDelegate:GB_LinkTableCustomDelegate? = nil;
    
    var rowCount:UInt {
        get { return UInt(dataSource?.numberOfRows!(in: self) ?? 0) }
    }
    fileprivate var mutex = pthread_mutex_t()
    
    // initializers, some of which are required for no good reason
    required init?(coder:NSCoder) {
        pthread_mutex_init(&mutex, nil)
        super.init(coder:coder);

    }
    override init(frame aRect:CGRect) {
        pthread_mutex_init(&mutex, nil)
        super.init(frame:aRect)

    }
    deinit {
        pthread_mutex_destroy(&mutex)
    }
    //-----------------------------------------------------------------------------------
    // overriding keyDown so we can implement deleting rows by keyPress
    override func keyDown(with theEvent: NSEvent) {
        var isDeleteKeyEvent = false;
        // the following code is just to detect if the key being pressed is a delete key
        if theEvent.type == NSEvent.EventType.keyDown {
            let inputChars = theEvent.characters
            if (inputChars != nil) && (inputChars!.count == 1) {
                let theChar = inputChars!.unicodeScalars.first!
                if (theChar.value == UInt32(NSDeleteCharacter)) || (theChar.value == UInt32(NSDeleteFunctionKey)) {
                    isDeleteKeyEvent = true;
                }
            }
        }
        // passing on a non delete event
        if (!isDeleteKeyEvent) { super.keyDown(with: theEvent) }
        // finding the selection and deleting it!
        else {
            if selectedRowIndexes.count != 0 {
                _ = deleteTheseRowsInTable(selectedRowIndexes)
            }
            selectedIndexes = selectedRowIndexes
        }
    }
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    public func launchInBrowser(row:Int) -> Bool {
        guard let urlString = specialDelegate?.getLinkForRow(row)?.getUrlAtIndex(0) else { return false}
        guard let clickedURL = URL(string: urlString) else { return false }
        NSWorkspace.shared.open(clickedURL)
        return true;
    }
    public func launchClickedRowInBrowser() -> Bool {
        if (clickedRow < 0) { return false }
        else { return launchInBrowser(row: clickedRow) }
    }
    
    // +++ [ special selection related methods and properties ] ++++++++++++++++++++++
    // set to false when I want change a selection without triggering tableViewSelectionDidChange
    fileprivate(set) var useSelectionChangeHander:Bool = true
    
    /* We keep track of the selection here because in a multiple selection table, there is no way
     to tell the difference between select and deselect without knowing the old selection data */
    fileprivate(set) var selectedIndexes:IndexSet = IndexSet()
    
    func updateSelection() {
        selectedIndexes = selectedRowIndexes
    }
    
    // a particular link might be displayed in detail in the special panel. This is tracked (and marked)
    fileprivate(set) var displayedLinkIndex:UInt? = nil
    
    func rowIsDisplayedLink(_ theRow:Int) -> Bool {
        if displayedLinkIndex == nil { return false }
        else { return (displayedLinkIndex! == UInt(theRow)) }
    }
    func hasLinkIndex() -> Bool {
        return (displayedLinkIndex != nil)
    }
    func indexesContainDisplayedLink() -> Bool {
        if displayedLinkIndex == nil { return false }
        return selectedIndexes.contains(Int(displayedLinkIndex!))
    }
    func clearDisplayedLinkIndex() {
        displayedLinkIndex = nil;
    }
    
    // helper method for sending displayedLink notifications
    func changeDisplayedLink(_ newDisplayedLink:UInt?) {
        let forUnsortedLinks = specialDelegate!.isForUnsorted()
        displayedLinkIndex = newDisplayedLink
        var notificationData:[String : AnyObject]
        if (displayedLinkIndex == nil) {
            notificationData = makeLinkDisplayNotification(-1, forUnsortedLinks, nil, groupName: nil, pageName: nil)
        }
        else {
            let gNameParam = specialDelegate!.getGroupName()
            let pNameParam = specialDelegate!.getPageName()
            notificationData = makeLinkDisplayNotification(Int(displayedLinkIndex!), forUnsortedLinks,
                                    specialDelegate!.getLinkForRow(Int(displayedLinkIndex!)), groupName:gNameParam, pageName: pNameParam)
        }
        NotificationCenter.default.post(name: LinkClickedNotification, object: self, userInfo: notificationData)
    }
    //+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    /* When doing an internal row drag and drop (the delegate methods for this are merged
        with the same delegate that provides data), we need to know where the Displayed Link Index will be */
    func calcDisplLinkIdxAfterReorder(_ sourceIndexes:IndexSet, newRow:Int) -> UInt? {
        if displayedLinkIndex == nil { return UInt(newRow) }
        /* assert check: a displayed link must be selected, and therefore must have
         been moved by a drag-and-drop row re-order. */
        if (!sourceIndexes.contains(Int(displayedLinkIndex!))) { return UInt(newRow) }
        // finding the index of the display in the source indexes
        var currentIndex = sourceIndexes.first
        var indexPosition = 0
        while (currentIndex != nil) && (currentIndex != NSNotFound) {
            if currentIndex == Int(displayedLinkIndex!) { break }
            currentIndex = sourceIndexes.integerGreaterThan(currentIndex!)
            indexPosition += 1
        }
        // return the result
        return UInt(newRow + indexPosition)
    }
    
    /* Helper method, calculate the new selection index and displayedLinkIndex after drag **to**
     another table, which will **not** be the selected table.
     The result is (<selected index>,<make selected index displayed>)  */
    func calcIndexesAfterDrag(_ draggedRows:IndexSet) -> (Int, Bool) {
        let haveDisp = (displayedLinkIndex != nil)
        var newSelection:Int
        // special case, everything is being dragged!
        if UInt(draggedRows.count) == rowCount { return (-1, haveDisp ) }
        // if the dragging is multiple rows, it must contain the selection
        if draggedRows.count > 1 {
            // if the table does not display a link, we select nothing!
            if !haveDisp { return (-1,false) }
            // otherwise, we have to pick a new selection (and display it)
            newSelection = draggedRows.first!
            if  newSelection == (Int(rowCount) - draggedRows.count) { newSelection -= 1 }
            return (newSelection,true)
        }
            // otherwise, it might, we need to find the old selection
        else {
            let oldSelection = selectedRowIndexes.first
            // nothing is selected? okay
            if (oldSelection == NSNotFound) || (oldSelection == nil) { return (-1,false) }
            // if we have a selection, we might need to move it
            if oldSelection! > draggedRows.first! { newSelection = oldSelection!-1 }
            else if oldSelection == (Int(rowCount) - 1) { newSelection = oldSelection!-1 }
            else { newSelection = oldSelection! }
            // done
            return (newSelection, haveDisp )
        }
    }
    
    /* Another calculate indexes, this time when deleting a row. If there is a displayed
     link, we always selected a new one if deleted, unless there are none left. This
     is the *only* time the entire result is nil, and a nil selection notification
     should be sent only the. */
    fileprivate func calcIndexesWhenDeleting(_ rowToDelete:UInt) -> (IndexSet,UInt?)? {
        // assertion check
        assert(rowToDelete<rowCount)
        // checking selection data...
        let currentSelection = selectedRowIndexes
        // three different cases...
        // nothing is selected
        if currentSelection.count == 0 { return (IndexSet(),nil) }
            // deleting the displayed and only row
        else if (rowCount==1) && (displayedLinkIndex != nil ) { return nil }
            // one row is selected
        else if currentSelection.count == 1 {
            let currSel = currentSelection.first
            if displayedLinkIndex != nil {
                assert(displayedLinkIndex! == UInt(currSel!))
            }
            var newSek:Int
            if UInt(currSel!) > rowToDelete  { newSek = currSel!-1}
            else if (UInt(currSel!) == rowToDelete) && (currSel! == (Int(rowCount) - 1)) { newSek = currSel! - 1}
            else { newSek = currSel! }
            return (IndexSet(integer:newSek), (displayedLinkIndex==nil) ? nil : UInt(newSek) )
        }
            // multiple rows are selected
        else {
            var newSelection:IndexSet = IndexSet();
            // looping through the selected indexes to build the new selected indexes
            var currentIndex = currentSelection.first
            while (currentIndex != nil) && (currentIndex != NSNotFound) {
                if currentIndex! < Int(rowToDelete) { newSelection.insert(currentIndex!) }
                else if currentIndex! > Int(rowToDelete) { newSelection.insert(currentIndex!-1) }
                currentIndex = currentSelection.integerGreaterThan(currentIndex!)
            }
            // figuring out the new displayed index
            let newDisplIndex:UInt?
            if displayedLinkIndex != nil {
                if displayedLinkIndex! > rowToDelete { newDisplIndex = displayedLinkIndex! - 1 }
                else if displayedLinkIndex! == rowToDelete { newDisplIndex = UInt(newSelection.min()!) }
                else { newDisplIndex = displayedLinkIndex }
            }
            else { newDisplIndex = nil }
            // done
            return (newSelection,newDisplIndex)
        }
    }
    
    // delete one row (and update display)
    func deleteRowInTable(_ rowToDelete:UInt) -> Bool {
        // validity checks
        if rowToDelete >= rowCount { return false }
        // starting...
        pthread_mutex_lock(&mutex)
        // getting the new selection info
        let newSelectionData = calcIndexesWhenDeleting(rowToDelete)
        // deleting
        if (specialDelegate == nil) {
            pthread_mutex_unlock(&mutex)
            return false;
        }
        if !(specialDelegate!.deleteRowFromData(rowToDelete)) {
            pthread_mutex_unlock(&mutex)
            return false;
        }
        pthread_mutex_unlock(&mutex)
        // releading data and handling the selection afterwards
        reloadNoSelect()
        if newSelectionData == nil { changeDisplayedLink(nil) }
        else {
            let newIndexes = newSelectionData!.0
            if newSelectionData!.1 != nil {
                changeSelection(newIndexes, newDisplayedLink: newSelectionData!.1, reload:false)
            }
            else {
                useSelectionChangeHander = false
                selectRowIndexes(newIndexes, byExtendingSelection: false)
                selectedIndexes = newIndexes
                displayedLinkIndex = nil
                useSelectionChangeHander = true
            }
        }
        // done
        return true
    }
    
    // delete several rows (and update display)
    func deleteTheseRowsInTable(_ rowsToDelete:IndexSet) -> Bool {
        // validity check
        if rowsToDelete.count == 0 { return false }
        if UInt(rowsToDelete.last!) >= rowCount { return false }
        // starting ....
        pthread_mutex_lock(&mutex)
        let newSelectionData = calcIndexesAfterDrag(rowsToDelete)
        // deleting
        if (specialDelegate == nil) {
            pthread_mutex_unlock(&mutex)
            return false;
        }
        if !(specialDelegate!.deleteFromDataTheseRows(rowsToDelete)) {
            pthread_mutex_unlock(&mutex)
            return false;
        }
        pthread_mutex_unlock(&mutex)
        // reloading and changing the selection data
        if newSelectionData.0 != -1 {
            let displ:UInt? = (newSelectionData.1) ? UInt(newSelectionData.0) : nil
            changeSelection(IndexSet(integer:newSelectionData.0), newDisplayedLink: displ, reload: true)
        }
        // reloading and changing the selection data to nothing
        else {
            reloadNoSelect()
            if newSelectionData.1 { changeDisplayedLink(nil) }
        }
        return true;
    }
    // delete currently selected rows
    func deleteSelectedRows() -> Bool {
        if selectedRowIndexes.count != 0 {
            _ = deleteTheseRowsInTable(selectedRowIndexes)
            selectedIndexes = selectedRowIndexes
            return true
        }
        else { return false }
    }
    
    // helper method to change selection and displayed link programmatically
    func changeSelection(_ newSelected:IndexSet, newDisplayedLink:UInt?, reload:Bool) {
        // general change of selection
        useSelectionChangeHander = false
        if reload { reloadData() }
        selectRowIndexes(newSelected, byExtendingSelection: false)
        selectedIndexes = newSelected
        // handling the displayed link
        changeDisplayedLink(newDisplayedLink)
        useSelectionChangeHander = true
    }
    //++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    /* When dragging to another table, to avoid selection hassles, we reload using this
     method. Also, it returns the displayedLinkIndex, which will be set to nil. */
    func reloadDeslect() -> UInt? {
        useSelectionChangeHander = false
        reloadData()
        deselectAll(self)
        let oldDisplayedLink = displayedLinkIndex
        displayedLinkIndex = nil
        selectedIndexes = IndexSet()
        useSelectionChangeHander = true
        return oldDisplayedLink
    }
    // a more selective version of the above, used when you want to clear a selection
    func reloadNoSelect() {
        useSelectionChangeHander = false
        displayedLinkIndex = nil
        deselectAll(self)
        reloadData()
        selectedIndexes = IndexSet()
        useSelectionChangeHander = true
    }    
    /* Reloads table and restores old selection data. Use only after appending */
    func reloadAfterAppend() {
        useSelectionChangeHander = false
        let oldSelection = selectedRowIndexes
        reloadData()
        selectRowIndexes(oldSelection, byExtendingSelection: false)
        useSelectionChangeHander = true
    }
    // reloads row
    func reloadRow(_ rowIndex:UInt) -> Bool {
        // verifications
        if rowIndex >= rowCount { return false }
        // reload column by column
        let ʒrow = IndexSet(integer:Int(rowIndex))
        let columnCount = numberOfColumns
        // skipping column 1 for now
        let columnDex = IndexSet(integersIn: 1..<columnCount)
        reloadData(forRowIndexes: ʒrow, columnIndexes: columnDex)
        return true
    }
    
    // helper method, reloads table, and selects (with display) one index
    func reloadAndPickIndex(_ theIndex:UInt?) {
        useSelectionChangeHander = false
        reloadData()
        if theIndex != nil {
            selectedIndexes = IndexSet(integer:Int(theIndex!))
            selectRowIndexes(selectedIndexes, byExtendingSelection: false)
        }
        else {
            selectedIndexes = IndexSet()
            deselectAll(self)
        }
        changeDisplayedLink(theIndex)
        useSelectionChangeHander = true
    }
    
    // non private method for reloading, picking an index, and sending a notification
    func reloadAndSetIndex(_ theIndex:UInt) -> Bool {
        if theIndex >= rowCount { return false }
        reloadAndPickIndex(theIndex)
        return true
    }
    
    
}


