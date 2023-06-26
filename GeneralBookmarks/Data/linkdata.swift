//
//  linkdata.swift
//  GeneralBookmarks
//  Core classes and stuff for link data
//  Created by David Faulks on 2016-02-19.
//  Copyright © 2016-2019 dfaulks. All rights reserved.
//  Last July 17, 2019

import Foundation
import AppKit
//==========================================================
/* links can have a status as to validity */
enum GB_LinkStatus:String {
    case Unchecked
    case Invalid
    case Okay
    case Missing
    case Failed
    case Redirected
    case Forbidden
    case Mixed
}

// we will associate a colour for each LinkStatus
let GB_DarkerGreen = NSColor(red: 0.0, green: 0.6, blue: 0.0, alpha: 1.0)

func getColourForStatus(_ inStatus:GB_LinkStatus) -> NSColor {
    switch inStatus {
        case .Unchecked : return NSColor.black
        case .Invalid   : return NSColor.magenta
        case .Okay      : return GB_DarkerGreen
        case .Missing   : return NSColor.red
        case .Failed    : return NSColor.black
        case .Redirected: return NSColor.blue
        case .Forbidden : return NSColor.black
        case .Mixed     : return NSColor.brown
    }
}

//==========================================================
/* The purpose of this class is to hold a set of links (for a single 'site') */
class GB_SiteLink : NSObject,NSCoding {
    
    // the data  (the links, 0 is always the most important and usually the only one)
    fileprivate var linkURLs:[String] = []              // URLS
    fileprivate var linkLabels:[String] = []            // associated labels
    fileprivate var linkStatuses:[GB_LinkStatus] = []   // associated Status
    
    private(set) var status:GB_LinkStatus = .Invalid;
    var important:Bool = false                      // important link
    var depreciated:Bool = false;                   // hide the link (but keep it just in case)
    
    private var priv_checking:Bool = false
    private let mutex:NSLock = NSLock()
    
    var checking:Bool {
        get {
            mutex.lock()
            defer { mutex.unlock() }
            return priv_checking
        }
        set(value) {
            mutex.lock()
            defer { mutex.unlock() }
            priv_checking = value
        }
    }
    
    // ++++ [ Init ] +++++++++++++++++++++++++++++++++++++++++++++
    
    // the default initializer gives an empty SiteLink, but normally there is at least one URL
    convenience init(url:String, linkLabel inLinkLabel:String) {
        self.init();
        let apr = self.appendUrlAndLabel(url: url, label: inLinkLabel)
        assert(apr,"Initial url or label is empty (this is not allowed).")
    }
    
    // ++++ [ Coding related constants and Methods ] +++++++++++++
    fileprivate let linkUrlsKey = "LinkURLsKey"
    fileprivate let linkLabelsKey = "LinkLabelsKey"
    fileprivate let linkStatusesKey = "LinkStatusesKey"
    fileprivate let importantKey = "ImportantKey"
    fileprivate let depreciatedKey = "DepreciatedKey"
    
    // encode
    func encode(with aCoder: NSCoder) {
        // the first two arrays
        aCoder.encode(linkURLs, forKey: linkUrlsKey)
        aCoder.encode(linkLabels, forKey: linkLabelsKey)
        // enums are not directly encodeable, so we have to convert to string list first
        var statusStrings:[String] = []
        for currStatus in linkStatuses {
            statusStrings.append(currStatus.rawValue)
        }
        aCoder.encode(statusStrings, forKey: linkStatusesKey)
        // finishing
        aCoder.encode(important, forKey: importantKey)
        aCoder.encode(depreciated, forKey: depreciatedKey)
        
    }
    // decode
    required convenience init?(coder aDecoder: NSCoder) {
        self.init()
        linkURLs = aDecoder.decodeObject(forKey: linkUrlsKey) as! Array<String>
        linkLabels = aDecoder.decodeObject(forKey: linkLabelsKey) as! Array<String>
        let statusStrings = aDecoder.decodeObject(forKey: linkStatusesKey) as! Array<String>
        if (statusStrings.count != linkURLs.count) {
            assert(statusStrings.count == linkURLs.count, "Status string count does not match URL count!");
            linkStatuses = Array(repeating: .Unchecked, count: linkURLs.count)
        }
        else {
            for currStatusString in statusStrings {
                linkStatuses.append(GB_LinkStatus(rawValue: currStatusString)!)
                if linkStatuses.last! == .Okay {
                    linkStatuses.removeLast()
                    linkStatuses.append(.Unchecked)
                }
            }
        }
        important = aDecoder.decodeBool(forKey: importantKey)
        depreciated = aDecoder.decodeBool(forKey: depreciatedKey)
        assert(linkURLs.count == linkStatuses.count,"Number of links and numer of statuses do not match!")
        setMainStatus()
    }
    
