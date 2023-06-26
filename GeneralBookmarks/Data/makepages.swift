//
//  makepages.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2017-12-23.
//  Copyright © 2017-2019 dfaulks. All rights reserved.
//
// Classes that handle producing html output from input...
// these handle page level and above

import Foundation
//======================================================================================
enum GB_PageNavOption:Int {
    case allSame; case current; case noCurrent
}
// useful for making a 'nav' of links to pages in the results
class GB_PageNavOutputter : GB_OutputBase {
    var page_link:String = "" // &#0# is the page filename, &#1# is the page name
    var currentPage:String = "" // used for the current page when navOption == .current.
    var navOption:GB_PageNavOption = .current
    // data that is loaded before making the output (and is not saved)
    private var pageNames:[String] = []
    private var pageFileNames:[String] = []
    var loadedCount:Int {
        return pageNames.count
    }
    
    func addPage(_ inPage:GB_PageOfLinks) {
        pageNames.append(inPage.pageName)
        pageFileNames.append(inPage.filename)
    }
    func clearPages() {
        pageNames = []
        pageFileNames = []
    }
    
    func makeOutput(forPageName:String) -> String {
        // getting some important values
        let pageCount = pageNames.count
        let currentIndex = pageNames.index(of: forPageName)
        let doingLast = (currentIndex == (pageCount - 1))
        var outputString = ""
        var tempLink = ""
        // looping over the page info
        for pageIndex in 0..<pageCount {
            let htmlPageName = escapedHTMLfromText(pageNames[pageIndex], encodequotes: true)
            // outputting the current link info
            if (pageIndex == currentIndex) && (navOption != .allSame) {
                if navOption == .noCurrent { continue }
                tempLink = currentPage.replacingOccurrences(of: "&#0#", with: pageFileNames[pageIndex])
                outputString += tempLink.replacingOccurrences(of: "&#1#", with: htmlPageName)
            }
            else {
                tempLink = page_link.replacingOccurrences(of: "&#0#", with: pageFileNames[pageIndex])
                outputString += tempLink.replacingOccurrences(of: "&#1#", with: htmlPageName)
            }
            // handling the separator
            if doingLast && (navOption == .noCurrent) && (pageIndex == (pageCount - 2)) { continue }
            if pageIndex < (pageCount - 1) { outputString += separator }
        }
        // done with thw loop, we now embed the list in overall and return
        return overall.replacingOccurrences(of: "&#0#", with: outputString)
    }
    
    // ++++ [ Coding related constants and Methods ] +++++++++++++
    fileprivate let pageLinkKey = "PageLinkKey"
    fileprivate let currentPageKey = "CurrentPageKey"
    fileprivate let navOptionKey = "PageNavOptionKey"
    
    // encode
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(page_link, forKey: pageLinkKey)
        aCoder.encode(currentPage, forKey: currentPageKey)
        aCoder.encode(navOption.rawValue, forKey: navOptionKey)
    }
    // decode
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
        separator = aDecoder.decodeObject(forKey: separatorKey) as! String
        overall = aDecoder.decodeObject(forKey: overallKey) as! String
        page_link = aDecoder.decodeObject(forKey: pageLinkKey) as! String
        currentPage = aDecoder.decodeObject(forKey: currentPageKey) as! String
        let navOptionRaw = aDecoder.decodeInteger(forKey: navOptionKey)
        navOption = GB_PageNavOption(rawValue: navOptionRaw)!
    }
    
    func copyObject() -> GB_PageNavOutputter {
        let result = GB_PageNavOutputter()
        coreCopy(target: result)
        result.page_link = page_link
        result.currentPage = currentPage
        result.navOption = navOption
        return result
    }
}
//======================================================================================
// produces a page of outputs
class GB_PageOutputter: NSObject,NSCoding {
    // sub-part formatters
    var majorLinkFormat:GB_LinkOutputter? = nil
    var linkFormatter:GB_LinkOutputter = GB_LinkOutputter()
    var groupFormatter:GB_GroupOutputter = GB_GroupOutputter()
    var bigLinksFormatter:GB_MajorLinksOutputter? = nil
    var groupBarFormatter:GB_GroupListOutputter? = nil
    var groupListFormatter:GB_GroupSequenceOutputter = GB_GroupSequenceOutputter()
    
