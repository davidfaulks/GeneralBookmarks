//****************************************************************
//
//  utilities.swift
//  GeneralBookmarks
//  Non-gui related helper classes and utilities
//  Created by David Faulks on 2016-04-30.
//  Copyright © 2016-2019 dfaulks. All rights reserved.
//  Last updated March 24, 2019

import Foundation
import AppKit

//****************************************************************
// a class that is mainly intended to let me extract link data
class GB_StringExtractor {
    
    // +++ [internal data and init ] ++++++++++++++++++++++++++++++++
    fileprivate let stringBase:String
    fileprivate var currentIndex:String.Index
    fileprivate var oldIndex:String.Index
    // the caseSensetive property has internal data and external setter and getter
    fileprivate var compOption:NSString.CompareOptions = NSString.CompareOptions.caseInsensitive
    fileprivate var isCaseSen = false;
    var caseSensentive:Bool {
        get { return isCaseSen }
        set(inCaseSen) {
            isCaseSen = inCaseSen
            if (!inCaseSen) { compOption = NSString.CompareOptions.caseInsensitive }
            else { compOption = []}
        }
    }
    fileprivate let defaultLocale:Locale
        
    // the default initializer needs a string to extract from
    init(inString:String) {
        stringBase = inString
        currentIndex = stringBase.startIndex
        oldIndex = stringBase.startIndex
        // I am not planning on supporting unusual case conversion
        defaultLocale = Locale(identifier: "en_US")
    }
    
    // +++ [ Basic informational methods and properties ] +++++++++++
    // read-only at end property
    var isAtEnd:Bool {
        return (currentIndex==stringBase.endIndex)
    }
    // unchangable string contents
    var string:String {
        return stringBase
    }
    
    // +++ [ Methods for moving the index and extracting strings ] ++
    
    // private helper function, because the rangeOfString is long
    fileprivate func getRangeFromCurrent(_ thisString:String) -> Range<String.Index>? {
        return stringBase.range(of: thisString, options: compOption, range: currentIndex..<stringBase.endIndex, locale: defaultLocale)
    }
    // looks for the next occurence of the input string, and if found, moves the currentIndex past it
    func movePast(_ thisString:String) -> Bool {
        // simple ‘always false’ cases
        if thisString.isEmpty {return false}
        if self.isAtEnd {return false}
        // searching for the substring from currentIndex
        if let foundRange = getRangeFromCurrent(thisString) {
            // if the substring is found, we move the index past it
            oldIndex = currentIndex
            currentIndex = foundRange.upperBound
            return true
        }
        // if the substring is not found, we do thing (except return false)
        else { return false }
    }
    
    // gets string up to a endString, and moves index past end string
    func getMovePast(_ endString:String) ->String? {
        // simple ‘always false’ cases
        if endString.isEmpty {return nil}
        if self.isAtEnd {return nil}
        // looking for the end String
        if let endRange = getRangeFromCurrent(endString) {
            let subStringRange = currentIndex..<endRange.lowerBound
            let resultString = String(stringBase[subStringRange])
            // setting the new index
            oldIndex = currentIndex
            currentIndex = endRange.upperBound
            // returning the result
            return resultString            
        }
        else { return nil }
    }
    
    /* a private helper version of get delimited, start to end */
    fileprivate func getDelimitedInternal(_ startDelimiter:String, _ endDelimiter:String) -> (outString:String, endIndex:String.Index)? {
        // looking for the start
        if let startRange = getRangeFromCurrent(startDelimiter) {
            // here, with start found, we look for the end
            if let endRange = stringBase.range(of: endDelimiter, options: compOption, range: startRange.upperBound..<stringBase.endIndex, locale: defaultLocale) {
                // extracting the substring
                let subStringRange = startRange.upperBound..<endRange.lowerBound
                let resultString = String(stringBase[subStringRange])
                // returning the result
                return (resultString,endRange.upperBound)
            }
            else { return nil }
            
        }
        else {return nil}
    }
    
