//
//  main.swift
//  link_crawler
//
//  Created by Daniel Moro on 31.10.2020.
//

import Foundation
import Combine

var cancellables: Set<AnyCancellable> = []

struct LinkedData {
    var name: String
    var data: Data
}

func processLinksIn(_ string: String, path: String, completion: @escaping () -> Void) {
    let baseURL = URL(string: path)
    let links = HTMLLinkParser.parse(string)
    var taskCounter = 0
    let cwd = FileManager.default.currentDirectoryPath
    for link in links {
        if let url = URL(string: link.reference, relativeTo: baseURL) {
            taskCounter += 1
            URLSession.shared.dataTaskPublisher(for: url).sink { (result) in
                switch result {
                case .finished:
                    break
                case .failure(let error):
                    print(error)
                }
            } receiveValue: { (response) in
                let cwde = cwd.appending(link.title ?? link.reference)
                do {
                    try response.data.write(to: URL(fileURLWithPath: cwde))
                } catch let error {
                    print(error)
                }
                taskCounter -= 1
                if taskCounter <= 0 {
                    completion()
                }
            }.store(in: &cancellables)
        }
    }
}

func get(path: String, completion: @escaping (_ result: String?) -> Void) {
    if let url = URL(string: path) {
    URLSession.shared.dataTaskPublisher(for: url)
        .flatMap { result -> AnyPublisher<[(data: Data, response: URLResponse)], URLError> in
            if let string = String(data: result.data, encoding: .utf8) {
                let links = HTMLLinkParser.parse(string)
                let result = links.compactMap { link -> URLSession.DataTaskPublisher? in
                    if let itemUrl = URL(string: link.reference, relativeTo: url) {
                        return URLSession
                            .shared
                            .dataTaskPublisher(for: itemUrl)
                    } else {
                        return nil
                    }
                }
                let merged = Publishers.MergeMany(result)
                    .collect().eraseToAnyPublisher()
                return merged
            }
            return Fail(error: URLError(.cancelled)).eraseToAnyPublisher()
        }
        .sink(receiveCompletion: { (result) in
            switch result {
            case .finished:
                break
            case .failure(_):
                break
            }
        }, receiveValue: { (values) in
            for value in values {
//                value.data
            }
        })
        .store(in: &cancellables)
    }
}

if CommandLine.arguments.count > 1 {
    var keepRunning = true
    var path = CommandLine.arguments[1]
    if path.contains("&") {
        path = path.replacingOccurrences(of: "&", with: "%26")
    }
    get(path: path) { (result) in
        keepRunning = false
    }
//    if let url = URL(string: path) {
//        get(url: url, completion: { (result) in
//            if let result = result {
//                processLinksIn(result, path: path) {
//                    keepRunning = false
//                }
//            } else {
//                keepRunning = false
//            }
//        })
//    } else {
//        keepRunning = false
//    }

    while keepRunning {
    }
}
