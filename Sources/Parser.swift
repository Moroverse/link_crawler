//
//  Parser.swift
//
//
//  Created by Daniel Moro on 31.10.2020.
//

import Foundation

public struct Parser<Output> {
    public let run: (inout Substring) -> Output?
}

extension Parser {
    public func run(_ input: String) -> (match: Output?, rest: Substring) {
        var input = input[...]
        let match = run(&input)
        return (match, input)
    }

    public static func always(_ output: Output) -> Self {
        Self { _ in output }
    }

    public static var never: Self {
        Self { _ in nil }
    }

    public func map<NewOutput>(_ f: @escaping (Output) -> NewOutput) -> Parser<NewOutput> {
        .init { input in
            self.run(&input).map(f)
        }
    }

    public func flatMap<NewOutput>(
        _ f: @escaping (Output) -> Parser<NewOutput>
    ) -> Parser<NewOutput> {
        .init { input in
            let original = input
            let output = self.run(&input)
            let newParser = output.map(f)
            guard let newOutput = newParser?.run(&input) else {
                input = original
                return nil
            }
            return newOutput
        }
    }

    public static func prefix(while p: @escaping (Character) -> Bool) -> Parser<Substring> {
        return Parser<Substring> { str in
            let prefix = str.prefix(while: p)
            str.removeFirst(prefix.count)
            return prefix
        }
    }
    
    func zeroOrMore(
        separatedBy separator: Parser<Void> = ""
      ) -> Parser<[Output]> {
        Parser<[Output]> { input in
          var rest = input
          var matches: [Output] = []
          while let match = self.run(&input) {
            rest = input
            matches.append(match)
            if separator.run(&input) == nil {
              return matches
            }
          }
          input = rest
          return matches
        }
      }

    public static func oneOf<Output>(_ ps: [Parser<Output>]) -> Parser<Output> {
        return Parser<Output> { str in
            for p in ps {
                if let match = p.run(&str) {
                    return match
                }
            }
            return nil
        }
    }

    public static func oneOf(_ ps: Self...) -> Self {
        oneOf(ps)
    }
}

public func zip<Output1, Output2>(
    _ p1: Parser<Output1>,
    _ p2: Parser<Output2>
) -> Parser<(Output1, Output2)> {
    .init { input -> (Output1, Output2)? in
        let original = input
        guard let output1 = p1.run(&input) else { return nil }
        guard let output2 = p2.run(&input) else {
            input = original
            return nil
        }
        return (output1, output2)
    }
}

public func zip<Output1, Output2, Output3>(
    _ p1: Parser<Output1>,
    _ p2: Parser<Output2>,
    _ p3: Parser<Output3>
) -> Parser<(Output1, Output2, Output3)> {
    zip(p1, zip(p2, p3))
        .map { output1, output23 in (output1, output23.0, output23.1) }
}

public func zip<A, B, C, D>(
    _ a: Parser<A>,
    _ b: Parser<B>,
    _ c: Parser<C>,
    _ d: Parser<D>
) -> Parser<(A, B, C, D)> {
    zip(a, zip(b, c, d))
        .map { a, bcd in (a, bcd.0, bcd.1, bcd.2) }
}

public func zip<A, B, C, D, E>(
    _ a: Parser<A>,
    _ b: Parser<B>,
    _ c: Parser<C>,
    _ d: Parser<D>,
    _ e: Parser<E>
) -> Parser<(A, B, C, D, E)> {
    zip(a, zip(b, c, d, e))
        .map { a, bcde in (a, bcde.0, bcde.1, bcde.2, bcde.3) }
}

public func zip<A, B, C, D, E, F>(
    _ a: Parser<A>,
    _ b: Parser<B>,
    _ c: Parser<C>,
    _ d: Parser<D>,
    _ e: Parser<E>,
    _ f: Parser<F>
) -> Parser<(A, B, C, D, E, F)> {
    return zip(a, zip(b, c, d, e, f))
        .map { a, bcdef in (a, bcdef.0, bcdef.1, bcdef.2, bcdef.3, bcdef.4) }
}

