import UIKit
class ViewController: UIViewController {
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    @IBAction func githubClick(_ sender: UIButton) {
        openUrl("https://github.com/Ty3uK/songlink-ios")
    }
    
    @IBAction func telegramClick(_ sender: UIButton) {
        openUrl("https://t.me/xxxTy3uKxxx")
    }
    
    private func openUrl(_ urlString: String) {
        if let url = URL(string: urlString), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:])
        }
    }
}