    /* Extracts the substring between the next occurence of startDelimiter and the next ocurrence of endDelimiter after that.
       The returned value is nil if the delimiters are not found, a string (which might be empty) otherwise. */
    func getDelimitedSubString(_ startDelimiter:String, _ endDelimiter:String) -> String? {
        // simple 'always false' cases
        if startDelimiter.isEmpty { return nil}
        if endDelimiter.isEmpty { return nil }
        if self.isAtEnd { return nil }
        // the internal helper method does most of the work
        if let delimitedData = getDelimitedInternal(startDelimiter, endDelimiter) {
            oldIndex = currentIndex
            currentIndex = delimitedData.endIndex
            return delimitedData.outString
        }
        else { return nil }
    }
}
//**************************************************************************************************
// singleton class to help with string utils, by defining some complex constants in advance
class GBStringUtils {
    static let inst = GBStringUtils()
    
    private init() {
        attributedOptions = [NSAttributedString.DocumentReadingOptionKey.documentType: NSAttributedString.DocumentType.html, NSAttributedString.DocumentReadingOptionKey.characterEncoding: String.Encoding.utf8.rawValue]
        fragIDChars = CharacterSet(charactersIn: "#%^[]{}\\\"<>`|&").inverted
        filenameChars = CharacterSet(charactersIn: "#%^[]{}\\\"<>`|&;?").inverted
        metaCharExp = try! NSRegularExpression(pattern: metaCharPattern, options: .caseInsensitive)
        httpEquivExp = try! NSRegularExpression(pattern: httpEquivPattern, options: .caseInsensitive)
        xmlEncExp = try! NSRegularExpression(pattern: xmlencPattern, options: .caseInsensitive)
        html5Exp = try! NSRegularExpression(pattern: html5doctype, options: .caseInsensitive)
        latin9enc = CFStringEncoding(CFStringEncodings.isoLatin9.rawValue)
    }
    
    // for NSAttributedString html to text
    let attributedOptions:[NSAttributedString.DocumentReadingOptionKey:Any]
    // character sets for links
    let fragIDChars:CharacterSet
    let filenameChars:CharacterSet
    // regular expressions for getting html stuff
    let metaCharPattern = "<meta\\s+charset\\s*=\\s*\"([^\"]*)\""
    let httpEquivPattern = "<meta\\s+http-equiv\\s*=\\s*\"Content-Type\"\\s+content\\s*=\\s*\"\\s*text\\/html\\s*;\\s*charset\\s*=([^\"]*)\""
    let xmlencPattern = "<\\?xml\\s+version\\s*=\\s*\"1.0\"\\s+encoding\\s*=\\s*\"([^\"]*)\"\\?>"
    let html5doctype = "<!DOCTYPE\\s+html>"
    let metaCharExp:NSRegularExpression
    let httpEquivExp:NSRegularExpression
    let xmlEncExp:NSRegularExpression
    let html5Exp:NSRegularExpression
    
