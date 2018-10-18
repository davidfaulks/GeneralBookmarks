//
//  widgets.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-03-16.
//  Copyright © 2016 dfaulks. All rights reserved.
//
// last update May 25, 2016

import Foundation
import Cocoa


// widgets for this app
//
/* Intended to be a simple text-based list view. Cocoa provides plenty of complex UI Widgets, but 
is lacking in simple convenience classes. */

// protocol for having the displayed strings come from an external source
@objc protocol GB_StringListViewDelegate {
    var itemCount:UInt { get }
    func getStringAtIndex(_ index:UInt) -> String?
    var attachedListBox:GB_StringListView? { get set}
    @objc optional func moveRow(_ fromRow:Int, toRow:Int) -> Bool
    @objc optional func selectionChange(_ newSelection:Int, oldSelection:Int)
    @objc optional func handleExternalDrop(_ dropSource:AnyObject, typeString:String, sourceIndexes:IndexSet, toRow:Int) -> Bool
    @objc optional func validateExternalDrop(_ table:NSTableView, info:NSDraggingInfo, toRow:Int) -> NSDragOperation
}

// I have to subclass NSTableView to allow enabling/disabling row drag and drop, it seems
class GB_DragDisablable_TableView : NSTableView {
    var canDragRows:Bool = false
    
    override func canDragRows(with rowIndexes: IndexSet, at mouseDownPoint: NSPoint) -> Bool {
        if canDragRows { return super.canDragRows(with: rowIndexes, at: mouseDownPoint) }
        else { return false }
    }
}

