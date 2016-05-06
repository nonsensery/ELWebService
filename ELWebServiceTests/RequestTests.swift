//
//  RequestTests.swift
//  ELWebService
//
//  Created by Angelo Di Paolo on 3/11/15.
//  Copyright (c) 2015 WalmartLabs. All rights reserved.
//

import Foundation
import XCTest
@testable import ELWebService

///  Tests the functionality of the Request struct.
class RequestTests: XCTestCase {
    // MARK: Utilities
    
    /**
     Compares values of top-level keys for equality and asserts when unequal.
     Supports Int and String value types only.
    */
    static func assertRequestParametersNotEqual(parameters: [String: AnyObject], toOriginalParameters originalParameters: [String: AnyObject]) {
        
        for (name, originalValue) in originalParameters {
            let comparisonValue: AnyObject? = parameters[name]
            
            XCTAssert(comparisonValue != nil, "value should not be nil for key \(name)")
            
            if let originalValue = originalValue as? String,
                let comparisonValue = comparisonValue as? String {
                    XCTAssertEqual(originalValue, comparisonValue)
            } else if let originalValue = originalValue as? Int,
                let comparisonValue = comparisonValue as? Int {
                    XCTAssertEqual(originalValue, comparisonValue)
            } else {
                XCTFail("Failed to downcast JSON values for originalValue: \(originalValue) and \(comparisonValue)")
            }
        }
    }
    
    /// Creates a Request value for testing.
    static func CreateTestRequest() -> Request {
        let url = "http://httpbin.org/get"
        var request = Request(.GET, url: url)
        request.headers["Test-Header-Name"] = "testValue"
        return request
    }
    
    // MARK: Tests
    
    func test_urlRequestValue_encodedHeaderFields() {
        let request = RequestTests.CreateTestRequest()
        let urlRequest = request.urlRequestValue
        
        XCTAssertEqual(urlRequest.HTTPMethod!, request.method.rawValue)
        
        for (name, value) in request.headers {
            let resultingValue = urlRequest.valueForHTTPHeaderField(name)!
            XCTAssertEqual(value, resultingValue)
        }
    }
    
    func test_urlRequestValue_validURLWithEmptyParameters() {
        let request = Request(.GET, url: "http://httpbin.org/")
        let urlRequest = request.urlRequestValue
        let urlString = urlRequest.URL?.absoluteString
        
        XCTAssertNotNil(urlString)
        XCTAssertFalse(urlString!.containsString("?"))
    }
    
    func test_headerProperties_setValuesInTheCorrectHeaderFields() {
        let contentType = "application/json"
        let userAgent = "user agent value"
        
        var request = RequestTests.CreateTestRequest()
        request.contentType = contentType
        request.userAgent = userAgent
        
        XCTAssertEqual(request.headers["Content-Type"]!, contentType)
        XCTAssertEqual(request.headers["User-Agent"]!, userAgent)
        XCTAssertEqual(Request.Headers.userAgent, "User-Agent")
        XCTAssertEqual(Request.Headers.contentType, "Content-Type")
        XCTAssertEqual(Request.Headers.accept, "Accept")
        XCTAssertEqual(Request.Headers.cacheControl, "Cache-Control")
    }
    
    func test_headerProperties_getValuesFromTheCorrectHeaderFields() {
        let contentType = "application/json"
        let userAgent = "user agent value"
        var request = RequestTests.CreateTestRequest()
        
        request.headers["Content-Type"] = contentType
        request.headers["User-Agent"] = userAgent
        
        XCTAssertEqual(request.userAgent, userAgent)
        XCTAssertEqual(request.contentType, contentType)
    }
    
    func test_parameters_encodedInURLAsPercentEncoding() {
        var request = RequestTests.CreateTestRequest()
        let parameters = ["foo" : "bar", "paramName" : "paramValue", "percentEncoded" : "this needs percent encoded"]
        request.parameters = parameters
        request.parameterEncoding = .Percent
        
        let urlRequest = request.urlRequestValue
        let components = NSURLComponents(URL: urlRequest.URL!, resolvingAgainstBaseURL: false)!
        
        if let queryItems = components.queryItems {
            for item in queryItems {
                let originalValue = parameters[item.name]!
                XCTAssertEqual(item.value!, originalValue)
            }
            
        } else {
            XCTFail("queryItems should not be nil")
        }
        
        XCTAssertEqual((components.queryItems!).count, parameters.keys.count)
    }
    
