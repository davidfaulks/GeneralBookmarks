//
//  makeoutput.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2017-12-14.
//  Copyright © 2017-2019 dfaulks. All rights reserved.
//
// Classes that handle producing html output from input...
// these handle lower level parts of pages

import Foundation

// in general, #&<number># is replaced by the appropriate source string
let separatorKey = "SeparatorKey"
let overallKey = "OverallKey"

// to save repeated coding, a base class that includes overall and separator
class GB_OutputBase: NSObject,NSCoding {
    var separator:String = ""
    var overall:String = ""
    
    func encode(with aCoder: NSCoder) {
        aCoder.encode(separator, forKey: separatorKey)
        aCoder.encode(overall, forKey: overallKey)
    }
    
    convenience required init?(coder aDecoder: NSCoder) {
        self.init()
        separator = aDecoder.decodeObject(forKey: separatorKey) as! String
        overall = aDecoder.decodeObject(forKey: overallKey) as! String
    }
    
    func coreCopy(target:GB_OutputBase) {
        target.separator = separator
        target.overall = overall
    }
}

//=========================================================================================
// GB_SiteLink to formatted string
class GB_LinkOutputter: GB_OutputBase {
    var first_link:String = "" // #&0# is the url, #&1# is the link label
    var other_links:String = ""
    // #&0# in overall is the list of links, which is built up of single_links separated by separators
    
    // ++++ [ Converts a site link ] +++++++++++++++++++++++++++++
    func convertData(source:GB_SiteLink) -> String {
        if source.linkCount == 0 { return "" }
        // first links
        let rep1 = first_link.replacingOccurrences(of: "&#0#", with: source.getUrlAtIndex(0))
        var replacement = escapedHTMLfromText(source.getLinkLabelAtIndex(0), encodequotes: true)
        var linkList:String = rep1.replacingOccurrences(of: "&#1#", with: replacement)
        // additional linls
        if source.linkCount > 1 {
            for index in 1..<source.linkCount {
                linkList += separator
                let rep2 = other_links.replacingOccurrences(of: "&#0#", with: source.getUrlAtIndex(index))
                replacement = escapedHTMLfromText(source.getLinkLabelAtIndex(index), encodequotes: true)
                linkList += rep2.replacingOccurrences(of: "&#1#", with: replacement)
            }
        }
        // embedding the new link list in 'overall'
        return overall.replacingOccurrences(of: "&#0#", with: linkList)
    }
    
    // ++++ [ Coding related constants and Methods ] +++++++++++++
    fileprivate let firstLinkKey = "FirstLinkKey"
    fileprivate let otherLinkKey = "OtherLinkKey"
    
    // encode
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(first_link, forKey: firstLinkKey)
        aCoder.encode(other_links, forKey: otherLinkKey)
    }
    // decode
    required convenience init?(coder aDecoder:NSCoder) {
        self.init()
        first_link = aDecoder.decodeObject(forKey: firstLinkKey) as! String
        other_links = aDecoder.decodeObject(forKey: otherLinkKey) as! String
        separator = aDecoder.decodeObject(forKey: separatorKey) as! String
        overall = aDecoder.decodeObject(forKey: overallKey) as! String
    }
    
    func copyObject() -> GB_LinkOutputter {
        let result = GB_LinkOutputter()
        coreCopy(target: result)
        result.first_link = first_link
        result.other_links = other_links
        return result
    }
}
//=========================================================================================
// GB_LinkGroup to formatted string
class GB_GroupOutputter : GB_OutputBase {
    // separator : Separates the output of GB_LinkOutputter
    /* overall : &#0# is the group fragment-identifier, &#1# is the group name, and &#2# is the list of links */
    var addLineSeparator = true
    