// the data source can be from an internal string list, or from a delegate
class GB_StringListView : NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    
    // the data source deletgate
    var delegate:GB_StringListViewDelegate? = nil
    // the internal table
    fileprivate var table:GB_DragDisablable_TableView? = nil
    fileprivate var column:NSTableColumn? = nil
    
    // +++ [ Initialization ] ++++++++++++++++++++++++++++++++++++
    // shared setup
    fileprivate func sharedSetup() {
        let cvsize = contentSize
        // creating the table and setting it up.
        let tableFrame = NSRect(x: 0, y: 0, width: cvsize.width - 16, height: cvsize.width)
        table = GB_DragDisablable_TableView(frame: tableFrame)
        column = NSTableColumn()
        column!.minWidth = 50.0
        column!.isEditable = false
        table!.addTableColumn(column!)
        table!.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table!.delegate = self
        table!.dataSource = self
        table!.headerView = nil
        table!.setContentHuggingPriority(750, for: .vertical)
        
        table!.autoresizesSubviews = true
        
        // scrollview setup, which is a colossal pain
        self.hasVerticalScroller = true
        self.hasHorizontalScroller = false
        self.translatesAutoresizingMaskIntoConstraints = false
        self.contentView.autoresizingMask = [.viewHeightSizable,.viewWidthSizable]
        
        self.documentView = table
        table!.allowsEmptySelection = false
    }
    var internalTable:NSTableView? {
        get { return table }
    }
    
    
    // initializers, some of which are required for no good reason
    required init?(coder:NSCoder) {
        super.init(coder:coder);
        sharedSetup()
    }
    override init(frame aRect:CGRect) {
        super.init(frame:aRect)
        sharedSetup()
    }
    // this should not be necessary...
    func sizeColumn() {
        // table!.sizeLastColumnToFit()
    }
    
    // +++ [ Row Selection ] ++++++++++++++++++++++++++++++++++++++
    // for simplicity, I've decided to disallow multiple selection (selection is still a pain)
    // for deselection, if you want to know where it happened, we need to keep track of the selection index
    fileprivate var selectionIndex:Int = -1
    fileprivate var noSignal1:Bool = false // optionally turned on to block change selection handlers
    fileprivate var noSignal2:Bool = false // always turned on when reloading tables to avoid issues
    
    // getting selection info read-only properties
    var selectedIndex:Int {
        get { return table!.selectedRow }
    }
    var selectedUIndex:UInt? {
        get {
            let xres = table!.selectedRow
            if xres < 0 { return nil }
            else { return UInt(xres) }
        }
    }
    var latestSelectedString:String? {
        get {
            let xres = table!.selectedRow
            if (xres<0) || (delegate == nil) { return nil }
            return delegate!.getStringAtIndex(UInt(xres))
        }
    }
    /* SelectRowIndexes does not trigger shouldSelectRow, so we have a helper
        method to send a selection will change manually. no checking done */
    fileprivate func sendSelectionChange(_ newRow:Int) {
        let oldIndex = selectionIndex
        selectionIndex = newRow
        delegate?.selectionChange?(newRow, oldSelection: oldIndex)
    }
    
    // changing the selection, returns false if the selection is invalid
    func changeSelection(_ toIndex:Int, _ triggerSignal:Bool) -> Bool {
        // checking for edge cases (no delegate or invalid index)
        if delegate == nil { return (toIndex < 0) }
        if toIndex > Int(delegate!.itemCount) { return false }
        // correct cases
        noSignal1 = true  // this might be unneeded
        if (toIndex<0) { table!.deselectAll(self) }
        else { table!.selectRowIndexes(IndexSet(integer:toIndex), byExtendingSelection: false) }
        let xIndex = (toIndex < 0) ? -1 : toIndex
        noSignal1 = false
        if triggerSignal { sendSelectionChange(xIndex) }
        return true
    }
    // a version of change selection that takes UInt or nil
    func changeSelection(_ toIndex:UInt?, _ triggerSignal:Bool) -> Bool {
        let intIndex = (toIndex == nil) ? -1 : Int(toIndex!)
        return changeSelection(intIndex, triggerSignal)
    }
    // simplified deselect
    func deSelect(_ triggerSignal:Bool) {
        changeSelection(-1, triggerSignal)
    }
    
    // annoyingly, tableViewSelectionDidChange refuses to work
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        let oldSelection = selectionIndex
        selectionIndex = row
        if !(noSignal1 || noSignal2) {
            delegate?.selectionChange?(row, oldSelection: oldSelection)
        }
        return true
    }
    
    // returns a new selection if a row is deleted
    func getNewSelectionAfterRowDelete(_ rowToDelete:UInt) -> Int {
        // bad cases
        assert(delegate != nil)
        if rowToDelete >= delegate!.itemCount { return -1 }
        // also return nil, but for a good reason...
        if selectedUIndex == nil { return -1 }
        if (delegate!.itemCount) < 2 { return -1}
        // getting the current selection index
        let currentIndex = selectedUIndex!
        let resultIndex:UInt
        if currentIndex < rowToDelete { resultIndex = currentIndex }
        else if currentIndex > rowToDelete { resultIndex = currentIndex - 1 }
        else if currentIndex == (delegate!.itemCount - 1) { resultIndex = currentIndex - 1 }
        else { resultIndex = currentIndex }
        
        return Int(resultIndex);
    }    
    
    // +++ [ wrappers used for context menus ] ++++++++++++++++++++
    var clickedRow:Int {
        get { return table!.clickedRow }
    }
    var tableMenu:NSMenu? {
        get { return table!.menu }
        set(value) { table!.menu = value }
    }
    
    // +++ [ General methods ] ++++++++++++++++++++++++++++++++++++
    // reload with suppressed signal, and optional refresh
    func reloadData(_ refresh:Bool) {
        noSignal2 = true
        table!.deselectAll(self)
        table!.reloadData()
        if refresh { table!.display() }
        noSignal2 = false
    }
    
    // reload data and select row!
    func reloadAndSelect(_ rowIndex:Int, _ triggerSignal:Bool) -> Bool {
        // reloading first
        reloadData(false)
        // we might need to manually trigger a -1 deselection
        if rowIndex<0 {
            table!.display()
            if triggerSignal { sendSelectionChange(-1) }
            return true
        }
        // for a selection...
        // bad selection case
        if (delegate == nil) || (UInt(rowIndex) >= delegate!.itemCount) {
            selectionIndex = -1
            table!.display()
            return false
        }
        // things are okay
        if triggerSignal {
            table!.selectRowIndexes(IndexSet(integer:rowIndex), byExtendingSelection: false)
            table!.display()
            sendSelectionChange(rowIndex)
        }
        else {
            noSignal1 = true
            table!.selectRowIndexes(IndexSet(integer:rowIndex), byExtendingSelection: false)
            table!.display()
            noSignal1 = false
        }
        return true
    }
    
    /* Simplified helper version of reload and select. It is known here that no change
     signal is wanted, rowIndex is >=0 (and in range) , and therefore delegate != nil */
    fileprivate func intReloadAndSelect(_ row:Int) {
        reloadData(false)
        noSignal1 = true
        table!.selectRowIndexes(IndexSet(integer:row), byExtendingSelection: false)
        table!.display()
        noSignal1 = false
    }
    
    /* load listview and pick zero if present */
    func loadPickZero(_ triggerSignal:Bool) -> Bool {
        let itemCount = (delegate?.itemCount) ?? 0
        reloadData(true)
        if itemCount > 0 {
            noSignal1 = true
            table!.selectRowIndexes(IndexSet(integer:0), byExtendingSelection: false)
            noSignal1 = false
            if (triggerSignal) { sendSelectionChange(0) }
            return true
        }
        else { return false }
    }
    
    // reloads one row only
    func reloadRow(_ theRow:UInt) -> Bool {
        if delegate == nil { return false }
        if theRow >= delegate!.itemCount { return false }
        table!.reloadData(forRowIndexes: IndexSet(integer:Int(theRow)), columnIndexes:IndexSet(integer:0))
        return true
    }
    
   
    // +++ [ Data Source delegate methods ] +++++++++++++++++++++++
    // number of items
    func numberOfRows(in tableView: NSTableView) -> Int {
        return Int(delegate?.itemCount ?? 0)
    }
    
    // cell based is the only type I can get to work.
    func tableView(_ tableView: NSTableView,objectValueFor tableColumn: NSTableColumn?, row: Int) -> Any? {
        assert(row>=0)
        return delegate?.getStringAtIndex(UInt(row))
    }
    
    // +++ [ Drag and Drop properties and methods ] +++++++++++++++
    
    /* There is no NSTableView distinction between drag-and-drop reordering rows, and
    dragging items in-and out of the table, but I think that distinction should be made. */
    
    // external drag and drop
    fileprivate var externalDragDrop:Bool = false
    var allowExternalDragDrop:Bool {
        get { return externalDragDrop }
        set(newValue) {
            externalDragDrop = newValue
            if newValue {
                table!.register(forDraggedTypes: [NSPasteboardTypeString])
                table!.canDragRows = true
            }
            else if (!dragReorder){
                table!.unregisterDraggedTypes()
                table!.canDragRows = false
            }
        }
    }

    // drag reordering
    fileprivate var dragReorder:Bool = false
    var allowDragReordering:Bool {
        get { return dragReorder }
        set(newValue) {
            dragReorder = newValue
            if newValue {
                table!.register(forDraggedTypes: [NSPasteboardTypeString])
                table!.canDragRows = true
            }
            else if (!externalDragDrop){
                table!.unregisterDraggedTypes()
                table!.canDragRows = false
            }
        }
    }
    // adding drag types for external drag and drop
    func addExternalDragTypes(_ newTypes:[String]) -> Bool {
        if !externalDragDrop { return false }
        let newDrag = [NSPasteboardTypeString] + newTypes
        table!.unregisterDraggedTypes()
        table!.register(forDraggedTypes: newDrag)
        return true
    }
    // clears external drag types (except for NSPasteboardTypeString)
    func resetExternalDragTypes() -> Bool {
        if !externalDragDrop { return false }
        table!.unregisterDraggedTypes()
        table!.register(forDraggedTypes: [NSPasteboardTypeString])
        return true
    }
    
    // the NSTableViewDataSource delegate methods for drag and drop
    
    // dragging is starting (generic)
    func tableView(_ tableView: NSTableView, writeRowsWith writeRowsWithIndexes: IndexSet, to toPasteboard: NSPasteboard) -> Bool {
        let data = NSKeyedArchiver.archivedData(withRootObject: writeRowsWithIndexes)
        toPasteboard.declareTypes([NSPasteboardTypeString], owner:self)
        toPasteboard.setData(data, forType:NSPasteboardTypeString)
        return true
    }
    // dragging is ongoing (generic)
    func tableView(_ tableView: NSTableView, validateDrop info: NSDraggingInfo, proposedRow row: Int, proposedDropOperation dropOperation: NSTableViewDropOperation) -> NSDragOperation {
        let dragFrom = info.draggingSource() as? NSTableView
        if dragFrom === table {
            tableView.setDropRow(row, dropOperation: NSTableViewDropOperation.above)
            return NSDragOperation.move
        }
        else {
            let dragReturn = delegate?.validateExternalDrop?(table!, info:info, toRow: row)
            return dragReturn ?? NSDragOperation()
        }
    }
    // helper function for accept drop (row reordering) below
    fileprivate func getIndexSetFromPasteboard(_ pasteboard:NSPasteboard) -> IndexSet? {
        if let rowData = pasteboard.data(forType: NSPasteboardTypeString) {
            let dataIndexes = NSKeyedUnarchiver.unarchiveObject(with: rowData) as! IndexSet
            if dataIndexes.count == 0 { return nil }
            else { return dataIndexes }
        }
        else { return nil }
    }
    // Helper function for an external drop, for this app, I'll assume the data is an IndexSet
    // the return type is (<pasteboard type>,<index set>)?
    fileprivate func getDragDataFromPasteboard(_ pasteboard:NSPasteboard) -> (String,IndexSet)? {
        // there can be more than one type of data, so we loop
        for testType in table!.registeredDraggedTypes {
            if let draggedData = pasteboard.data(forType: testType) {
                let data = NSKeyedUnarchiver.unarchiveObject(with: draggedData) as! IndexSet
                return (testType,data)
            }
        }
        // if we get here, we have nothing
        return nil
    }
    // drop. This is more complicated, because we distinguish between two types
    func tableView(_ tableView: NSTableView, acceptDrop info: NSDraggingInfo, row: Int, dropOperation: NSTableViewDropOperation) -> Bool {
        
        let pasteboard = info.draggingPasteboard()
        let dragSource = info.draggingSource() as? NSTableView
        
        // row reordering
        if (dragSource === table) && dragReorder {
            if let dataIndexes = getIndexSetFromPasteboard(pasteboard) {
                let okay = delegate?.moveRow?(dataIndexes.first!, toRow: row) ?? false
                // if the move is successful, we reload and select the correct index
                if (okay) {
                    let newRow =  (dataIndexes.first! < row) ? (row-1) : row
                    intReloadAndSelect(newRow)
                }
                return okay
            }
        }
        // external drag in
        else if ( dragSource !== table) && externalDragDrop {
            if let dragData = getDragDataFromPasteboard(pasteboard) {
                let dropResult = delegate?.handleExternalDrop?(dragSource! as AnyObject, typeString: dragData.0,
                                            sourceIndexes: dragData.1, toRow: row)
                // please note that handleExternalDrop should also handle any reloading and selecting
                return dropResult ?? false
            }
        }
        // we get here if nothing happens
        return false
    }
    
    
   
}
//================================================================================
