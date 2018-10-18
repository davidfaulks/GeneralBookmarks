//
//  GB_PageSplitData.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2018-01-05.
//  Copyright © 2018 dfaulks. All rights reserved.
//

import Cocoa

class GB_PageSplitData: NSView {
    
    @IBOutlet weak var explainLabel: NSTextField!
    @IBOutlet weak var columCountDisplay: NSTextField!
    @IBOutlet weak var columnCountStepper: NSStepper!
    @IBOutlet weak var columnCountLabel: NSTextField!
    
    @IBOutlet weak var majorSiteSizeEdit: NSTextField!
    @IBOutlet weak var majorSiteSizeLabel: NSTextField!
    
    @IBOutlet weak var groupSizeBufferEdit: NSTextField!
    @IBOutlet weak var groupSizeBufferLabel: NSTextField!
    
    //===============================================================
    
    private var columnCount:Int = 2
    var groupListsCount:Int {
        return columnCount
    }
    
    @IBAction func columnStepperChanged(_ sender: Any) {
        let ccStepValue = columnCountStepper.integerValue
        if columnCount != ccStepValue {
            columnCount = ccStepValue
            columCountDisplay.stringValue = "\(columnCount)"
        }
    }
    
    // saving data
    func saveDataToPageOutputter(_ target:GB_PageOutputter) {
        target.groupSetCount = columnCount
        target.majorLinkSize = majorSiteSizeEdit.floatValue
        target.groupPadding = groupSizeBufferEdit.floatValue
    }
    
    // loading data
    func loadDataFromOutputter(_ source:GB_PageOutputter) -> Bool {
        // loading column count
        let cc = source.groupSetCount
        if (cc < 0) || (cc > 9) { return false }
        columnCount = cc
        columCountDisplay.stringValue = "\(cc)"
        // size of major group links
        let mgl = source.majorLinkSize
        if (mgl <= 0.0) || (mgl >= 100.0) { return false }
        majorSiteSizeEdit.floatValue = mgl
        // group padding
        let gp = source.groupPadding
        if (gp < 0.0) || (gp >= 100.0) { return false }
        groupSizeBufferEdit.floatValue = gp
        // done
        return true
    }
    

    
    //================================================================
    @IBOutlet var contentView: NSView!
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        // Drawing code here.
    }
    
    override init(frame frameRect: NSRect) {
        super.init(frame:frameRect)
        commonInit()
    }
    
    required init?(coder decoder: NSCoder) {
        super.init(coder: decoder)
        commonInit()
    }
    // setting up custom widgets is a pain...
    private func commonInit() {
        var objs:NSArray?
        let ok = Bundle.main.loadNibNamed(NSNib.Name(rawValue: "GB_PageSplitData"), owner: self, topLevelObjects: &objs)
        assert(ok)
        addSubview(contentView)
        contentView.frame = self.bounds
        contentView.autoresizingMask = [NSView.AutoresizingMask.height,NSView.AutoresizingMask.width]
        // setting up the number formatter
    
    
    }
    
}