    // the main status, based on the individual url statuses
    // .Invalid if there are none, .Mixed if they differ
    private func setMainStatus() {
        if (linkStatuses.count == 0) {
            status = .Invalid
            return
        }
        for sdex in 0..<linkStatuses.count {
            if (sdex == 0) { status = linkStatuses[sdex] }
            else if (status != linkStatuses[sdex]) {
                status = .Mixed
                break
            }
        }
    }
    
    
    // ++++ [Basic information methods] +++++++++++++++++++++++++
    
    // checks if the index is in range
    func indexInRange(_ index:Int) -> Bool {
        if (index<0) {return false}
        if (index>=linkLabels.count) {return false}
        return true
    }
    // assertion method to check if the index is within range
    fileprivate func assertInRange(_ index:Int) {
        assert(indexInRange(index),"GB_SiteLink: Index is not within range!")
    }
    
    // counts the number of links
    var linkCount:Int {
        return linkLabels.count
    }
    // returns true if the link count is 0
    var isEmpty:Bool {
        return (linkLabels.count == 0)
    }
    
    // returns the URL at the specified index
    func getUrlAtIndex(_ index:Int) -> String {
        assertInRange(index)
        return linkURLs[index]
    }
    
    // returns the label for the link at the specified index
    func getLinkLabelAtIndex(_ index:Int) -> String {
        assertInRange(index)
        return linkLabels[index]
    }
    
    // returns the status for the link at the specified index
    func getStatusAtIndex(_ index:Int) -> GB_LinkStatus {
        assertInRange(index)
        return linkStatuses[index]
    }
    // returns a copy of the status information, also also notes that we are startng checking
    func startCheckGetStatuses() -> [GB_LinkStatus] {
        mutex.lock()
        defer { mutex.unlock() }
        priv_checking = true
        return linkStatuses
    }
    //--------------------------------------------------------
    func replaceStatusesEndCheck(newStatuses:[GB_LinkStatus]) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        assert(linkStatuses.count == newStatuses.count, "LinkStatus counts do not match!")
        linkStatuses = newStatuses
        setMainStatus()
        priv_checking = false
        return true
    }
    // we use this to change an http link to an https one
    func updateHTTPS(index:Int) {
        mutex.lock()
        defer { mutex.unlock() }
        assertInRange(index)
        let insertx = linkURLs[index].index(linkURLs[index].startIndex, offsetBy: 4)
        linkURLs[index].insert("s", at: insertx)
    }
    
    
    // ++++ [Methods to change the contents ] +++++++++++++++++++++++++
    
    // sets the URL and label for an existing link
    func setUrlAndLabelAtIndex(_ index:Int, url inurl:String, label inlabel:String) -> Bool {
        assertInRange(index)
        if inurl.isEmpty {return false}
        if inlabel.isEmpty {return false}
        // okay here
        if (linkURLs[index] != inurl) {
            linkURLs[index] = inurl
            linkStatuses[index] = .Unchecked
        }
        linkLabels[index] = inlabel
        setMainStatus()
        return true
    }
    
    // sets just the URL for an existing link
    func setUrlAtIndex(_ index:Int, inurl:String) -> Bool {
        assertInRange(index)
        if inurl.isEmpty { return false }
        // okay here
        if linkURLs[index] != inurl {
            linkURLs[index] = inurl
            linkStatuses[index] = .Unchecked
            setMainStatus()
            return true
        }
        else { return false }
    }
    
    // sets just the label for an existing link
    func setLabelAtIndex(_ index:Int, inlabel:String) -> Bool {
        assertInRange(index)
        if inlabel.isEmpty { return false }
        // okay here
        if linkLabels[index] != inlabel {
            linkLabels[index] = inlabel
            return true
        }
        else { return false }
    }
    
    // gets the status of an existing link
    func setStatusAtIndex(_ index:Int, status instatus:GB_LinkStatus) {
        assertInRange(index)
        linkStatuses[index] = instatus
        setMainStatus()
    }
    
    
    // ++++ [ Methods to add,remove, and shuffle links ] +++++++++++++++++++++++++
    
    // add a new URL with label, the default status is .Unchecked
    func appendUrlAndLabel(url inurl:String, label inlabel:String) -> Bool {
        if inurl.isEmpty {return false}
        if inlabel.isEmpty {return false}
        linkURLs.append(inurl)
        linkLabels.append(inlabel)
        linkStatuses.append(.Unchecked)
        setMainStatus()
        return true
    }
    // insert a new URL with label at the specified index
    func insertLinkAtIndex(_ index:Int, url inurl:String, label:String) -> Bool {
        if inurl.isEmpty { return false }
        if label.isEmpty { return false }
        if (index < -1) || (index >= linkURLs.count) { return false }
        linkURLs.insert(inurl, at: index)
        linkLabels.insert(label, at: index)
        linkStatuses.insert(.Unchecked, at: index)
        setMainStatus()
        return true
    }
    
    // remove the URL and associated status and label
    func deleteLinkAtIndex(_ index:Int) {
        assertInRange(index)
        linkURLs.remove(at: index)
        linkLabels.remove(at: index)
        linkStatuses.remove(at: index)
        setMainStatus()
    }
    
    // moves a link in the array
    func moveLinkAtIndex(_ index:Int, toIndex:Int) {
        // bad cases
        assertInRange(index)
        assert(toIndex >= 0)
        assert(toIndex <= linkURLs.count)
        // do nothing case
        if index == toIndex { return }
        // getting the values to move
        let sourceURL = linkURLs.remove(at: index)
        let sourceLabel = linkLabels.remove(at: index)
        let sourceStatus = linkStatuses.remove(at: index)
        // calculating a new insertion point
        let insertIndex = (index < toIndex) ? (toIndex - 1) : toIndex
        // inserting
        linkURLs.insert(sourceURL, at: insertIndex)
        linkLabels.insert(sourceLabel, at:insertIndex)
        linkStatuses.insert(sourceStatus, at: insertIndex)
    }
    
    // +++ [ Extra ] +++
    // for use in sorting, sort by first url
    func orderedBefore(_ second:GB_SiteLink) -> Bool {
        // trivial special case: sorting empty objects (always after non-empty)
        if isEmpty { return false }
        else if second.isEmpty { return true }
        // we try to remove the protocol before doing string comparison
        let link1 = stripProtocol(inURL: linkURLs[0])
        let link2 = stripProtocol(inURL: second.linkURLs[0])
        // finally, compare
        return link1 < link2
    }
   
}
//==========================================================
// function for checking if two GB_SiteLink objects have any identical URLS
enum SameURLResult { case none; case some; case all}

