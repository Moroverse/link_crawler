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

func get(path: String, completion: @escaping () -> Void) {
    let cwd = FileManager.default.currentDirectoryPath
    if let url = URL(string: path) {
    URLSession.shared.dataTaskPublisher(for: url)
        .flatMap { result -> AnyPublisher<[LinkedData], URLError> in
            if let string = String(data: result.data, encoding: .utf8) {
                let links = HTMLLinkParser.parse(string)
                let result = links.compactMap { link -> AnyPublisher<LinkedData, URLError>? in
                    if let itemUrl = URL(string: link.reference, relativeTo: url) {
                        return URLSession
                            .shared
                            .dataTaskPublisher(for: itemUrl)
                            .map { (output) -> LinkedData in
                                return LinkedData(name: link.title ?? link.reference, data: output.data)
                            }.eraseToAnyPublisher()
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
                let cwde = cwd + "/" + value.name
                do {
                    try value.data.write(to: URL(fileURLWithPath: cwde))
                } catch let error {
                    print(error)
                }
            }
            
            completion()
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
    get(path: path) {
        keepRunning = false
    }

    while keepRunning {
    }
}
