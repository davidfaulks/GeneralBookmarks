//
//  urlutilities.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2016-08-13.
//  Copyright © 2016-2019 dfaulks. All rights reserved.
//

import Foundation

// when a site link check is done, it sends notifications
let NotifSiteCheckSingle = Notification.Name("NotifOneSiteChecked")
let NotifSiteCheckMultiple = Notification.Name("NotifASiteChecked")
let NotifSiteChecksDone = Notification.Name("NotifMultiSiteCheckDone")

// keys for notifications
let ChangeCountKey = "ChangeCount"
let LinkObjectKey = "LinkObject"

//====================================================================================
// class which wraps the complexities of checking GB_SiteLink. HTTP/HTTPS Only!
class GB_CheckSiteLink {
    // basic config
    private let config = URLSessionConfiguration.ephemeral
    private let session:URLSession
    private(set) weak var linkObjectPointer:GB_SiteLink? = nil
    // fetch/access data
    private var URLs:[URL?] = []
    private var tasks:[URLSessionDataTask?] = []
    private var results:[GB_LinkStatus] = []
    private var link_status_copy:[GB_LinkStatus] = []
    // when done, what do we do?
    let notifyOnEmpty:Bool
    let forMultiple:Bool
    var specialCallback:((_ checker:GB_CheckSiteLink)->Void)? = nil
    private(set) var alldone = false
    
