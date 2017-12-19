//
//  ViewController.swift
//  在线百家乐-威尼斯人娱乐场
//
//  Created by Changcui Wan on 2017/12/12.
//  Copyright © 2017年 Changcui Wan. All rights reserved.
//

import UIKit
import WebKit
import EventKit
import UserNotifications
import DRPLoadingSpinner
import Alamofire

struct urlLink: Decodable {
    var success: Bool
    var payload: urlLinkPayload
}

struct urlLinkPayload: Decodable {
    var affiliateLink: [String]
}

struct CreateResponse: Decodable {
    var success: Bool
    var payload: CreatePayload
}

struct CreatePayload: Decodable {
    var message: String
}

struct Calander: Decodable {
    var success: Bool
    var payload: CalanderPayload
}

struct CalanderPayload: Decodable {
    var eventTitle: String
    var eventMessage: String
    var end: String
}



class ViewController: UIViewController, WKNavigationDelegate {
    
    @IBOutlet weak var webView: WKWebView!
    
    var spinner: DRPLoadingSpinner!
    let casinoName: String = "威尼斯人娱乐场"
    var linkString: String!
    var eventTitle: String!
    var notes: String!
    var end: Date!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        webView.navigationDelegate = self
        getLink()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        createUser()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        checkCalendarAuthorizationStatus()
        print("end date: \(self.end)")
    }
    
    override var shouldAutorotate: Bool {
        let isAutorotate: Bool
        
        if (approvedUploadCheck() == false) {
            isAutorotate = true
        } else {
            isAutorotate = false
        }
        return isAutorotate
    }
    
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        let orientation: UIInterfaceOrientationMask
        
        if (approvedUploadCheck() == false) {
            orientation = .landscapeLeft
            loadingSpinnerConfig()
        } else {
            orientation = .portrait
            loadingSpinnerConfig()
        }
        return orientation
    }
    
    @IBAction func homeButton(_ sender: UIButton) {
        timeDelay()
    }
    
    @IBAction func backButton(_ sender: UIButton) {
        webView.goBack()
    }
    
    @IBAction func forwardButton(_ sender: UIButton) {
        webView.goForward()
    }
    
    @IBAction func refreshButton(_ sender: UIButton) {
        webView.reload()

    }
    
    func getIFAddresses() -> [String] {
        var addresses = [String]()
        
        // Get list of all interfaces on the local machine:
        var ifaddr : UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0 else { return [] }
        guard let firstAddr = ifaddr else { return [] }
        
        // For each interface ...
        for ptr in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(ptr.pointee.ifa_flags)
            let addr = ptr.pointee.ifa_addr.pointee
            
            // Check for running IPv4, IPv6 interfaces. Skip the loopback interface.
            if (flags & (IFF_UP|IFF_RUNNING|IFF_LOOPBACK)) == (IFF_UP|IFF_RUNNING) {
                if addr.sa_family == UInt8(AF_INET) || addr.sa_family == UInt8(AF_INET6) {
                    
                    // Convert interface address to a human readable string:
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if (getnameinfo(ptr.pointee.ifa_addr, socklen_t(addr.sa_len), &hostname, socklen_t(hostname.count),
                                    nil, socklen_t(0), NI_NUMERICHOST) == 0) {
                        let address = String(cString: hostname)
                        addresses.append(address)
                    }
                }
            }
        }
        
        freeifaddrs(ifaddr)
        return addresses
    }
    
    func getLink() -> Void{
        let urlString = "http://localhost:4040/api/casinos/affiliate-link"
        guard let url = URL(string: urlString) else {
            return
        }
        
        let parameters: Parameters = [ "name": casinoName ]
        Alamofire.request(url, parameters: parameters).responseJSON { response in
            if(response.error != nil){
                return
            }
            guard let data = response.data else {
                return
            }
            do {
                let result = try JSONDecoder().decode(urlLink.self, from: data)
                self.linkString = result.payload.affiliateLink[0]
                self.timeDelay()
            } catch let jsonErr {
                print(jsonErr)
            }
            
        }
    }
    
    func createUser() {
        guard let deviceId = UIDevice.current.identifierForVendor?.uuidString else
        { return }
        let parameters: Parameters = [
            "name": casinoName,
            "deviceId": deviceId,
            "ipAddress": getIFAddresses()
        ]
        let urlString = "http://localhost:4040/api/ios-users/create"
        guard let url = URL(string: urlString) else
            { return }
        
        Alamofire.request(url, method: .post, parameters: parameters, encoding: URLEncoding.httpBody).responseJSON { response in
            if(response.error != nil){
                return
            }
            guard let data = response.data else {
                return
            }
            do {
                let result = try JSONDecoder().decode(CreateResponse.self, from: data)
                print(result.payload.message)
            } catch let jsonErr {
                print(jsonErr)
            }
        }
    }
    
    func getCalanderEvent() {
        let urlString = "http://localhost:4040/api/ios-calander/event"
        guard let url = URL(string: urlString) else {
            return
        }
        let parameters: Parameters = [ "name": casinoName ]
        Alamofire.request(url, parameters: parameters).responseJSON { response in
            if(response.error != nil){
                return
            }
            guard let data = response.data else {
                return
            }
            do {
                let result = try JSONDecoder().decode(Calander.self, from: data)
                self.eventTitle = result.payload.eventTitle
                self.notes = result.payload.eventMessage
                let endString = result.payload.end
                let dateFormatter = DateFormatter()
                dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
                dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
                self.end = dateFormatter.date(from: endString)
                self.addEvent()
            } catch let jsonErr {
                print(jsonErr)
            }
            
        }
    }
    
    func loadGameURL(){
        let myURL = URL(string: "http://showcase.codethislab.com/games/baccarat/")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
    }
    
    func loadReal(){
        let myURL = URL(string: self.linkString)
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
    }
    
    func loadingSpinnerConfig(){
        let screenRect: CGRect = UIScreen.main.bounds
        spinner = DRPLoadingSpinner(frame: CGRect(x: (screenRect.size.width / 2) - 25, y: (screenRect.size.height / 2) - 25, width: 50, height: 50))
        view.addSubview(spinner)
    }
    
    func addEvent(){
        let eventStore: EKEventStore = EKEventStore()
        eventStore.requestAccess(to: .event) { (granted, error) in
            if (granted) && (error == nil)
            {
                let event: EKEvent = EKEvent(eventStore: eventStore)
                event.title = self.eventTitle
                event.startDate = Date()
                event.endDate = self.end
                event.notes = self.notes
                event.calendar = eventStore.defaultCalendarForNewEvents
                do {
                    try eventStore.save(event, span: .thisEvent)
                }catch let error as NSError{
                    print("error: \(error)")
                }
                print("saveEvent")
            }else{
                print("error: \(String(describing: error))")
            }
        }
    }
    
    func alertGoSettings(){
        let alertController = UIAlertController(title: "提醒！", message: "为了我们更优质的服务您，请前往设置->在线百家乐-威尼斯人娱乐场->打开日历", preferredStyle: .alert)
        let settingsAction = UIAlertAction(title: "设置", style: .default) { (_) -> Void in
            guard let settingsUrl = URL(string: UIApplicationOpenSettingsURLString) else {
                return
            }
            
            if UIApplication.shared.canOpenURL(settingsUrl) {
                UIApplication.shared.open(settingsUrl, completionHandler: { (success) in
                    print("Settings opened: \(success)") // Prints true
                })
            }
        }
        alertController.addAction(settingsAction)
        let cancelAction = UIAlertAction(title: "取消", style: .default, handler: nil)
        alertController.addAction(cancelAction)
        self.present(alertController, animated: true, completion: nil)
    }
    
    func checkCalendarAuthorizationStatus() {
        let status = EKEventStore.authorizationStatus(for: EKEntityType.event)
        switch (status) {
        case EKAuthorizationStatus.notDetermined:
            // This happens on first-run
            print("还没选择")
        case EKAuthorizationStatus.authorized:
            print("已同意")
            getCalanderEvent()
        case EKAuthorizationStatus.restricted, EKAuthorizationStatus.denied:
            // We need to help them give us permission
            alertGoSettings()
            print("拒绝同意")
        }
    }
    
    func approvedUploadCheck() -> Bool {
        let isUpload: Bool
        let now: Date = Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd HH:mm"
        let uploadTime: Date = formatter.date(from: "2016/12/15 00:00")!
        
        if (now > uploadTime) {
            print("already upload")
            isUpload = true
        } else {
            print("uploading")
            isUpload = false
        }
        
        return isUpload
    }
    
    func timeDelay() {
        if (approvedUploadCheck() == true) {
            getCalanderEvent()
            loadReal()
        } else {
            loadGameURL()
        }
    }
    

    
    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        spinner.startAnimating()
    }
    
    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        spinner.stopAnimating()
    }

    
}
    

