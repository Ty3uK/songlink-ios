import Foundation
import RxSwift

struct Response: Decodable {
    let pageUrl: String
    let linksByPlatform: Dictionary<String, Link>
}

struct Link: Decodable {
    let url: String
}

struct Provider: Decodable {
    let name: String
    let label: String
    let url: String
}

class SongLink {
    private var providers: [Provider] = []

    func load(_ url: String) -> Observable<[Provider]> {
        if providers.count > 0 {
            return Observable.just(providers)
        }

        return requestData(url)
            .flatMap({ self.parseJson($0) })
            .flatMap({ self.getProviders($0) })
            .map({
                self.providers = $0
                return $0
            })
    }
    
    private func requestData(_ url: String) -> Observable<Data> {
        return Observable.create() { observer in
            let targetUrl = URL(
                string:
                "https://api.song.link/v1-alpha.1/links" +
                "?" +
                "key=71d7be8a-3a76-459b-b21e-8f0350374984" +
                "&" +
                "url=\(url)"
            )

            let task = URLSession.shared.dataTask(with: targetUrl!) { (data, response, error) in
                guard let response = response as? HTTPURLResponse else {
                    observer.onError(NSError(domain: "Cannot decode response", code: 1, userInfo: nil))
                    observer.onCompleted()
                    return
                }

                if response.statusCode != 200 {
                    let message = String(format: "Server returned %d status code", response.statusCode)
                    observer.onError(NSError(domain: message, code: response.statusCode, userInfo: nil))
                    observer.onCompleted()
                    return
                }

                if let data = data {
                    observer.onNext(data)
                } else if let error = error {
                    observer.onError(error)
                }

                observer.onCompleted()
            }

            task.resume()

            return Disposables.create()
        }
    }

    private func parseJson(_ data: Data) -> Observable<Response> {
        return Observable.create() { observer in
            let disposable = Disposables.create()

            guard let parsed = try? JSONDecoder().decode(Response.self, from: data) else {
                observer.onError(NSError(domain: "Error: Couldn't decode data into SL", code: 1, userInfo: nil))
                observer.onCompleted()
                return disposable
            }

            observer.onNext(parsed)
            observer.onCompleted()

            return disposable
        }
    }

    private func getProviders(_ response: Response) -> Observable<[Provider]> {
        return Observable.create { observer in
            var providers: [Provider] = []
            let regex = String(
                format: "%@|%@|%@",
                "(?<=[A-Z])(?=[A-Z][a-z])",
                "(?<=[^A-Z])(?=[A-Z])",
                "(?<=[A-Za-z])(?=[^A-Za-z])"
            )

            for (name, link) in response.linksByPlatform {
                providers.append(
                    Provider(
                        name: name,
                        label: name
                            .replacingOccurrences(of: regex, with: " ", options: .regularExpression)
                            .capitalized,
                        url: link.url
                    )
                )
            }
            
            providers.append(
                Provider(
                    name: "song.link",
                    label: "song.link",
                    url: response.pageUrl
                )
            )

            observer.onNext(providers)
            observer.onCompleted()

            return Disposables.create()
        }
    }
}