    // ++++ [ Converts a group] +++++++++++++++++++++++++++++
    func convertData(source:GB_LinkGroup, basicLinkFormatter:GB_LinkOutputter, majorLinkFormatter:GB_LinkOutputter) -> String {
        // we build the list of links first, even if it is empty
        var linkList = ""
        let outputCount = source.countNonDepreciatedLinks
        if outputCount > 0 {
            var outputIndex = 0
            for linkDex in 0..<source.count {
                let currentLink = source.linkAtIndex(linkDex)!
                if currentLink.depreciated { continue } // we skip outputting these
                // we use 2 different formatters...
                if currentLink.important { linkList += majorLinkFormatter.convertData(source: currentLink) }
                else { linkList += basicLinkFormatter.convertData(source: currentLink) }
                outputIndex += 1
                // adding the separator
                if outputIndex < outputCount {
                    linkList += separator
                    if addLineSeparator { linkList += "\n" }
                }
            }
        }
        if addLineSeparator { linkList += "\n" }
        // we stick it in overall
        var intermediateResult = overall.replacingOccurrences(of: "&#2#", with: linkList)
        var replacement = escapedHTMLfromText(source.groupName, encodequotes: true)
        intermediateResult = intermediateResult.replacingOccurrences(of: "&#1#", with: replacement)
        // finishing off
        return intermediateResult.replacingOccurrences(of: "&#0#", with: source.fragmentID)
    }
    
    // ++++ [ Coding related constants and Methods ] +++++++++++++
    fileprivate let addLineSeparatorKey = "AddLineSeparatorKey"
    
    // encode
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(addLineSeparator, forKey: addLineSeparatorKey)
    }
    // decode
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
        separator = aDecoder.decodeObject(forKey: separatorKey) as! String
        overall = aDecoder.decodeObject(forKey: overallKey) as! String
        addLineSeparator = aDecoder.decodeBool(forKey: addLineSeparatorKey)
    }
    
    func copyObject() -> GB_GroupOutputter {
        let result = GB_GroupOutputter()
        coreCopy(target: result)
        result.addLineSeparator = addLineSeparator
        return result
    }
}
//=========================================================================================
// sometimes you will want to produce a special list of all major links on a page.
class GB_MajorLinksOutputter : GB_OutputBase {
    var major_link:String = "" // #&0# is the url, #&1# is the link label
    
    // ++++ [ Produces the results from all Major Links in a page ] ++++++++++++++++++
    func produceResults(source:GB_PageOfLinks) -> String {
        let groupCount = source.groups.count
        if groupCount == 0 { return "" }
        // looping over the groups, first to count the total output
        var linkList:String = ""
        var totalMajor:Int = 0
        for groupIndex in 0..<groupCount { totalMajor += source.groups[groupIndex].countMajorLinks }
        // now we loop over and output the links..
        var outputIndex:Int = 0
        for groupIndex in 0..<groupCount {
            for linkIndex in 0..<(source.groups[groupIndex].count) {
                // getting the current link, and likely skipping it
                let currentLink = source.groups[groupIndex].linkAtIndex(linkIndex)!
                if !currentLink.important { continue }
                if currentLink.depreciated { continue }
                if currentLink.isEmpty { continue }
                // here, we have a major link, so we output
                outputIndex += 1
                var rep1 = major_link.replacingOccurrences(of: "&#0#", with: currentLink.getUrlAtIndex(0))
                let replacement = escapedHTMLfromText(currentLink.getLinkLabelAtIndex(0), encodequotes: true)
                rep1 = rep1.replacingOccurrences(of: "&#1#", with: replacement)
                // adding it to a list
                linkList += rep1
                // maybe adding the separator
                if outputIndex < totalMajor { linkList += separator }
            }
        }
        // with the list done, we embed it in the contianer
        return overall.replacingOccurrences(of: "&#0#", with: linkList)
    }
    
    // ++++ [ Coding related constants and Methods ] +++++++++++++
    fileprivate let majorLinkKey = "MajorLinkKey"
    
