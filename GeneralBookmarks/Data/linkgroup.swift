//
//  linkgroup.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2022-06-18.
//  Copyright © 2022 dfaulks. All rights reserved.
//

import Foundation

//==========================================================
/* Now, a class for holding multiple links. In addition to a simple list,
we also include a map, so we can find the index from the object (this is
useful while link checking, to find the index even if the link is moved). */
class GB_LinkGroup : NSObject, NSCoding {
    
    // the data (name, and list of links)
    var groupName:String = ""
    fileprivate var linkList:[GB_SiteLink] = []
    fileprivate var linkIndexLookup:Dictionary<GB_SiteLink,Int> = [:]
    private var fragment:String = ""
    private var splitsize = 0; // for auto-splitting groups
    
    var fragmentID:String {
        get {
            if fragment.isEmpty { return stringToFragmentID(source:groupName) }
            else { return fragment }
        }
        set(newValue) {
            if !newValue.isEmpty { fragment = stringToFragmentID(source:newValue) }
        }
    }
    
    // shorthand property
    var count:Int {
        return linkList.count
    }
    
    // +++++++++++++++++++++++++++++++++++++++++++++++++++++++++
    // group splitting
    
    var linksPerSplit:Int {
        get { return splitsize }
        set(newValue) {
            if (newValue < 0) { splitsize = 0 }
            else { splitsize = newValue }
        }
    }
    
    var numberOfSplitGroups:Int {
        if splitsize < 1 { return 1 }
        else {
            let outputLinks = self.countNonDepreciatedLinks
            if splitsize == 1 { return outputLinks }
            else if outputLinks < splitsize { return 1 }
            else {
                let groupcount = Double(outputLinks)/Double(splitsize)
                return Int(ceil(groupcount))
            }
        }
    }
    
    var groupWillSplit:Bool {
        return (numberOfSplitGroups > 1)
    }
    
    func makeSplitGroups() -> [GB_LinkGroup] {
        let groupCount = self.numberOfSplitGroups
        if groupCount == 1 { return [self] }
        else {
            // links per output group
            let outputLinks = self.countNonDepreciatedLinks
            let amountCount = Double(outputLinks)/Double(groupCount)
            let perAmount = Int(ceil(amountCount))
            
            var result:[GB_LinkGroup] = []
            var linkIndex = 0
            var addAmount = 0
            var groupCount = 0
            var currentList:[GB_SiteLink] = []
            
            repeat {
                repeat {
                    if !linkList[linkIndex].depreciated {
                        currentList.append(linkList[linkIndex])
                        addAmount += 1
                    }
                    linkIndex += 1
                } while (addAmount < perAmount) && (linkIndex < self.count)
                
                // group done
                groupCount += 1
                let newGroup = GB_LinkGroup(inName: groupName + " \(groupCount)")
                newGroup.appendLinkArray(currentList)
                result.append(newGroup)
                currentList = []
                addAmount = 0
                
            } while linkIndex < self.count
            
            return result
        }
    }

    
    // ++++ [ Dictionary Related methods ] +++++++++++++++++++++++
    fileprivate func updateLinkMapAfterIndex(_ fromIndex:UInt) {
        if fromIndex >= UInt(linkList.count) { return }
        for linkIndex in Int(fromIndex)..<linkList.count {
            linkIndexLookup[linkList[linkIndex]] = linkIndex
        }
    }
    func getIndexForLink(_ theLink:GB_SiteLink) -> Int {
        let index = linkIndexLookup[theLink]
        if index == nil { return -1 }
        else { return index! }
    }
    
    // ++++ [ add SiteLink methods ] +++++++++++++++++++++++++++++
    // inserts an array
    func insertLinks(_ links:Array<GB_SiteLink>, atIndex:Int) -> Bool{
        if (atIndex<0) || (atIndex > linkList.count) { return false }
        linkList.insert(contentsOf: links, at: atIndex)
        updateLinkMapAfterIndex(UInt(atIndex))
        return true
    }
    
    // inserts one link
    func insertLink(_ linkToInsert:GB_SiteLink, atIndex:Int) -> Bool {
        if atIndex > linkList.count { return false }
        if atIndex < 0 { return false }
        linkList.insert(linkToInsert, at: atIndex)
        updateLinkMapAfterIndex(UInt(atIndex))
        return true;
    }
    // appending links
    func appendLinkArray(_ linksToAppend:Array<GB_SiteLink>) {
        if linksToAppend.count == 0 { return }
        let newStart = UInt(linkList.count)
        linkList.append(contentsOf: linksToAppend)
        updateLinkMapAfterIndex(newStart)
    }
    func appendLink(_ linkToAppend:GB_SiteLink) {
        linkList.append(linkToAppend)
        linkIndexLookup[linkToAppend] = (linkList.count - 1)
    }
    
    
    
