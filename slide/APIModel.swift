//
//  APIModel.swift
//  slide
//
//  Created by Justin Zollars on 1/28/15.
//  Copyright (c) 2015 rmb. All rights reserved.
//

import UIKit

// This class is responible for calls to the Snap API server


class APIModel: NSObject {
    
    // var url: NSString // no need (!). It will be initialised from controller
    var data: NSMutableData = NSMutableData()
//    var snapsResults: JSON = JSON()
    var accessToken: NSString = ""
    var apiUserId: NSString = ""
    // TODO rename to device token
    var userID: NSString = ""


    
    // It doesn't look like Userid is used, rather self.userID is used. This is set by a chain method call apiObject.userid
    // from the userObject.findUser() on ViewDidLoad. We always have a user, we find one, and with it from disk and we set
    // the userid, accesstoken and other info
    func getSnaps(lat:NSString,long:NSString, delegate:APIProtocol) {
        var requestUrl = "https://airimg.com/snaps?token=17975700jDLD5HQtiLbKjwaTkKmZK7zTQO8l5CEmktBzVEAtY&device_token=" + self.userID + "&access_token=" + self.accessToken + "&lat=" + lat + "&long=" + long
//        NSLog("getting Snaps")
//        self.getRequest(requestUrl)
        
        request(.GET, requestUrl)
            .responseJSON { (req, res, json, error) in
                if(error != nil) {
                    NSLog("GET Error: \(error)")
                    println(res)
                }
                else {
                    var json = JSON(json!)
                    NSLog("GET Result: \(json)")
                    
                    // Call delegate
                    delegate.didReceiveResult(json)
                }
        }
        
    }
    
    func createUser(Userid:NSString) {
      NSLog("********************************************** createUser() called with Device Token=%@", Userid)
      userID = Userid
      var requestUrl = "https://airimg.com/profiles/new?token=17975700jDLD5HQtiLbKjwaTkKmZK7zTQO8l5CEmktBzVEAtY&profile[device_token]=" + self.userID +  "&profile[email]=u@u.com&profile[password]=a&profile[os]=ios"
        self.postRequest(requestUrl)
    }
    
    func createSnap(lat:NSString,long:NSString,video:NSString,image:NSString){
        var requestUrl = "https://airimg.com/snaps/new?access_token=" + self.accessToken + "&token=17975700jDLD5HQtiLbKjwaTkKmZK7zTQO8l5CEmktBzVEAtY&snap[userId]=" + self.apiUserId +  "&snap[img]=" + image + "&snap[film]=" + video + "&snap[lat]=" + lat + "&snap[long]=" + long + "&device_token=" + self.userID
        NSLog("********************************************** createSnap() called with request url= ", requestUrl)
        self.postRequest(requestUrl)
    }
    
    func postRequest(url:String) {
        var url = url
        NSLog("url:%@", url)
        let fileUrl = NSURL(string: url)
        var request = NSMutableURLRequest(URL: NSURL(string: url)!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 5)
        var response: NSURLResponse?
        var error: NSError?
        request.HTTPMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var connection: NSURLConnection = NSURLConnection(request: request, delegate: self, startImmediately: true)!;
    }
    
    func getRequest(url:String) {
        var url = url
        NSLog("url:%@", url)
        let fileUrl = NSURL(string: url)
        var request = NSMutableURLRequest(URL: NSURL(string: url)!, cachePolicy: NSURLRequestCachePolicy.ReloadIgnoringLocalCacheData, timeoutInterval: 5)
        var response: NSURLResponse?
        var error: NSError?
        request.HTTPMethod = "GET"
        request.setValue("text/plain; charset=utf-8", forHTTPHeaderField: "Content-Type")
        var connection: NSURLConnection = NSURLConnection(request: request, delegate: self, startImmediately: true)!;
    }
    
    func connection(didReceiveResponse: NSURLConnection!, didReceiveResponse response: NSURLResponse!) {
        // Received a new request, clear out the data object
        NSLog(" ----------------------------- didReceiveResponse() ----------------------------- ")
        self.data = NSMutableData()
    }
    
    func connection(connection: NSURLConnection!, didReceiveData data: NSData!) {
        NSLog(" ----------------------------- didReceiveData() ----------------------------- ")

        // Append the received chunk of data to our data object
        self.data.appendData(data)
    }
    
    // returns jsonResult as NSDictionary
    
    func connectionDidFinishLoading(connection: NSURLConnection!) {
         NSLog(" ----------------------------- connectionDidFinishLoading() ----------------------------- ")
        // Request complete, self.data should now hold the resulting info
        // Convert the retrieved data in to an object through JSON deserialization
        var err: NSError
        let json = JSON(data: data)
        self.processJson(json)
        
    }
    
    
    // TODO this is still a bit messy, this function handles the response of all API calls made through connnection delegate
    // It ended up this way because of a lack of being able to return a value to delegate functions
    // all processing events get lopped together for now, until this can be fixed in the future with a
    // better understanding of delegate on NSURLConnection() (connection) method
    

    func processJson(json:JSON) {
     
        NSLog(" ----------------------------- processJson() ----------------------------- ")
        if json.count>0 {
            if (json["access_token"] != nil) {
                NSLog(" ----------------------------- found access_token key ----------------------------- ")
                self.accessToken = json["access_token"].stringValue as NSString
                self.apiUserId = json["_id"].stringValue as NSString
                NSLog("accessToken:%@", accessToken)
                NSLog("snap ID:%@", apiUserId)
                self.updateUser()
            }
            
            if (json["success"] != nil){
                NSLog(" ----------------------------- video uploaded ----------------------------- ")
            }
        }
    }
    
    
    // searches by a userID, then it updates the access token
    // this should probably be moved to the User Model since its a CRUD event, even though its tied to the response
    // function above, processResults(), this probably doesn't matter bc its saving something. This could be made
    // more general by passing a key, to the update field and value of that being updated

    func updateUser(){
        let appDelegate =
        UIApplication.sharedApplication().delegate as AppDelegate
        let managedContext = appDelegate.managedObjectContext!
        var request = NSBatchUpdateRequest(entityName: "User")
        request.predicate = NSPredicate(format: "identity == %@", self.userID)
        request.propertiesToUpdate = ["accessToken":self.accessToken, "apiUserId":self.apiUserId]
        request.resultType = .UpdatedObjectsCountResultType
        var batchError: NSError?
        let result = managedContext.executeRequest(request,
            error: &batchError)
        
        if result != nil{
            if let theResult = result as? NSBatchUpdateResult{
                if let numberOfAffectedPersons = theResult.result as? Int{
                    println("The number of records that match the predicate " +
                        "and have an access token is \(numberOfAffectedPersons)")
                    
                }
            }
        } else {
            if let error = batchError{
                println("Could not perform batch request. Error = \(error)")
            }
        }
    } // end updateUser()
}