    // encode
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(major_link, forKey: majorLinkKey)
    }
    // decode
    required convenience init?(coder aDecoder:NSCoder) {
        self.init()
        major_link = aDecoder.decodeObject(forKey: majorLinkKey) as! String
        separator = aDecoder.decodeObject(forKey: separatorKey) as! String
        overall = aDecoder.decodeObject(forKey: overallKey) as! String
    }
    
    func copyObject() -> GB_MajorLinksOutputter {
        let result = GB_MajorLinksOutputter()
        coreCopy(target: result)
        result.major_link = major_link
        return result
    }
}

//=========================================================================================
/* This class is used for producing a list of internal links to the groups withing the page */
class GB_GroupListOutputter : GB_OutputBase {
    var group_link:String = "" // #&0# is the fragment id, #&1# is the group name
 
    // ++++ [ Produces the results for all groups in a page ] ++++++++++++++++++
    func produceResults(source:GB_PageOfLinks) -> String {
        let groupCount = source.groups.count
        if groupCount == 0 { return "" }
        // looping over the groups
        var groupList:String = ""
        for groupIndex in 0..<groupCount {
            // getting the group, and converting and adding the link data
            let currentGroup = source.groups[groupIndex]
            let temp = group_link.replacingOccurrences(of: "&#0#", with: currentGroup.fragmentID)
            var replacement = escapedHTMLfromText(currentGroup.groupName, encodequotes: true)
            groupList +=  temp.replacingOccurrences(of: "&#1#", with: replacement)
            // adding the separator
            if groupIndex < (groupCount-1) { groupList += separator }
        }
        // with the list done, we embed it in the contianer
        return overall.replacingOccurrences(of: "&#0#", with: groupList)
    }
    
    fileprivate let groupLinkKey = "GroupLinkKey"
    
    // encode
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
        aCoder.encode(group_link, forKey: groupLinkKey)
    }
    // decode
    required convenience init?(coder aDecoder:NSCoder) {
        self.init()
        separator = aDecoder.decodeObject(forKey: separatorKey) as! String
        overall = aDecoder.decodeObject(forKey: overallKey) as! String
        group_link = aDecoder.decodeObject(forKey: groupLinkKey) as! String
    }
    
    func copyObject() -> GB_GroupListOutputter {
        let result = GB_GroupListOutputter()
        coreCopy(target: result)
        result.group_link = group_link
        return result
    }
}
//=========================================================================================
class GB_GroupSequenceOutputter : GB_OutputBase {
    
    // ++++ [ Converts a site link ] +++++++++++++++++++++++++++++
    func convertData(source:[GB_LinkGroup], groupFormatter:GB_GroupOutputter,basicLinkFormatter:GB_LinkOutputter, majorLinkFormatter:GB_LinkOutputter) -> String {
        if source.count == 0 { return "" }
        // we produce a list of groups with separators
        var groupDataList:String = ""
        for groupIndex in 0..<source.count {
            let convertedGroup = groupFormatter.convertData(source: source[groupIndex], basicLinkFormatter: basicLinkFormatter, majorLinkFormatter: majorLinkFormatter)
            groupDataList += convertedGroup + "\n"
            if groupIndex < (source.count - 1) { groupDataList += separator }
        }
        // embedding the new link list in 'overall'
        return overall.replacingOccurrences(of: "&#0#", with: groupDataList)
    }
    
    // encode
    override func encode(with aCoder: NSCoder) {
        super.encode(with: aCoder)
    }
    // decode
    required convenience init?(coder aDecoder:NSCoder) {
        self.init()
        separator = aDecoder.decodeObject(forKey: separatorKey) as! String
        overall = aDecoder.decodeObject(forKey: overallKey) as! String
    }
    
    func copyObject() -> GB_GroupSequenceOutputter {
        let result = GB_GroupSequenceOutputter()
        coreCopy(target: result)
        return result
    }
}