    // data used at the page level
    /* Codes: &#0# is the page html filename, &#1# is the page name, &#2# is the page navigation,
     &#3# is the nav/bar containing links to the groups on this page, &#4# is for the list of major
     links, and &#0x# where x starts at 0, is for the lists of groups. */
    var overall:String = ""
    /* We try to break up the groups on a page into sub-lists, of roughly 'equal' size, with the size
     of a group being the link count plus padding. */
    private var ccount:Int = 2
    var groupSetCount:Int {
        get { return ccount }
        set(newValue) {
            if newValue > 0 { ccount = newValue }
        }
    }
    private var gpadding:Float = 4.0
    var groupPadding:Float {
        get { return gpadding }
        set(newVal) {
            if newVal > 0.0 { gpadding = newVal }
        }
    }
    private var mlinksize:Float = 1.0
    var majorLinkSize:Float {
        get { return mlinksize }
        set(newVal) {
            if newVal > 0.0 { mlinksize = newVal }
        }
    }
    
    // +++ [ Methods related to producing the output ] ++++++++++++++++++++
    private var groupSplit:[Int] = [] // number of groups per column/set
    
    // func calculateGroupSplit(usingPage page:GB_PageOfLinks) {
    func calculateGroupSplit(usingList groupList:[GB_LinkGroup]) {
        var groupSizes:[Float] = []
        var totalSize:Float = 0.0
        // we first calculate a size for each group
        for groupIndex in 0..<groupList.count {
            let currentGroup = groupList[groupIndex]
            // getting link counts
            let majorCount = currentGroup.countMajorLinks
            let minorCount = currentGroup.countNonDepreciatedLinks - majorCount
            // calculating a total group size
            let groupSize = Float(minorCount) + mlinksize*Float(majorCount) + gpadding
            groupSizes.append(groupSize)
            totalSize += groupSize
        }
        // calculating an average column/set size
        var columnSize = totalSize / Float(ccount)
        // determining how many groups in each column
        var runSize:Float = 0.0
        var groupRunCount:Int = 0
        var columnsLeft = ccount
        var sizeLeft:Float = totalSize
        // we go over the recorded size of each group
        for groupIndex in 0..<groupSizes.count {
            runSize += groupSizes[groupIndex]
            groupRunCount += 1
            // when the accumulated size is >= the column Size, we output the number of groups, and reset the totals
            if runSize >= columnSize {
                groupSplit.append(groupRunCount)
                columnsLeft -= 1
                // if there is only 1 column left, we are done...
                if columnsLeft == 1 {
                    groupSplit.append(groupList.count - groupRunCount)
                    return
                }
                groupRunCount = 0
                // calculating a new column size to make sure groups remain spread out
                sizeLeft = totalSize - runSize
                runSize = 0.0
                columnSize = sizeLeft / Float(columnsLeft)
            }
        }
        // done
    }
    
    // private helper method for producing a group list
    private func makeGroupList(/* page:GB_PageOfLinks,*/ groupList:[GB_LinkGroup], groupListIndex:Int, groupListStart:Int) -> String {
        // we assume the inputs are okay...
        // making a group slice
        let upperBound = groupListStart + groupSplit[groupListIndex]
        let workGroups = Array(groupList[groupListStart..<upperBound])
        let mlink = majorLinkFormat ?? linkFormatter
        return groupListFormatter.convertData(source: workGroups, groupFormatter: groupFormatter, basicLinkFormatter: linkFormatter, majorLinkFormatter: mlink)
    }
    
    // producing the output
    func makePage(page:GB_PageOfLinks, pageNavFormat:GB_PageNavOutputter?) -> String {
        let groupList = page.getAllSpltGroups()
        groupSplit = []
        calculateGroupSplit(usingList: groupList)
        // calculateGroupSplit(usingPage: page)
        // making the page nav bar (if there)
        let pageNav:String
        if pageNavFormat != nil {
            pageNav = pageNavFormat!.makeOutput(forPageName: page.pageName)
        }
        else { pageNav = "" }
        // we start producing the output
        var output = overall.replacingOccurrences(of: "&#0#", with: page.filename)
        output = output.replacingOccurrences(of: "&#1#", with: page.pageName)
        if pageNav != "" {
            output = output.replacingOccurrences(of: "&#2#", with: pageNav)
        }
        // the optional group bar and big Links
        if groupBarFormatter != nil {
            let groupBar = groupBarFormatter!.produceResults(groupListing: groupList)
            output = output.replacingOccurrences(of: "&#3#", with: groupBar)
        }
        if bigLinksFormatter != nil {
            let bigLinks = bigLinksFormatter!.produceResults(source: page)
            output = output.replacingOccurrences(of: "&#4#", with: bigLinks)
        }
        // columns/group output
        var groupIndex = 0
        for cIndex in 0..<groupSplit.count {
            let replaceThis = "&#0\(cIndex)#"
            /*
            let currentColumnString = makeGroupList(page:page, groupListIndex: cIndex, groupListStart: groupIndex)
             */
            let currentColumnString = makeGroupList(groupList: groupList, groupListIndex: cIndex, groupListStart: groupIndex)
            output = output.replacingOccurrences(of: replaceThis, with: currentColumnString)
            groupIndex += groupSplit[cIndex]
        }
        // done
        return output
    }
    