    // keeping track of the count of done checks
    private let mutex = NSLock()
    private var checkC = 0
    private(set) var statusChanged = 0
    var checksDone:Int {
        get {
            mutex.lock()
            defer { mutex.unlock() }
            return checkC
        }
    }
    private func incrementAndCheckIfDone() -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        checkC += 1
        return (checkC == URLs.count)
    }
    private func qPrint(_ msg:String) {
        NSLog("Check \(linkObjectPointer!.getLinkLabelAtIndex(0)) : \(msg)")
    }
    //-----------------------------------------------------------------
    
    // inits and deinits
    init(notifyIfEmpty:Bool, multiple:Bool) {
        self.notifyOnEmpty = notifyIfEmpty
        self.forMultiple = multiple
        session = URLSession(configuration:config)
    }
    deinit {
        session.invalidateAndCancel()
    }
    //-----------------------------------------------------------------
    // private function to create a data task for the given index (make sure the index and its URL are valid first)
    private func makeTask(forIndex:Int) {
        // I will *not* check validity...
        let newTask = session.dataTask(with: URLs[forIndex]!, completionHandler: { (discard:Data?, response:URLResponse?, errval:Error?) in
            self.handleResponse(forIndex: forIndex, inResponse: response, inErr: errval)
            // finally, once done...
            if self.incrementAndCheckIfDone() {
                self.dispatchDone()  // only called when all of the links are checked (unless they are invalid)
            }

        })
        tasks.append(newTask)
    }
    // --------------------------------------------------
    // the function that sets up the checks, given a link object
    func willCheckLinkObject(_ linkObject:GB_SiteLink) -> Bool {
        self.linkObjectPointer = linkObject
        // turning the string urls to URL objects, and marking them as valid (.Unchecked) or invalid (.Invalid)
        var tempURL:URL? = nil
        for linkIndex in 0..<linkObjectPointer!.linkCount {
            tempURL = URL(string:linkObjectPointer!.getUrlAtIndex(linkIndex))
            URLs.append(tempURL)
            if tempURL == nil { results.append(.Invalid) }
            else {
                let proto = tempURL!.scheme!.lowercased()
                if (proto == "http") || (proto == "https") {
                    results.append(.Unchecked)
                }
                else { results.append(.Invalid)}
            }
        }
        // setting up the tasks array, the item is nil if the correspoding URL is invalid)
        var checkCount:Int = 0
        for taskIndex in 0..<linkObjectPointer!.linkCount {
            if results[taskIndex] == .Unchecked {
                makeTask(forIndex: taskIndex)
                checkCount += 1
            }
            else { tasks.append(nil) }
        }
        // afterwards, we might have nothing to check...
        return (checkCount > 0)
    }
    //-------------------------------------------------------
    // starts the checks
    func check() -> Bool {
        checkC = 0
        statusChanged = 0
        // invalid urls mean the associated 'task' is nil and therefore 'already done'
        for taskIndex in 0..<tasks.count {
            if tasks[taskIndex] == nil { checkC += 1}
        }
        // we might return false if there is nothing to do
        if checkC == tasks.count { return false }
        // otherwise, start the valid tasks
        for startTaskIndex in 0..<tasks.count {
            if tasks[startTaskIndex] != nil {
                tasks[startTaskIndex]!.resume()
            }
            else {
                // 2 different ways to get the original status of this URL
                let xstatus:GB_LinkStatus
                if link_status_copy.count > 0 { xstatus = link_status_copy[startTaskIndex] }
                else { xstatus = linkObjectPointer!.getStatusAtIndex(startTaskIndex) }
                
                // if we will not check the link, record if the status (probably .Invalid) differs
                if results[startTaskIndex] != xstatus {
                    statusChanged += 1
                }
            }
        }
        return true
    }
    // --------------------------------------------------
    // one-method wrapper that does all you need
    func doFullCheck(linkObject:GB_SiteLink) {
        link_status_copy = linkObject.startCheckGetStatuses()
        let validx = self.willCheckLinkObject(linkObject)
        if validx { self.check() }
        else {
            linkObjectPointer!.checking = false
            // preparing the notification info
            if notifyOnEmpty {
                let notifyData:[String:Any] = [ChangeCountKey:0,LinkObjectKey:linkObjectPointer!]
                let notifName = forMultiple ? NotifSiteCheckMultiple : NotifSiteCheckSingle
                NotificationCenter.default.post(name: notifName, object: self, userInfo: notifyData)
            }
            alldone = true
            specialCallback?(self)
        }
    }
    
    //-----------------------------------------------
    
    // when done...
    private func dispatchDone() {
        let changed = (statusChanged > 0)
        if notifyOnEmpty || changed {
            // preparing the notification info
            let notifyData:[String:Any] = [ChangeCountKey:statusChanged,LinkObjectKey:linkObjectPointer!]
            let notifName = forMultiple ? NotifSiteCheckMultiple : NotifSiteCheckSingle
            // sending the notification

            _ = linkObjectPointer!.replaceStatusesEndCheck(newStatuses: self.results)
            NotificationCenter.default.post(name: notifName, object: self, userInfo: notifyData)
        }
        else {
            linkObjectPointer!.checking = false
        }
        // we might also execute a block!
        alldone = true
        specialCallback?(self)
    }
    
    //----------------------------------------------------------------
    // a function that handles the response from an url header
    private func handleResponse(forIndex:Int,inResponse:URLResponse?,inErr:Error?) {
        if let response = inResponse as? HTTPURLResponse,inErr == nil {
            let responseCode = response.statusCode
            switch responseCode {
                case 200...299,307,418: results[forIndex] = .Okay
                case 400,404,410,523,530: results[forIndex] = .Missing
                case 305,401,403,407,423,450: results[forIndex] = .Forbidden
                case 451,495,496,497,525,526: results[forIndex] = .Forbidden
                case 300...399: results[forIndex] = .Redirected
                default: results[forIndex] = .Failed
            }
        }
        // did not get any response: faliure!
        else {
            results[forIndex] = .Failed
        }
        // record status changes...
        if results[forIndex] != linkObjectPointer!.getStatusAtIndex(forIndex) {
            statusChanged += 1
        }
    }
    //---------------------------------------------------------
    // in order to be able to use the object, we can reset and clear some things
    public func reset() -> Bool {
        if !alldone { return false }
        mutex.lock()
        defer { mutex.unlock() }
        URLs = []
        tasks = []
        results = []
        link_status_copy = []
        alldone = false
        checkC = 0
        statusChanged = 0
        return true
    }

}
//====================================================================================
// when checking single links, I want to be able to start another check before the first one is done....
// so a class to manage that
class GB_SingleLinkChecker {
    private var startdex:Int = 0
    private var checkmap:[Int:GB_CheckSiteLink] = [:]
    
