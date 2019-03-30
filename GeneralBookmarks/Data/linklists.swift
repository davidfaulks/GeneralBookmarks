//
//  linklists.swift
//  GeneralBookmarks
//  Higher level groupings of links, including the class that holds an entire collection
//  Created by David Faulks on 2016-04-28.
//  Copyright © 2016-2019 dfaulks. All rights reserved.
//
// last updated August 15, 2016

import Foundation
//==========================================================
/* A class intended to hold a page's worth of link groups */
class GB_PageOfLinks: NSObject,NSCoding {
    // name and list of groups
    var pageName:String = ""
    var groups:[GB_LinkGroup] = []
    // filename...
    private var setFilename:String = ""
    var filename:String {
        get {
            if setFilename.isEmpty { return stringToFilename(source: pageName) }
            else { return setFilename }
        }
        set(newString) {
            if !newString.isEmpty { setFilename = newString }
        }
    }
    // special flag
    var notInNav:Bool = false
    
    // ++++ [ Coding related constants and Methods ] +++++++++++++
    fileprivate let pageNameKey = "PageNameKey"
    fileprivate let groupListKey = "GroupListKey"
    fileprivate let pageFileNameKey = "PageFileNameKey"
    fileprivate let notInNavKey = "NotInNavKey"
    
    // encode
    func encode(with aCoder: NSCoder) {
        aCoder.encode(pageName, forKey: pageNameKey)
        aCoder.encode(groups, forKey: groupListKey)
        aCoder.encode(setFilename, forKey: pageFileNameKey)
        aCoder.encode(notInNav, forKey: notInNavKey)
    }
    // decode
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
        pageName = aDecoder.decodeObject(forKey: pageNameKey) as! String
        groups = aDecoder.decodeObject(forKey: groupListKey) as! Array<GB_LinkGroup>
        setFilename = (aDecoder.decodeObject(forKey: pageFileNameKey) as? String) ?? ""
        notInNav = aDecoder.decodeBool(forKey: notInNavKey)
    }
    
    // +++ [ create with name ] +++++++++++++++++++++++++++++++++++
    convenience init(inName:String) {
        self.init()
        pageName = inName
    }
    
    // +++ [ Utility methods ] ++++++++++++++++++++++++++++++++++++
    
    var countLinks:UInt {
        get {
            var linkTotal = 0
            for currGroup in groups {
                linkTotal += currGroup.count
            }
            return UInt(linkTotal)
        }
    }
    
    func countNonDepreciatedLinks() -> UInt {
        var linkTotal = 0
        for currGroup in groups {
            linkTotal += currGroup.countNonDepreciatedLinks
        }
        return UInt(linkTotal)
    }
    
}


//==========================================================
/* A class that holds an entire link collection */
class GB_LinkCollection: NSObject,NSCoding {
    
    // the unsorted data
    fileprivate var unsortedLinks:[GB_SiteLink] = []
    fileprivate var unsortedLinkIndexMap:Dictionary<GB_SiteLink,Int> = [:]
    var unsortedLinkCount:Int {
        get { return unsortedLinks.count }
    }
    
    // a default page which is never output (to hold temporary groups)
    var defaultPage:GB_PageOfLinks? = nil;
    
    // list of pages
    var listOfPages:[GB_PageOfLinks] = []
    
    var collectionName:String = "LinkCollection"
    // +++ [ special map methods ] ++++++++++++++++++++++++++
    fileprivate func updateUnsortedMapAfterIndex(_ fromIndex:UInt) {
        if fromIndex >= UInt(unsortedLinkCount) { return }
        for unsortedIndex in Int(fromIndex)..<unsortedLinks.count {
            unsortedLinkIndexMap[unsortedLinks[unsortedIndex]] = unsortedIndex
        }
    }
    func indexForLink(_ theLink:GB_SiteLink) -> Int {
        let res = unsortedLinkIndexMap[theLink]
        if res == nil { return -1 }
        else { return res! }
    }
    
    // +++ [ Utility Methods ] +++++++++++++++++++++++++++++++
    // basic links access
    func linkAtIndex(_ index:Int) -> GB_SiteLink {
        assert(index>=0)
        assert(index<unsortedLinkCount)
        return unsortedLinks[index]
    }
    
    // pulling selected items out of unsortedLinks
    func extractLinksAtIndexes(_ indexGroup:IndexSet) -> Array<GB_SiteLink>? {
        // nil cases
        if indexGroup.count == 0 { return nil }
        if indexGroup.first! < 0 { return nil }
        if indexGroup.last! > unsortedLinks.count { return nil }
        // going ahead
        var currentIndex = indexGroup.last
        var result:Array<GB_SiteLink> = []
        var extractedItem:GB_SiteLink? = nil
        while (currentIndex != nil) && (currentIndex != NSNotFound) {
            extractedItem = unsortedLinks.remove(at: currentIndex!)
            unsortedLinkIndexMap.removeValue(forKey: extractedItem!)
            result.insert(extractedItem!, at: 0)
            currentIndex = indexGroup.integerLessThan(currentIndex!)
        }
        updateUnsortedMapAfterIndex(UInt(indexGroup.first!))
        // done
        return result
    }
    // reordering links in unsorted links
    func moveLinkInUnsorted(_ fromIndex:Int, toIndex:Int) -> Bool {
        let xres = moveItemInArray(&unsortedLinks, fromIndex: fromIndex, toIndex: toIndex)
        if !xres { return false }
        updateUnsortedMapAfterIndex(UInt(fromIndex))
        return true
    }
    
