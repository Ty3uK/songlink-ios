import UIKit
import Social
import MobileCoreServices
import RxSwift

class ShareViewController: UIViewController {
    
    let reload = PublishSubject<Bool>()
    let disposeBag = DisposeBag()
    let songLink = SongLink()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        wrapLoadWithReload()
            .subscribe(
                onNext: { self.handleAction(result: $0) },
                onError: { self.handleError(error: $0) }
            )
            .disposed(by: disposeBag)
        
        reload.onNext(true)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.view.alpha = 0.0
        
        UIView.animate(withDuration: 0.3) {
            self.view.alpha = 1.0
        }
    }
    
    private func wrapLoadWithReload() -> Observable<ActionSheetResult> {
        return reload.flatMap({ _ in
            self.getIncomingUrl()
                .flatMap({ self.songLink.load($0.absoluteString) })
                .observeOn(MainScheduler.instance)
                .flatMap({ showServicesSheet(root: self, services: $0) })
                .flatMap({ showActionSheet(root: self, provider: $0) })
                .do(onCompleted: { self.exit() })
        })
    }
    
    private func getIncomingUrl() -> Observable<URL> {
        return Observable.create() { observer in
            let URL_TYPE = kUTTypeURL as String
            
            if let item = self.extensionContext?.inputItems.first as? NSExtensionItem,
                let itemProvider = item.attachments?.first,
                itemProvider.hasItemConformingToTypeIdentifier(URL_TYPE) {
                
                itemProvider.loadItem(forTypeIdentifier: URL_TYPE, options: nil) { (url, error) in
                    if let error = error {
                        observer.onError(error)
                        observer.onCompleted()
                        return
                    }
                    
                    observer.onNext(url as! URL)
                    observer.onCompleted()
                }
            }
            
            return Disposables.create()
        }
    }
    
    @objc private func openURL(_ url: URL) {
        var responder: UIResponder? = self
        
        while responder != nil {
            if let app = responder as? UIApplication {
                app.perform(#selector(openURL(_:)), with: url)
                return
            }
            
            responder = responder?.next
        }
    }
    
    private func handleAction(result: ActionSheetResult) {
        let url = URL(string: result.provider.url)!
        
        switch result.action {
        case .OPEN:
            self.openURL(url)
        case .COPY:
            UIPasteboard.general.string = result.provider.url
        case .SHARE:
            let shareView = UIActivityViewController(activityItems: [url], applicationActivities: nil)
            
            shareView.popoverPresentationController?.sourceView = self.view
            shareView.completionWithItemsHandler = { (_, _, _, _) in
                self.exit()
            }
            
            self.present(shareView, animated: true, completion: nil)
        default:
            self.reload.onNext(true)
        }
        
        if result.action != .SHARE && result.action != .BACK {
            self.exit()
        }
    }
    
    private func handleError(error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("An error occured", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
        let cancel = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .destructive) { _ in
            self.exit()
        }
        
        alert.addAction(cancel)
        
        self.present(alert, animated: true, completion: nil)
    }
    
    private func exit(callback: ((Bool) -> Void)? = nil) {
        self.extensionContext!.completeRequest(returningItems: nil, completionHandler: callback)
    }
    
}