    func launchCheck(urldata:GB_SiteLink) {
        let checkObj = GB_CheckSiteLink(notifyIfEmpty: true, multiple: false)
        let startcopy = startdex
        checkObj.specialCallback = { (_ checker:GB_CheckSiteLink ) in
            self.checkmap[startcopy] = nil
        }
        checkmap[startdex] = checkObj
        startdex += 1
        checkObj.doFullCheck(linkObject: urldata)
    }
    
}
//---------------------------------------------------------------------------------
// for checking set of multiple links, we check more than one site at the same time
class GB_GroupLinkChecker {
    private let mutex = NSLock()
    private var checkers:[GB_CheckSiteLink] = []
    // the list of links to process
    private(set) var linklist:[GB_SiteLink] = []
    private(set) var linksStarted = 0
    private(set) var linksDone = 0
    private(set) var listName:String = ""
    // some more status properties
    private(set) var allDone:Bool = false
    var notActive:Bool {
        mutex.lock()
        defer { mutex.unlock()}
        return allDone || (linksStarted == 0)
    }
    
    // init with a specified number of checkers
    init(checkerCount:Int) {
        let acount = (checkerCount < 1) ? 1 : checkerCount
        for dex in 0..<acount {
            checkers.append(GB_CheckSiteLink(notifyIfEmpty: false,multiple: true))
            checkers[dex].specialCallback = { (_ checker:GB_CheckSiteLink ) in
                DispatchQueue.global(qos: .utility).async {
                    self.checkDone(checker: checker)
                }
            }
        }
    }
    
    // setting a list of links to check (cannot be done while a previous check is in progress
    public func setListToCheck(links:[GB_SiteLink], name:String) -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        if (linksStarted > 0) && (!allDone) { return false }
        linklist = links
        linksStarted = 0
        linksDone = 0
        allDone = false
        listName = name
        return true
    }
    
    // conveneince method that sets the list from a group
    public func setGroupToCheck(group:GB_LinkGroup) -> Bool {
        if group.count == 0 { return false }
        var listCopy:[GB_SiteLink] = []
        for dex in 0..<group.count { listCopy.append(group.linkAtIndex(dex)!) }
        return setListToCheck(links: listCopy, name: group.groupName)
    }
    // for unsorted links, since the array is internal to the link collection object
    public func setUnsortedToCheck(collection:GB_LinkCollection) -> Bool {
        if collection.unsortedLinkCount == 0 { return false }
        var listCopy:[GB_SiteLink] = []
        for dex in 0..<collection.unsortedLinkCount { listCopy.append(collection.linkAtIndex(dex)) }
        return setListToCheck(links: listCopy, name: "Unsorted Links")
    }
    
    // start checking using the already set list
    public func startChecks() -> Bool {
        mutex.lock()
        defer { mutex.unlock() }
        if (linklist.count == 0) { return false } // nothing to check
        if (linksStarted > 0) { return false } // already started
        // launch the checks
        let lauchAmount = min(linklist.count,checkers.count)
        for lindex in 0..<lauchAmount {
            checkers[lindex].doFullCheck(linkObject: linklist[lindex])
            linksStarted += 1
        }
        return true
    }
    
    
    // the core callback when a checker is done
    private func checkDone(checker:GB_CheckSiteLink) {
        mutex.lock()
        defer { mutex.unlock() }
        linksDone += 1
        // resetting the checker
        let index = checkers.index(where:{ (item) in (item === checker) })!
        let rok = checkers[index].reset()
        assert(rok)
        // if there are unstarted links, setup the checker with a new link to do
        if (linksStarted != linklist.count) {
            linksStarted += 1
            checkers[index].doFullCheck(linkObject: linklist[linksStarted-1])
        }
        // here, we are done
        else if (linksDone == linklist.count ){
            allDone = true
            let odata = ["listName":listName]
            NotificationCenter.default.post(name: NotifSiteChecksDone, object: self, userInfo: odata)
        }
    }
}



//====================================================================================