    func moveLinksInUnsorted(_ fromIndexes:IndexSet, toIndex:Int) -> Bool {
        let xres = moveItemsInArray(&unsortedLinks, fromIndexes: fromIndexes, toIndex: toIndex)
        if !xres { return false }
        updateUnsortedMapAfterIndex(UInt(fromIndexes.first!))
        return true
    }
    
    // inserting links
    func insertLinks(_ linksToInsert:Array<GB_SiteLink>, atIndex:Int) -> Bool {
        if linksToInsert.count == 0 { return false }
        if atIndex > unsortedLinkCount { return false }
        if atIndex < 0 { return false }
        // doing the actions
        unsortedLinks.insert(contentsOf: linksToInsert, at: atIndex)
        updateUnsortedMapAfterIndex(UInt(atIndex))
        return true
    }
    func insertLink(_ linkToInsert:GB_SiteLink, atIndex:Int) -> Bool {
        if atIndex > unsortedLinkCount { return false }
        if atIndex < 0 { return false }
        unsortedLinks.insert(linkToInsert, at: atIndex)
        updateUnsortedMapAfterIndex(UInt(atIndex))
        return true;
    }
    // appending links
    func appendLinkArray(_ linksToAppend:Array<GB_SiteLink>) {
        if linksToAppend.count == 0 { return }
        let newStart = UInt(unsortedLinks.count)
        unsortedLinks.append(contentsOf: linksToAppend)
        updateUnsortedMapAfterIndex(newStart)
    }
    func appendLink(_ linkToAppend:GB_SiteLink) {
        unsortedLinks.append(linkToAppend)
        unsortedLinkIndexMap[linkToAppend] = (unsortedLinks.count - 1)
    }
    
    // deleting one item from unsorted
    func deleteUnsortedSite(_ atIndex:Int) -> Bool {
        if atIndex >= unsortedLinkCount { return false }
        let remlink = unsortedLinks.remove(at: atIndex)
        unsortedLinkIndexMap.removeValue(forKey: remlink)
        updateUnsortedMapAfterIndex(UInt(atIndex))
        return true
    }
    
    
    //++++++++++++++++++++++++++++++++++++++++++++++++++++
    // pulling out a group from a certain page
    func takeGroupFromPage(_ pageIndex:UInt, atIndex:UInt) -> GB_LinkGroup? {
        if pageIndex >= UInt(listOfPages.count) { return nil }
        if atIndex >= listOfPages[Int(pageIndex)].countLinks { return nil }
        return listOfPages[Int(pageIndex)].groups.remove(at: Int(atIndex))
    }
    
    // ++++ [ Coding related constants and Methods ] +++++++++++++
    fileprivate let unsortedLinksKey = "UnsortedLinksKey"
    fileprivate let defaultPageKey = "DefaultPageKey"
    fileprivate let pagesListKey = "PagesListKey"
    fileprivate let collectionNameKey = "CollectionNameKey"
    
    // encode
    func encode(with aCoder: NSCoder) {
        aCoder.encode(unsortedLinks, forKey: unsortedLinksKey)
        if defaultPage == nil {
            aCoder.encode(NSNull(), forKey: defaultPageKey)
        }
        else {
            aCoder.encode(defaultPage!, forKey: defaultPageKey)
        }
        aCoder.encode(listOfPages, forKey: pagesListKey)
        aCoder.encode(collectionName, forKey: collectionNameKey)
    }
    // decode
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
        unsortedLinks = aDecoder.decodeObject(forKey: unsortedLinksKey) as! Array<GB_SiteLink>
        updateUnsortedMapAfterIndex(0)
        let testObject = aDecoder.decodeObject(forKey: defaultPageKey)!
        if let tempDefaultPage = testObject as? GB_PageOfLinks { defaultPage = tempDefaultPage }
        else { defaultPage = nil }

        listOfPages = aDecoder.decodeObject(forKey: pagesListKey) as! Array<GB_PageOfLinks>
        collectionName = aDecoder.decodeObject(forKey: collectionNameKey) as! String
    }
}
//==========================================================
// link collection to and from file
func linkCollectionToFile(_ filepath:String, thisCollection:GB_LinkCollection) -> Bool {
    let success = NSKeyedArchiver.archiveRootObject(thisCollection, toFile: filepath)
    return success
}
func fromFileToLinkCollection(_ filepath:String) -> GB_LinkCollection? {
    // note that the documentation states that .unarchiveObjectWithFile can throw an exception
    // however, XCode states it does not
    let loadDed =  NSKeyedUnarchiver.unarchiveObject(withFile: filepath) as? GB_LinkCollection
    return loadDed    
}
 
//==========================================================