func checkForSameURLs(linkone:GB_SiteLink, linktwo:GB_SiteLink) -> SameURLResult {
    // trivial case 1
    if linkone.isEmpty || linktwo.isEmpty { return .none }
    // one URL makes things simpler
    if (linkone.linkCount == 1) && (linktwo.linkCount == 1) {
        let urleq = linkone.linkURLs[0] == linktwo.linkURLs[0]
        return (urleq) ? (.all) : (.none)
    }
    /* Multiple URLS makes for extra complication, The method below will handle
    cases where internal URLS are identical as well. */
    var onematch = Array(repeating: false, count: linkone.linkCount)
    var twomatch = Array(repeating: false, count: linktwo.linkCount)
    for onedex in 0..<linkone.linkCount {
        for twodex in 0..<linktwo.linkCount {
            let ceq = linkone.linkURLs[onedex] == linktwo.linkURLs[twodex]
            if ceq {
                onematch[onedex] = true
                twomatch[twodex] = true
            }
        }
    }
    // checking the match arrays to get the final result
    let onetrue = onematch.filter({$0 == true}).count
    let twotrue = twomatch.filter({$0 == true}).count
    if (onetrue == 0) && (twotrue == 0) { return .none }
    else if (onetrue == linkone.linkCount) && (twotrue == linktwo.linkCount) { return .all }
    else { return .some}
}

// takes an array of GB_SiteLink objects, sorts and removes duplicates
func makeFilteredSortedArray(sourceList:[GB_SiteLink]) -> [GB_SiteLink]? {
    if sourceList.count < 2 { return nil } // trivial do nothing
    // we go over the list to figure out what we might remove first
    var removeDuplicates = false
    print("Start Links: \(sourceList.count)")
    var keepLink = Array(repeating: true , count: sourceList.count)
    for odex in 0..<(sourceList.count-1) {
        for idex in (odex+1)..<sourceList.count {
            if !keepLink[idex] { continue }
            let compres = checkForSameURLs(linkone: sourceList[odex], linktwo: sourceList[idex])
            if compres == .all {
                removeDuplicates = true
                keepLink[idex] = false
            }
        }
    }
    // producing a new list for sorting
    var listToSort:[GB_SiteLink] = []
    if !removeDuplicates { listToSort = sourceList }
    else {
        for cdex in 0..<sourceList.count {
            if keepLink[cdex] { listToSort.append(sourceList[cdex]) }
        }
    }
    // sorting
    listToSort.sort(by: { $0.orderedBefore($1) } )
    return listToSort
}