public func zip<A, B, C, D, E, F, G>(
    _ a: Parser<A>,
    _ b: Parser<B>,
    _ c: Parser<C>,
    _ d: Parser<D>,
    _ e: Parser<E>,
    _ f: Parser<F>,
    _ g: Parser<G>
) -> Parser<(A, B, C, D, E, F, G)> {
    return zip(a, zip(b, c, d, e, f, g))
        .map { a, bcdefg in (a, bcdefg.0, bcdefg.1, bcdefg.2, bcdefg.3, bcdefg.4, bcdefg.5) }
}

extension Parser where Output == Int {
    public static let int = Self { input in
        let original = input

        var isFirstCharacter = true
        let intPrefix = input.prefix { character in
            defer { isFirstCharacter = false }
            return (character == "-" || character == "+") && isFirstCharacter
                || character.isNumber
        }

        guard let match = Int(intPrefix)
        else {
            input = original
            return nil
        }
        input.removeFirst(intPrefix.count)
        return match
    }
}

extension Parser where Output == Double {
    public static let double = Self { input in
        let original = input
        let sign: Double
        if input.first == "-" {
            sign = -1
            input.removeFirst()
        } else if input.first == "+" {
            sign = 1
            input.removeFirst()
        } else {
            sign = 1
        }

        var decimalCount = 0
        let prefix = input.prefix { char in
            if char == "." { decimalCount += 1 }
            return char.isNumber || (char == "." && decimalCount <= 1)
        }

        guard let match = Double(prefix)
        else {
            input = original
            return nil
        }

        input.removeFirst(prefix.count)

        return match * sign
    }
}

extension Parser where Output == Float {
    public static let float = Self { input in
        let original = input
        let sign: Float
        if input.first == "-" {
            sign = -1
            input.removeFirst()
        } else if input.first == "+" {
            sign = 1
            input.removeFirst()
        } else {
            sign = 1
        }

        var decimalCount = 0
        let prefix = input.prefix { char in
            if char == "." { decimalCount += 1 }
            return char.isNumber || (char == "." && decimalCount <= 1)
        }

        guard let match = Float(prefix)
        else {
            input = original
            return nil
        }

        input.removeFirst(prefix.count)

        return match * sign
    }
}

extension Parser where Output == Character {
    public static let char = Self { input in
        guard !input.isEmpty else { return nil }
        return input.removeFirst()
    }
}

extension Parser where Output == Void {
    public static func prefix(_ p: String) -> Self {
        Self { input in
            guard input.hasPrefix(p) else { return nil }
            input.removeFirst(p.count)
            return ()
        }
    }

    public static let zeroOrMoreSpaces = prefix(while: { $0 == " " }).map { _ in () }
    public static let oneOrMoreSpaces = prefix(while: { $0 == " " }).flatMap { $0.isEmpty ? .never : always(()) }
}

extension Parser: ExpressibleByStringLiteral where Output == Void {
    public typealias StringLiteralType = String

    public init(stringLiteral value: String) {
        self = .prefix(value)
    }
}

extension Parser: ExpressibleByUnicodeScalarLiteral where Output == Void {
    public typealias UnicodeScalarLiteralType = StringLiteralType
}

extension Parser: ExpressibleByExtendedGraphemeClusterLiteral where Output == Void {
    public typealias ExtendedGraphemeClusterLiteralType = StringLiteralType
}

extension Parser where Output == Substring {
    static func prefix(upTo substring: Substring) -> Self {
        Self { input in
          guard let endIndex = input.range(of: substring)?.lowerBound
          else { return nil }

          let match = input[..<endIndex]

          input = input[endIndex...]

          return match
        }
    }

    static func prefix(through substring: Substring) -> Self {
      Self { input in
        guard let endIndex = input.range(of: substring)?.upperBound
        else { return nil }

        let match = input[..<endIndex]

        input = input[endIndex...]

        return match
      }
    }
}
