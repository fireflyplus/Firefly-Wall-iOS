import UIKit
import WebKit
import CommonCrypto
import AppTrackingTransparency
import AdSupport

class FormViewController: UIViewController {
    private var wkWebView: WKWebView!

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidLoad()
        self.setupWKWebview()
        self.loadPage()
    }

    private func setupWKWebview() {
        navigationController?.navigationBar.isTranslucent = true
        
        self.wkWebView = WKWebView(frame: self.view.bounds, configuration: self.getWKWebViewConfiguration())
                
        self.wkWebView.translatesAutoresizingMaskIntoConstraints = false
        self.view.addSubview(self.wkWebView)
        // 使用 view 的边缘布局，忽略安全区
        NSLayoutConstraint.activate([
            self.wkWebView.topAnchor.constraint(equalTo: self.view.topAnchor),
            self.wkWebView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            self.wkWebView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            self.wkWebView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
    }
    
    private func loadPage() {
        let link = "https://gifts.fireflyplus.com/firefly-wall/list"
        let url = URL(string: link)
        self.wkWebView.load(URLRequest(url: url!))
        
        if #available(iOS 16.4, *) { // iOS 16.4以上开启调试模式，使其可以在 Safari 浏览器中调试
            self.wkWebView.isInspectable = true
        }
    }
    
    private func getWKWebViewConfiguration() -> WKWebViewConfiguration {
        let userController = WKUserContentController()
        if #available(iOS 14.0, *) {
            userController.add(self, contentWorld: .page, name: "initUser")
            userController.add(self, contentWorld: .page, name: "openBrowser")
            userController.add(self, contentWorld: .page, name: "closePage")
        } else {
            userController.add(self, name: "initUser")
            userController.add(self, name: "openBrowser")
            userController.add(self, name: "closePage")
        }
        
        let configuration = WKWebViewConfiguration()
        configuration.userContentController = userController
        return configuration
    }
}

extension FormViewController: WKScriptMessageHandler{
    
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print(message.name)
        print(message.body)
        
        if message.name == "initUser" { // 用户初始化
            let group = DispatchGroup()
            
            var userAgent = ""
            var ip = ""
            var idfa = ""
            
            // 获取 UA
            group.enter()
            self.wkWebView.evaluateJavaScript("navigator.userAgent") { result, error in
                if let ua = result as? String {
                    userAgent = ua
                }
                group.leave()
            }

            // 获取 IP
            group.enter()
            URLSession.shared.dataTask(with: URL(string: "https://api.ipify.org?format=text")!) { data, _, _ in
                if let data = data {
                    ip = String(data: data, encoding: .utf8) ?? ""
                }
                group.leave()
            }.resume()

            // 获取 IDFA
//            if #available(iOS 14, *) {
//                group.enter()
//                ATTrackingManager.requestTrackingAuthorization { status in
//                    if status == .authorized {
//                        idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
//                    }
//                    group.leave()
//                }
//            } else {
//                group.enter()
//                idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
//                group.leave()
//            }
    
            group.notify(queue: .main) {
                let appId = "T801001"
                let key = "05e98782776b44acb34d7f59d417f89b"
                let userId = "8eb7fbb7-90db-438e-b4a9-5be03a224534"
                let countryCode = "US"
                let language = "en"
                let placementId = "T801001G05"
                let extra = ""
                let iosVersion = UIDevice.current.systemVersion
                let time = Int(Date().timeIntervalSince1970 * 1000)
                
                let params: [(String, String)] = [
                    ("appId", appId),
                    ("countryCode", countryCode),
                    ("extra", extra),
                    ("idfa", idfa),
                    ("iosVersion", iosVersion),
                    ("ip", ip),
                    ("language", language),
                    ("placementId", placementId),
                    ("time", String(time)),
                    ("userAgent", userAgent),
                    ("userId", userId),
                ]
                

                let paramString = params.map { "\($0.0)=\($0.1)" }.joined(separator: "&")
                let stringToSign = paramString + key
                print(stringToSign)
                
                let sign = stringToSign.md5
                print(sign)
                
                var resp = Dictionary(uniqueKeysWithValues: params)
                resp["sign"] = sign
                print(resp)
                
                do {
                    let respData = try JSONSerialization.data(withJSONObject: resp)
                    let respString = String(data: respData, encoding: String.Encoding.utf8) ?? ""
                    print(respString)
                    
                    let returnDataString = "window.iosInitUserResponse(" + respString + ")"
                    print(returnDataString)
                    
                    self.wkWebView.evaluateJavaScript(returnDataString, completionHandler: nil)
                } catch let myJSONError {
                    print(myJSONError)
                }
            }
        }
        
        if message.name == "openBrowser", let req = message.body as? String { // 浏览器打开 URL
            let data = try! JSONDecoder().decode([String: String].self, from: req.data(using: .utf8)!)
            let url = URL(string: data["openUrl"] ?? "")
            print(url!.path)
            if UIApplication.shared.canOpenURL(url!) {
                UIApplication.shared.open(url!) // 使用默认浏览器打开 url
            }
        }
        
        if message.name == "closePage", let req = message.body as? String { // 关闭页面
            let data = try! JSONDecoder().decode([String: String].self, from: req.data(using: .utf8)!)
            let page = data["page"] ?? ""
            print(page)
            
            exit(0)
        }
    }
}

extension String {
    public var md5: String {
        guard let data = data(using: .utf8) else {
            return self
        }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))

        #if swift(>=5.0)
            _ = data.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) in
            return CC_MD5(bytes.baseAddress, CC_LONG(data.count), &digest)
            }
        #else
            _ = data.withUnsafeBytes { bytes in
            return CC_MD5(bytes, CC_LONG(data.count), &digest)
        }
        #endif

        return digest.map { String(format: "%02x", $0) }.joined()

    }
}