    // +++ [ Coding related constants and methods ] +++++++++++++++++++++++
    let majorLinkFKey = "MajorLinkFormatter"
    let linkFKey = "LinkFormatter"
    let groupFKey = "GroupFormatter"
    let majorlinksBarFKey = "MajorLinksNavFormatter"
    let groupNavFKey = "GroupNavBarFormatter"
    let groupListFKey = "GroupListFormatter"
    let overallKey = "OverallKey"
    let columnCountKey = "ColumnCountKey"
    let groupPaddingKey = "GroupPaddingKey"
    let majorLinkSizeKey = "MajorLinkSizeKey"

    func encode(with aCoder: NSCoder) {
        // encoding subclasses
        if majorLinkFormat != nil { aCoder.encode(majorLinkFormat!, forKey:majorLinkFKey) }
        aCoder.encode(linkFormatter, forKey:linkFKey)
        aCoder.encode(groupFormatter, forKey:groupFKey)
        if bigLinksFormatter != nil { aCoder.encode(bigLinksFormatter!, forKey:majorlinksBarFKey) }
        if groupBarFormatter != nil { aCoder.encode(groupBarFormatter!, forKey:groupNavFKey) }
        aCoder.encode(groupListFormatter, forKey:groupListFKey)
        // encoding simpler values
        aCoder.encode(overall,forKey:overallKey)
        print("Encode Column Count: \(ccount)")
        aCoder.encode(ccount, forKey: columnCountKey)
        aCoder.encode(gpadding, forKey: groupPaddingKey)
        aCoder.encode(mlinksize, forKey: majorLinkSizeKey)
    }
    
    convenience required init?(coder aDecoder: NSCoder) {
        self.init()
        // decoding subclasses (if there)
        majorLinkFormat = aDecoder.decodeObject(forKey: majorLinkFKey) as? GB_LinkOutputter
        linkFormatter = aDecoder.decodeObject(forKey: linkFKey) as! GB_LinkOutputter
        groupFormatter = aDecoder.decodeObject(forKey: groupFKey) as! GB_GroupOutputter
        bigLinksFormatter = aDecoder.decodeObject(forKey: majorlinksBarFKey) as? GB_MajorLinksOutputter
        groupBarFormatter = aDecoder.decodeObject(forKey: groupNavFKey) as? GB_GroupListOutputter
        groupListFormatter = aDecoder.decodeObject(forKey: groupListFKey) as! GB_GroupSequenceOutputter
        // decoding simpler values
        overall = aDecoder.decodeObject(forKey: overallKey) as! String
        let temp_ccount = aDecoder.decodeInteger(forKey: columnCountKey)
        assert(temp_ccount > 0)
        ccount = temp_ccount
        print("Decode Column Count: \(temp_ccount)")
        let temp_gpadding = aDecoder.decodeFloat(forKey: groupPaddingKey)
        assert(temp_gpadding > 0.0)
        gpadding = temp_gpadding
        let temp_mlinksize = aDecoder.decodeFloat(forKey: majorLinkSizeKey)
        assert(temp_mlinksize > 0.0)
        mlinksize = temp_mlinksize
    }
    
    func copyObject() -> GB_PageOutputter {
        let result = GB_PageOutputter()
        // copying complicated subvalues
        result.majorLinkFormat = majorLinkFormat?.copyObject()
        result.linkFormatter = linkFormatter.copyObject()
        result.groupFormatter = groupFormatter.copyObject()
        result.bigLinksFormatter = bigLinksFormatter?.copyObject()
        result.groupBarFormatter = groupBarFormatter?.copyObject()
        result.groupListFormatter = groupListFormatter.copyObject()
        // copying simpler subvalues
        result.overall = overall
        result.ccount = ccount
        result.gpadding = gpadding
        result.mlinksize = mlinksize
        return result
    }
    
}
