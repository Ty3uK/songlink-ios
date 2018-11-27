import Foundation
import RxSwift

let BASE_URL = "https://song.link/"
let INITIAL_STATE_REGEXP = "<script id=\"initialState\".+>(.+)</script>"
let SERVICES = [
    SLProvider(name: "yandex", label: "Yandex Music", url: ""),
    SLProvider(name: "google", label: "Google Music", url: ""),
    SLProvider(name: "appleMusic", label: "Apple Music", url: ""),
    SLProvider(name: "spotify", label: "Spotify", url: ""),
    SLProvider(name: "youtube", label: "Youtube", url: ""),
    SLProvider(name: "youtubeMusic", label: "Youtube Music", url: ""),
    SLProvider(name: "deezer", label: "Deezer", url: ""),
    SLProvider(name: "pandora", label: "Pandora", url: ""),
    SLProvider(name: "soundcloud", label: "SoundCloud", url: ""),
    SLProvider(name: "tidal", label: "Tidal", url: ""),
    SLProvider(name: "songlink", label: "song.link", url: "")
]

struct SL: Decodable {
    let songlink: SLData
}

struct SLResponse {
    let url: String
    let data: Data
}

struct SLData: Decodable {
    let title: String
    let artistName: String
    let links: SLLinks
}

struct SLLinks: Decodable {
    let listen: [SLLink]
}

struct SLLink: Decodable {
    let name: String
    let provider: String
    let url: String
}

struct SLProvider {
    let name: String
    let label: String
    let url: String
}

enum SLError: Error {
    case runtimeError(String)
}

class SongLink {
    private var url: String? = nil
    private var providers: [SLProvider] = []
    
    func load(_ url: String) -> Observable<[SLProvider]> {
        if providers.count > 0 {
            return Observable.just(providers)
        }
        
        return requestData(url)
            .map({
                self.url = $0.url
                return $0.data
            })
            .flatMap({ self.extractData($0) })
            .flatMap({ self.parseJson($0) })
            .flatMap({ self.getProviders(data: $0) })
            .map({
                self.providers = $0
                return $0
            })
    }
    
    private func parseJson(_ data: Data) -> Observable<SL> {
        return Observable.create() { observer in
            let disposable = Disposables.create()
            
            guard let parsed = try? JSONDecoder().decode(SL.self, from: data) else {
                observer.onError(SLError.runtimeError("Error: Couldn't decode data into SL"))
                observer.onCompleted()
                return disposable
            }
            
            observer.onNext(parsed)
            observer.onCompleted()
            
            return disposable
        }
    }
    
    private func requestData(_ url: String) -> Observable<SLResponse> {
        return Observable.create() { observer in
            let targetUrl = URL(string: BASE_URL + url)
            
            let task = URLSession.shared.dataTask(with: targetUrl!) { (data, response, error) in
                guard let response = response as? HTTPURLResponse else {
                    observer.onError(SLError.runtimeError("Cannot decode response"))
                    observer.onCompleted()
                    return
                }
                
                if response.statusCode != 200 {
                    let message = String(format: "Server returned %d status code", response.statusCode)
                    observer.onError(SLError.runtimeError(message))
                    observer.onCompleted()
                    return
                }
                
                if let data = data {
                    observer.onNext(SLResponse(url: response.url!.absoluteString, data: data))
                } else if let error = error {
                    observer.onError(error)
                }
                
                observer.onCompleted()
            }
            
            task.resume()
            
            return Disposables.create()
        }
    }
    
    private func extractData(_ html: Data) -> Observable<Data> {
        return Observable.create() { observer in
            func error(_ error: Error) {
                observer.onError(error)
                observer.onCompleted()
            }
            
            let disposable = Disposables.create()
            
            guard let htmlString = String(data: html, encoding: .utf8) else {
                error(SLError.runtimeError("HTML parsing error"))
                return disposable
            }
            
            guard let regex = try? NSRegularExpression(pattern: INITIAL_STATE_REGEXP) else {
                error(SLError.runtimeError("NSRegularExpression creating error"))
                return disposable
            }
            
            let matches = regex.matches(
                in: htmlString,
                options: [],
                range: NSMakeRange(0, htmlString.count)
            )
            
            guard let match = matches.first, let range = Range(match.range(at: 1), in: htmlString) else {
                error(SLError.runtimeError("Initial state not found"))
                return disposable
            }
            
            guard let result = String(htmlString[range]).data(using: .utf8) else {
                error(SLError.runtimeError("Cannot extract initialState"))
                return disposable
            }
            
            observer.onNext(result)
            observer.onCompleted()
            
            return disposable
        }
    }
    
    private func getProviders(data: SL) -> Observable<[SLProvider]> {
        return Observable.create { observer in
            var services: [SLProvider] = []
            
            SERVICES.forEach() { item in
                guard let remoteProvider = data.songlink.links.listen.first(where: { link in link.name == item.name }) else { return }
                let newProvider = SLProvider(
                    name: item.name,
                    label: item.label,
                    url: remoteProvider.url
                )
                
                services.append(newProvider)
            }
            
            let songlinkProvider = SLProvider(
                name: SERVICES.last!.name,
                label: SERVICES.last!.label,
                url: self.url!
            )
            
            services.append(songlinkProvider)
            
            observer.onNext(services)
            observer.onCompleted()
            
            return Disposables.create()
        }
    }
}
