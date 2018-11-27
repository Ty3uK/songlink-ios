import UIKit
import RxSwift

enum ACTIONS {
    case OPEN
    case COPY
    case SHARE
    case BACK
}

struct ActionSheetResult {
    let action: ACTIONS
    let provider: SLProvider
}

func showServicesSheet(root: UIViewController, services: [SLProvider]) -> Observable<SLProvider> {
    return Observable.create { observer in
        let actionSheet = UIAlertController(title: NSLocalizedString("Select target music service", comment: ""), message: nil, preferredStyle: .actionSheet)
        
        for provider in services {
            let serviceAction = UIAlertAction(title: provider.label, style: .default) { action in
                observer.onNext(provider)
                observer.onCompleted()
            }
            
            actionSheet.addAction(serviceAction)
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { action in
            observer.onCompleted()
        }
        
        actionSheet.addAction(cancelAction)
        
        root.present(actionSheet, animated: true, completion: nil)
        
        return Disposables.create()
    }
}

func showActionSheet(root: UIViewController, provider: SLProvider) -> Observable<ActionSheetResult> {
    return Observable.create { observer in
        let actionSheet = UIAlertController(title: provider.label, message: nil, preferredStyle: .actionSheet)
        
        let openAction = UIAlertAction(title: NSLocalizedString("Open", comment: ""), style: .default) { action in
            observer.onNext(ActionSheetResult(action: .OPEN, provider: provider))
        }
        
        let copyAction = UIAlertAction(title: NSLocalizedString("Copy", comment: ""), style: .default) { action in
            observer.onNext(ActionSheetResult(action: .COPY, provider: provider))
        }
        
        let shareAction = UIAlertAction(title: NSLocalizedString("Share", comment: ""), style: .default) { action in
            observer.onNext(ActionSheetResult(action: .SHARE, provider: provider))
        }
        
        let backAction = UIAlertAction(title: NSLocalizedString("Back", comment: ""), style: .default) { action in
            observer.onNext(ActionSheetResult(action: .BACK, provider: provider))
        }
        
        let cancelAction = UIAlertAction(title: NSLocalizedString("Cancel", comment: ""), style: .cancel) { action in
            observer.onCompleted()
        }
        
        actionSheet.addAction(openAction)
        actionSheet.addAction(copyAction)
        actionSheet.addAction(shareAction)
        actionSheet.addAction(backAction)
        actionSheet.addAction(cancelAction)
        
        root.present(actionSheet, animated: true, completion: nil)
        
        return Disposables.create()
    }
}