    func test_parameters_encodedInBodyAsPercentEncoding() {
        var request = Request(.POST, url: "http://httpbin.org/")
        let parameters = ["percentEncoded" : "this needs percent encoded"]
        request.parameters = parameters
        request.parameterEncoding = .Percent
        
        let urlRequest = request.urlRequestValue
        
        let encodedData = urlRequest.HTTPBody
        XCTAssertNotNil(encodedData)
        
        let stringValue = NSString(data: encodedData!, encoding: NSUTF8StringEncoding)!
        let components = stringValue.componentsSeparatedByString("=")
        XCTAssertEqual(components[0], "percentEncoded")
        XCTAssertEqual(components[1], "this%20needs%20percent%20encoded")

        let contentType = urlRequest.valueForHTTPHeaderField("Content-Type")
        XCTAssertNotNil(contentType)
        XCTAssertEqual(contentType, "application/x-www-form-urlencoded")
    }

    func test_parameters_encodedInBodyAsJSON() {
        var request = Request(.POST, url: "http://httpbin.org/")
        let parameters = ["x" : "1"]
        request.parameters = parameters
        request.parameterEncoding = .JSON

        let urlRequest = request.urlRequestValue

        let content = urlRequest.HTTPBody
        XCTAssertNotNil(content)
        XCTAssertEqual(NSString(data: content!, encoding: NSUTF8StringEncoding)!, "{\"x\":\"1\"}")

        let contentType = urlRequest.valueForHTTPHeaderField("Content-Type")
        XCTAssertNotNil(contentType)
        XCTAssertEqual(contentType, "application/json")
    }

    func test_parameterEncoding_canBeSetBackToPercent() {
        var request = Request(.POST, url: "http://httpbin.org/")
        let parameters = ["x" : "1"]
        request.parameters = parameters

        // Setting the encoding to JSON should not "lock in" the body or content type:
        request.parameterEncoding = .JSON
        request.parameterEncoding = .Percent

        let urlRequest = request.urlRequestValue

        let content = urlRequest.HTTPBody
        XCTAssertNotNil(content)
        XCTAssertEqual(NSString(data: content!, encoding: NSUTF8StringEncoding)!, "x=1")

        let contentType = urlRequest.valueForHTTPHeaderField("Content-Type")
        XCTAssertNotNil(contentType)
        XCTAssertEqual(contentType, "application/x-www-form-urlencoded")
    }

    func test_contentType_explicitValueOverridesImplicitValue() {
        var request = Request(.POST, url: "http://httpbin.org/")
        let parameters = ["Percent Encoded" : "this needs percent encoded (%&=)"]
        request.parameters = parameters
        request.parameterEncoding = .Percent
        request.contentType = Request.ContentType.json

        let urlRequest = request.urlRequestValue

        let contentType = urlRequest.valueForHTTPHeaderField("Content-Type")
        XCTAssertEqual(contentType, "application/json")
    }

    func test_setBody_overwritesExistingBodyData() {
        var request = Request(.POST, url: "http://httpbin.org/")
        let parameters = ["percentEncoded" : "this needs percent encoded"]
        request.parameters = parameters
        request.parameterEncoding = .Percent
        let testData = "newBody".dataUsingEncoding(NSUTF8StringEncoding, allowLossyConversion: false)
        request.body = testData
        
        let urlRequest = request.urlRequestValue
    
        let encodedBody = urlRequest.HTTPBody
        XCTAssertNotNil(encodedBody)
        let stringValue = NSString(data: encodedBody!, encoding: NSUTF8StringEncoding)!
        let components = stringValue.componentsSeparatedByString("=")
        XCTAssertEqual(components.count, 1)
        XCTAssertEqual(encodedBody, testData)
    }
}
