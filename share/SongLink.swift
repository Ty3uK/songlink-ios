import Foundation
import RxSwift

let BASE_URL = "https://song.link/"
let INITIAL_STATE_REGEXP = "<script id=\"initialState\".+>\\s+?(.+)\\s+?</script>"
let SERVICES = [
    SLProvider(name: "YANDEX_SONG", label: "Yandex Music", url: ""),
    SLProvider(name: "GOOGLE_SONG", label: "Google Music", url: ""),
    SLProvider(name: "ITUNES_SONG", label: "Apple Music", url: ""),
    SLProvider(name: "SPOTIFY_SONG", label: "Spotify", url: ""),
    SLProvider(name: "YOUTUBE_VIDEO", label: "Youtube", url: ""),
    SLProvider(name: "YOUTUBE_SONG", label: "Youtube Music", url: ""),
    SLProvider(name: "DEEZER_SONG", label: "Deezer", url: ""),
    SLProvider(name: "PANDORA_SONG", label: "Pandora", url: ""),
    SLProvider(name: "SOUNDCLOUD_SONG", label: "SoundCloud", url: ""),
    SLProvider(name: "TIDAL_SONG", label: "Tidal", url: ""),
    SLProvider(name: "SONGLINK", label: "song.link", url: "")
]

struct SL: Decodable {
    var songlink: SLData
}

struct SLResponse {
    let url: String
    let data: Data
}

struct SLData: Decodable {
    let title: String
    let artistName: String
    let nodesByUniqueId: [String: SLNode]

    var links: [SLLink] = []

    enum CodingKeys: String, CodingKey {
        case title = "title"
        case artistName = "artistName"
        case nodesByUniqueId = "nodesByUniqueId"
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        title = try container.decode(String.self, forKey: .title)
        artistName = try container.decode(String.self, forKey: .artistName)
        nodesByUniqueId = try container.decode([String: SLNode].self, forKey: .nodesByUniqueId)
    }

    init(title: String, artistName: String, nodesByUniqueId: [String: SLNode]) {
        self.title = title
        self.artistName = artistName
        self.nodesByUniqueId = nodesByUniqueId
    }
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

struct SLNode: Decodable {
    let entity: String?
    let listenUrl: String?
    let listenAppUrl: String?
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
            .flatMap({ self.fillLinks($0) })
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
                observer.onError(NSError(domain: "Error: Couldn't decode data into SL", code: 1, userInfo: nil))
                observer.onCompleted()
                return disposable
            }

            observer.onNext(parsed)
            observer.onCompleted()

            return disposable
        }
    }

    private func fillLinks(_ data: SL) -> Observable<SL> {
        var slData = SLData(
            title: data.songlink.title,
            artistName: data.songlink.artistName,
            nodesByUniqueId: data.songlink.nodesByUniqueId
        )

        data.songlink.nodesByUniqueId.forEach { key, value in
            guard let entity: String = value.entity else { return }
            guard let listenUrl: String = value.listenUrl else { return }

            let listenAppUrl = value.listenAppUrl ?? ""
            let provider = entity
                .replacingOccurrences(of: "_SONG", with: "")
                .replacingOccurrences(of: "_VIDEO", with: "")

            slData.links.append(SLLink(
                name: entity,
                provider: provider,
                url: listenUrl
            ))

            if listenAppUrl.count > 0 && provider == "YOUTUBE" {
                slData.links.append(SLLink(
                    name: "YOUTUBE_SONG",
                    provider: "YOUTUBE",
                    url: listenAppUrl
                ))
            }
        }

        return Observable.just(SL(songlink: slData))
    }

    private func requestData(_ url: String) -> Observable<SLResponse> {
        return Observable.create() { observer in
            let targetUrl = URL(string: BASE_URL + url)

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
                error(NSError(domain: "HTML parsing error", code: 1, userInfo: nil))
                return disposable
            }

            guard let regex = try? NSRegularExpression(pattern: INITIAL_STATE_REGEXP) else {
                error(NSError(domain: "NSRegularExpression creating error", code: 1, userInfo: nil))
                return disposable
            }

            let matches = regex.matches(
                in: htmlString,
                options: [],
                range: NSMakeRange(0, htmlString.count)
            )

            guard let match = matches.first, let range = Range(match.range(at: 1), in: htmlString) else {
                error(NSError(domain: "Initial state not found", code: 1, userInfo: nil))
                return disposable
            }

            guard let result = String(htmlString[range]).data(using: .utf8) else {
                error(NSError(domain: "Cannot extract initialState", code: 1, userInfo: nil))
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
                guard let remoteProvider = data.songlink.links.first(where: { link in link.name == item.name }) else { return }
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