    // static helper functions
    // gets the NSRange of a swift string
    static func makeNSRange(for instring:String) -> NSRange {
        return NSRange(instring.startIndex...,in:instring)
    }
    // extracts a trimmed substring using an NSRange
    static func getSubString(from:String, using:NSRange) -> String? {
        guard let swrange = Range(using, in:from) else { return nil }
        let resultString = String(from[swrange])
        return resultString.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // does a regular expression search for the first item and returns the capture...
    static func getCapture(exp:NSRegularExpression, from target:String) -> String? {
        // some quick checks
        if target.isEmpty { return nil }
        if exp.numberOfCaptureGroups == 0 { return nil }
        let res1 = exp.firstMatch(in: target, options: [], range: makeNSRange(for: target))
        if res1 == nil { return nil }
        return getSubString(from: target, using: res1!.range(at: 1))
    }
    
    // special Latin-9 (ISO-8859-15) to String, since it is not supported by the built-in libs
    let latin9enc:CFStringEncoding
    
    static func convertFromLatin9(source:Data) -> String {
        var result:String = ""
        for byte in source {
            switch byte {
                // special cases
                case 164: result.append(Character(Unicode.Scalar(0x20AC)!))  // €
                case 166: result.append(Character(Unicode.Scalar(0x0160)!))  // Š
                case 168: result.append(Character(Unicode.Scalar(0x0161)!))  // š
                case 180: result.append(Character(Unicode.Scalar(0x017D)!))  // Ž
                case 184: result.append(Character(Unicode.Scalar(0x017E)!))  // ž
                case 188: result.append(Character(Unicode.Scalar(0x0152)!))  // Œ
                case 189: result.append(Character(Unicode.Scalar(0x0153)!))  // æ
                case 190: result.append(Character(Unicode.Scalar(0x0178)!))  // Ÿ
                // otherwise just like Unicode / Latin-1
                default: result.append(Character(Unicode.Scalar(byte)))
            }
        }
        return result
    }
}
//================================================================
// converts HTML string tp plain text by decoding entities and stripping tags, uses WebKit
func textFromHTML(_ inputString:String) -> String {
    let inputData = inputString.data(using: String.Encoding.utf8)!
    
    let attributedString:NSAttributedString
    do {
        attributedString = try NSAttributedString(data: inputData, options: GBStringUtils.inst.attributedOptions, documentAttributes: nil)
    }
    catch { return inputString }
    let resString = attributedString.string
    return resString.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
}
//----------------------------------------------------------------
// minimal plain text to text with html entitites escaped
func escapedHTMLfromText(_ inputString:String, encodequotes:Bool) -> String {
    var result:String = ""
    for char in inputString.unicodeScalars {
        if      char == "&" { result += "&amp"  }
        else if char == "<" { result += "&lt;"  }
        else if char == ">" { result += "&gt;"  }
        else if char == "\""{ result += (encodequotes) ? ("&quot;") : ("\"") }
        else if char == "\'"{ result += (encodequotes) ? ("&apos;") : ("\'") }
        else { result += String(char) }
    }
    return result;
}
//----------------------------------------------------------------
// for converting strings to string suitable for fragment identifiers
func stringToFragmentID(source:String) -> String {
    let tempString = source.replacingOccurrences(of: " ", with: "_")
    return tempString.addingPercentEncoding(withAllowedCharacters: GBStringUtils.inst.fragIDChars)!
}
//----------------------------------------------------------------
func stringToFilename(source:String) -> String {
    var tempString = source.replacingOccurrences(of: " ", with: "_")
    tempString = tempString.replacingOccurrences(of: ",", with: "_")
    tempString = tempString.replacingOccurrences(of: "&", with: "and")
    tempString = tempString.replacingOccurrences(of: "__", with: "_")
    tempString = tempString.addingPercentEncoding(withAllowedCharacters: GBStringUtils.inst.filenameChars)!
    return tempString + ".html"
}
//-----------------------------------------------------------------
// tests if a string has one of a set of prefixes, case insensetive
func hasAllowedPrefix(_ testURL:String) -> Bool {
    let allowedPrefixes = ["http:","https:","ftp:","ftps:","gopher:","sftp:"]
    let lowercaseInput = testURL.lowercased(with: Locale(identifier: "en_US"))
    // loop testing
    for currPrefix in allowedPrefixes {
        if lowercaseInput.hasPrefix(currPrefix) { return true }
    }
    return false
}
//--------------------------------------------------------------
// uses GB_String extractor to get a list of links from a web page
func extractLinksFromHTML(_ inputHTML:String) ->[GB_SiteLink] {
    // setting up
    var result:[GB_SiteLink] = []
    let extractor = GB_StringExtractor(inString:inputHTML)
    var currLink:GB_SiteLink? = nil
    // the extraction loop
    while extractor.movePast("<a ") {
        // trying to extract the url
        guard let url = extractor.getDelimitedSubString("href=\"", "\"") else { continue }
        if url.isEmpty { continue }
        // testing the url (certain protocols only)
        if !url.contains(":") { continue }
        if (!hasAllowedPrefix(url)) { continue }
        let unescURL = url.removingPercentEncoding!
        // here, we have a valid url, what is the label?
        guard let lLabel = extractor.getDelimitedSubString(">", "</a>") else { continue }
        let convertedLabel = textFromHTML(lLabel)
        let linkLabel = (convertedLabel.isEmpty) ? "(No Link Text)" : convertedLabel
        // building a site to add
        currLink = GB_SiteLink(url: unescURL, linkLabel: linkLabel)
        result.append(currLink!)
    }
    return result
}
//================================================================
/* Creates string from text file. Output is a tuple, first being
 a successful or not bool, second the string (result if successful,
 error message if not). */
func loadFileToString(_ filepath:String) -> (Bool, String) {
    let filemgr = FileManager.default
    if filemgr.fileExists(atPath: filepath) {
        _ = loadHTMLFileToString(filepath)
        do {
            let readFile = try String(contentsOfFile: filepath, encoding: String.Encoding.utf8)
            return (true,readFile)
        }
        catch let error as NSError {
            return (false,error.localizedDescription)
        }
    }
    else { return (false,"File not found.") }
}
//----------------------------------------------------------------
// annoying that there seems to be no built-in method to do this already..
func detectHTMLCharset(source:Data) -> (Int,String.Encoding) {
    // too short
    if source.count < 4 { return (-1,String.Encoding.ascii) } // bad result
    // checking for utf-16 or utf-32 via BOM
    if (source[0] == 0) || (source[0] == 0xFF) || (source[0] == 0xFE) {
        if (source[0] == 0xFE) && (source[1] == 0xFF) { return (0,String.Encoding.utf16BigEndian) } // big endian utf-16
        else if (source[0] == 0xFF) && (source[1] == 0xFE) {
            if (source[2] == 0) && (source[3] == 0 ) { return (0,String.Encoding.utf32LittleEndian) }
            else { return (0,String.Encoding.utf16LittleEndian) }
        }
        else if (source[0] == 0) && (source[1] == 0) {
            if (source[2] == 0xFE) && (source[3] == 0xFF) { return (0,String.Encoding.utf32BigEndian) }
        }
    }
    // checking the string contents
    let asciidata:String
    let q_asciidata = String(data: source, encoding: .windowsCP1252)
    if (q_asciidata == nil) { asciidata = String(data: source, encoding: .utf8)! }
    else { asciidata = q_asciidata! }
    var charsetString:String? = nil
    // trying to get a chartype string from meta tags
    charsetString = GBStringUtils.getCapture(exp: GBStringUtils.inst.metaCharExp, from: asciidata)
    if (charsetString == nil) {
        charsetString = GBStringUtils.getCapture(exp: GBStringUtils.inst.httpEquivExp, from: asciidata)
    }
    // fallback xml version
    if (charsetString == nil) {
        charsetString = GBStringUtils.getCapture(exp: GBStringUtils.inst.xmlEncExp, from: asciidata)
    }
    // if we have a meta tag charset...
    if (charsetString != nil) && (!(charsetString!.isEmpty)) {
        print("CharsetString: \(charsetString!)")
        // more general case
        let cfe = CFStringConvertIANACharSetNameToEncoding(charsetString! as CFString)
        if cfe != kCFStringEncodingInvalidId {
            // special cases, becuse String.Encoding is missing some useful charsets
            if cfe == GBStringUtils.inst.latin9enc {
                return (1,String.Encoding.ascii)
            }
            // using String.Encoding
            let nse = CFStringConvertEncodingToNSStringEncoding(cfe)
            return (0,String.Encoding(rawValue: nse))  // proper returned result
        }
    }
    // if we get here, we try to fallback on default encodings, which are different for html 5 and older
    let fres = GBStringUtils.inst.html5Exp.firstMatch(in: asciidata, options: [], range: GBStringUtils.makeNSRange(for: asciidata))
    // not found, charset latin-1
    if (fres == nil) { return (0,String.Encoding.isoLatin1) }
    else { return (0,String.Encoding.utf8) }
}
//---------------------------------------------------------------------------------
/* alternatve to loadFileToString for HTML files which tries to detect the character set... */
func loadHTMLFileToString(_ filepath:String) -> (Bool, String) {
    let filemgr = FileManager.default
    if filemgr.fileExists(atPath: filepath) {
        // loading mere data is annoyingly complex
        let xurl = URL.init(fileURLWithPath: filepath, isDirectory: false)
        let filedata:Data
        do { filedata = try Data.init(contentsOf: xurl) }
        catch {  return (false,"File failed to load : " + error.localizedDescription)  }
        // initial convert to string, assumi asci compatible charset
        let csetres = detectHTMLCharset(source: filedata)
        print("Charset code:\(csetres.0)  enc:\(csetres.1)")
        // default: using String.Encoding
        if csetres.0 == 0 {
            if let strRes = String(bytes: filedata, encoding: csetres.1) {
                return (true,strRes)
            }
            else { return (false,"Conversion to string failed") }
        }
        // special latin-9
        else if csetres.0 == 1 {
            return (true,GBStringUtils.convertFromLatin9(source: filedata))
        }
        else {
            return (false,"Could not find character set.")
        }
    }
    else { return (false,"File not found.") }
}


//================================================================
//  takes a single item in an array and moves it to a new position
func moveItemInArray<T>(_ array:inout Array<T>, fromIndex:Int, toIndex:Int) -> Bool {
    // quick checks for bad input
    if array.isEmpty { return false }
    if (fromIndex >= array.count) || (fromIndex < 0) { return false }
    if (toIndex > array.count) || (toIndex < 0) { return false }
    // special case
    if fromIndex == toIndex { return true }
    // general case
    let movedItem = array.remove(at: fromIndex)
    let toPosition = (fromIndex > toIndex) ? (toIndex) : (toIndex-1)
    array.insert(movedItem, at: toPosition)
    return true
}
//================================================================
/* This function is a generic for taking items from multiple positions 
 in an array, and inserting them at a particular spot in the same array */
func moveItemsInArray<T>(_ array:inout Array<T>, fromIndexes:IndexSet, toIndex:Int) -> Bool {
    // quick checks for bad input
    if array.isEmpty { return false }
    if toIndex > array.count { return false }
    if fromIndexes.last! >= array.count { return false }
    if toIndex < 0 { return false }
    // to do the reording properly, we need the values to move, and the proper insertion point
    var itemsToMove:Array<T> = []
    var insertPosition = toIndex
    // we loop backwards thru the indexes, removing (and saving) items and adjusting the insert point
    var currentIndex = fromIndexes.last
    while (currentIndex != nil) && (currentIndex != NSNotFound) {
        itemsToMove.insert(array.remove(at: currentIndex!), at: 0)
        if currentIndex! < toIndex { insertPosition -= 1 }
        currentIndex = fromIndexes.integerLessThan(currentIndex!)
    }
    // inserting the moved values
    array.insert(contentsOf: itemsToMove, at: insertPosition)
    // done
    return true    
}
//==================================================================
/* NSTextView does auto replace and spellchecking by default, and turning this off in the
 interface builder has no effect. */
func textViewRFix(textview:NSTextView) {
    textview.isAutomaticTextReplacementEnabled = false
    textview.isAutomaticDashSubstitutionEnabled = false
    textview.isAutomaticQuoteSubstitutionEnabled = false
    textview.isAutomaticSpellingCorrectionEnabled = false
}
//==================================================================
// strips protocol from url string
func stripProtocol(inURL:String) -> String {
    let f = inURL.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
    if f.count < 2 { return inURL }
    let second = String(f[1])
    if second.hasPrefix("//") { return String(second.dropFirst(2)) }
    else { return second }
}

//****************************************************************
