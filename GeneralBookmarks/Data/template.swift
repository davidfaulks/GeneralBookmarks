//
//  template.swift
//  GeneralBookmarks
//
//  Created by David Faulks on 2019-01-20.
//  Copyright © 2019 dfaulks. All rights reserved.
//

import Foundation

class GBTemplateOutputter: NSObject,NSCoding {
    var pageNav:GB_PageNavOutputter = GB_PageNavOutputter()
    var pageOutputter:GB_PageOutputter = GB_PageOutputter()
    var templateName:String = "(Default)"
    
    // ++ [ Making the results methods ] +++++++++++++++++++++++++++++++++
    // we do this in steps, so there can be GUI output
    private(set) var collectionToOutput:GB_LinkCollection? = nil
    private(set) var pageToOutputIndex:Int = -1
    private var outputDirectory:URL? = nil
    
    // initial output setup method
    func setupOutput(collection:GB_LinkCollection,targetDirectory:String) -> Bool {
        // validating the directory
        if !doesDirExist(path: targetDirectory) { return false }

        // setting the values...
        outputDirectory = URL(fileURLWithPath: targetDirectory, isDirectory: true)
        collectionToOutput = collection
        // clearing out old partial info
        pageNav.clearPages()
        pageToOutputIndex = -1
        // done
        return true;
    }
    
    // required for initializing the page nav outputter
    func buildPageNav() -> Bool {
        // initial checks
        if collectionToOutput == nil { return false }
        let pageCount = collectionToOutput!.listOfPages.count
        if pageCount == 0 { return false }
        // outputting
        for page in collectionToOutput!.listOfPages {
            if !page.notInNav { pageNav.addPage(page) }
        }
        return true;
    }
    
    // called async by output next page
    private func outputCurrentPage() -> Error? {
        // starting the output
        let pageToOutput = collectionToOutput!.listOfPages[self.pageToOutputIndex]
        let stringOutput = pageOutputter.makePage(page: pageToOutput, pageNavFormat: pageNav)
        let fileURL = outputDirectory!.appendingPathComponent(pageToOutput.filename)
        // writing...
        do {
            try stringOutput.write(to: fileURL, atomically: true, encoding: String.Encoding.utf8)
        }
        catch let error {
            return error
        }
        return nil
    }
    
    func outputNextPage(doWhenDone: ( (Bool,Error?)->Void )?) -> (Bool,String?) {
        // checking false conditions...
        if outputDirectory == nil { return (false,nil) }
        if collectionToOutput == nil { return (false,nil) }
        pageToOutputIndex += 1
        if pageToOutputIndex < 0 { return (false,nil) }
        if pageToOutputIndex >= (collectionToOutput!.listOfPages.count) { return (false,nil) }
        let pageoutName = collectionToOutput!.listOfPages[self.pageToOutputIndex].pageName
        // calling the method output method async
        DispatchQueue.global(qos: .utility).async {
            let outputResult = self.outputCurrentPage()
            doWhenDone?(outputResult == nil,outputResult)
        }
        return (true,pageoutName)
    }
    //------------------------------------------------------------------------

    // +++ [ Coding related constants and methods ] +++++++++++++++++++++++
    let pageNavOutputterKey = "PageNavOutputterKey"
    let pageOutputterKey = "PageOutputterKey"
    let templateNameKey = "TemplateNameKey"
    
    func encode(with aCoder: NSCoder) {
        // encoding subclasses
        aCoder.encode(pageNav, forKey:pageNavOutputterKey)
        aCoder.encode(pageOutputter, forKey:pageOutputterKey)
        // encoding simpler values
        aCoder.encode(templateName, forKey:templateNameKey)
    }
    
    convenience required init?(coder aDecoder: NSCoder) {
        self.init()
        // decoding subclasses (if there)
        pageNav = aDecoder.decodeObject(forKey:pageNavOutputterKey) as! GB_PageNavOutputter
        pageOutputter = aDecoder.decodeObject(forKey:pageOutputterKey) as! GB_PageOutputter
        // decoding simpler values
        templateName = aDecoder.decodeObject(forKey:templateNameKey) as! String

    }
    //-------------------------------------------------------------------
    func copyOutputter() -> GBTemplateOutputter {
        let result = GBTemplateOutputter()
        // copying complicated subvalues
        result.pageNav = pageNav.copyObject()
        result.pageOutputter = pageOutputter.copyObject()
        // simpler stuff
        result.templateName = templateName + " (copy)"
        return result
    }
}
//==========================================================
// link collection to and from file
func TemplateToFile(_ filepath:String, thisCollection:GBTemplateOutputter) -> Bool {
    let success = NSKeyedArchiver.archiveRootObject(thisCollection, toFile: filepath)
    return success
}
func fromFileToTemplate(_ filepath:String) -> GBTemplateOutputter? {
    // note that the documentation states that .unarchiveObjectWithFile can throw an exception
    // however, XCode states it does not
    let loadDed =  NSKeyedUnarchiver.unarchiveObject(withFile: filepath) as? GBTemplateOutputter
    return loadDed
}