    // ++++ [ remove SiteLink methods ] ++++++++++++++++++++++++++
    // pulls out a selection of links, returning nil of there is something wrong
    func extractLinksAtIndexes(_ indexGroup:IndexSet) -> Array<GB_SiteLink>? {
        // nil cases
        if indexGroup.count == 0 { return nil }
        if indexGroup.first! < 0 { return nil }
        if indexGroup.last! > linkList.count { return nil }
        // going ahead, prep first
        var currentIndex = indexGroup.last
        var result:Array<GB_SiteLink> = []
        var extractedLink:GB_SiteLink? = nil;
        // remove items and build list to return
        while (currentIndex != nil) && (currentIndex != NSNotFound) {
            extractedLink = linkList.remove(at: currentIndex!)
            result.insert(extractedLink!, at: 0)
            linkIndexLookup.removeValue(forKey: extractedLink!)
            currentIndex = indexGroup.integerLessThan(currentIndex!)
        }
        updateLinkMapAfterIndex(UInt(indexGroup.first!))
        // done
        return result
    }
    // deleting one item from unsorted
    func deleteLink(_ atIndex:Int) -> Bool {
        if atIndex >= linkList.count { return false }
        let remlink = linkList.remove(at: atIndex)
        linkIndexLookup.removeValue(forKey: remlink)
        updateLinkMapAfterIndex(UInt(atIndex))
        return true
    }
    // removes *all* links. generally used when we are about to delete the group
    func extractAllLinks() ->[GB_SiteLink] {
        let result = linkList
        linkIndexLookup = [:]
        return result
    }
    
    // internal remove duplicates and sort
    func removeDuplicatesAndSort() -> Bool {
        guard let resList = makeFilteredSortedArray(sourceList: linkList) else {
            return false
        }
        linkList = resList
        updateLinkMapAfterIndex(0)
        return true
    }
    
    // ++++ [ other SiteLink Methods ] +++++++++++++++++++++++++++
    // reordering links in unsorted links
    func moveLinkInternally(_ fromIndex:Int, toIndex:Int) -> Bool {
        let xres = moveItemInArray(&linkList, fromIndex: fromIndex, toIndex: toIndex)
        if !xres { return false }
        updateLinkMapAfterIndex(UInt(fromIndex))
        return true
    }
    
    func moveLinksInternally(_ fromIndexes:IndexSet, toIndex:Int) -> Bool {
        let xres = moveItemsInArray(&linkList, fromIndexes: fromIndexes, toIndex: toIndex)
        if !xres { return false }
        updateLinkMapAfterIndex(UInt(fromIndexes.first!))
        return true
    }
    func linkAtIndex(_ index:Int) -> GB_SiteLink? {
        if index >= linkList.count { return nil }
        else { return linkList[index] }
    }
    
    // for getting a list of all links (violates protection, so be careful)
    func addLinks(toArray:inout [GB_SiteLink]) {
        toArray.append(contentsOf: linkList)
    }
    
    // checking to see if we have a duplicate. This prioritizes all over some
    func containsDuplicate(for_link:GB_SiteLink) -> SameURLResult {
        var currentResult:SameURLResult = .none
        var lookingForAll = false
        
        for checkedLink in linkList {
            let checkResult = checkForSameURLs(linkone: checkedLink, linktwo: for_link)
            if checkResult == .none { continue }
            else if checkResult == .all { return .all }
            // if we have a 'some' result, we start looking for all
            else if (checkResult == .some) && !lookingForAll {
                currentResult = .some
                lookingForAll = true
            }
        }
        return currentResult
    }
    
    // ++++ [ Coding related constants and Methods ] +++++++++++++
    fileprivate let groupNameKey = "GroupNameKey"
    fileprivate let linkListKey = "LinkListKey"
    fileprivate let fragmentKey = "FragmentKey"
    fileprivate let splitCountKey = "SplitCountKey"
    
    // encode
    func encode(with aCoder: NSCoder) {
        aCoder.encode(groupName, forKey: groupNameKey)
        aCoder.encode(linkList, forKey: linkListKey)
        aCoder.encode(fragment, forKey: fragmentKey)
        aCoder.encode(NSNumber(value: splitsize), forKey: splitCountKey)
    }
    // decode
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
        groupName = aDecoder.decodeObject(forKey: groupNameKey) as! String
        linkList = aDecoder.decodeObject(forKey: linkListKey) as! Array<GB_SiteLink>
        fragment = (aDecoder.decodeObject(forKey: fragmentKey) as? String) ?? ""
        let splitRaw = aDecoder.decodeObject(forKey: splitCountKey) as? NSNumber
        splitsize = splitRaw?.intValue ?? 0
        updateLinkMapAfterIndex(0)
    }
    
    // ---- [ Convenience Init ] -----
    
    convenience init(inName:String) {
        self.init()
        groupName = inName
    }
    
    // ---- [ Utility Methods ] ------
    
    // counts the number of links that are not depreciated
    var countNonDepreciatedLinks:Int {
        var runcount = 0;
        for currLink in linkList {
            if !currLink.depreciated  {runcount+=1}
        }
        return runcount
    }
    // counts major, non-depreciated links
    var countMajorLinks:Int {
        var runcount = 0
        for currLink in linkList {
            if (!currLink.depreciated) && (currLink.important) && (!currLink.isEmpty){
                runcount += 1
            }
        }
        return runcount
    }
    
    
}
//==========================================================
