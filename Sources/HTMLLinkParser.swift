//
//  HTMLLinkParser.swift
//  LinkCrawler
//
//  Created by Daniel Moro on 31.10.20..
//

import Foundation

class HTMLLinkParser {
    struct Link {
        var reference: String
        var title: String?
    }
    
    static func parse(_ text: String) -> [Link] {
        let aParser = zip(.prefix(upTo: "<a href="),.prefix(through: "</a>")).map { firstPart, secondPart in firstPart+secondPart}
        let link = zip(.prefix(through: "<a href="),.prefix(upTo: " ")," title=", .prefix(upTo: ">"), .prefix(through: "</a>")).map{_,ref,_, title, _ in Link(reference: ref.replacingOccurrences(of: "\"", with: ""), title: title.replacingOccurrences(of: "\"", with: ""))}
        let links = aParser.zeroOrMore()

        let result = links.run(text)
        if let match = result.match {
            return match.compactMap {link.run(String($0)).match}
        } else {
            return []
        }
    }
}
