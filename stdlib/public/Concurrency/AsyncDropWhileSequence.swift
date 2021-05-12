//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Swift

@available(SwiftStdlib 5.5, *)
extension AsyncSequence {
  /// Omits elements from the base asynchronous sequence until a given closure
  /// returns false, after which it passes through all remaining elements.
  ///
  /// Use `drop(while:)` to omit elements from an asynchronous sequence until
  /// the element received meets a condition you specify.
  ///
  /// In this example, an asynchronous sequence called `Counter` produces `Int`
  /// values from `1` to `10`. The `drop(while:)` function causes the modified
  /// sequence to ignore the values `1` through `4`, and instead emit
  /// `5` through `10`:
  ///
  ///     for try await number in Counter(howHigh: 10)
  ///             .drop(while: { $0 < 5 } ) {
  ///         print("\(number) ", terminator: " ")
  ///     }
  ///     // prints "5 6 7 8 9 10"
  ///
  /// After the predicate returns `false`, the sequence never executes it again,
  /// and from then on the sequence passes through elements from its underlying
  /// sequence as-is.
  ///
  /// - Parameter predicate: A closure that takes an element as a parameter and
  ///   returns a Boolean value indicating whether to drop the element from the
  ///   modified sequence.
  /// - Returns: An `AsyncDropWhileSequence` that skips over values from the
  ///   base sequence until the provided closure returns `false`.
  @inlinable
  public __consuming func drop(
    while predicate: @escaping (Element) async -> Bool
  ) -> AsyncDropWhileSequence<Self> {
    AsyncDropWhileSequence(self, predicate: predicate)
  }
}

/// An asynchronous sequence which omits elements from the base sequence until a
/// given closure returns false, after which it passes through all remaining
/// elements.
@available(SwiftStdlib 5.5, *)
public struct AsyncDropWhileSequence<Base: AsyncSequence> {
  @usableFromInline
  let base: Base

  @usableFromInline
  let predicate: (Base.Element) async -> Bool

  @usableFromInline
  init(
    _ base: Base, 
    predicate: @escaping (Base.Element) async -> Bool
  ) {
    self.base = base
    self.predicate = predicate
  }
}

@available(SwiftStdlib 5.5, *)
extension AsyncDropWhileSequence: AsyncSequence {
  
  /// The type of element produced by this asynchronous sequence.
  ///
  /// The drop-while sequence iterator produces whatever type of element its
  /// base iterator produces.
  public typealias Element = Base.Element
  /// The type of iterator that produces elements of the sequence.
  public typealias AsyncIterator = Iterator

  /// The iterator that produces elements of the drop-while sequence.
  public struct Iterator: AsyncIteratorProtocol {
    @usableFromInline
    var baseIterator: Base.AsyncIterator

    @usableFromInline
    var predicate: ((Base.Element) async -> Bool)?

    @usableFromInline
    init(
      _ baseIterator: Base.AsyncIterator, 
      predicate: @escaping (Base.Element) async -> Bool
    ) {
      self.baseIterator = baseIterator
      self.predicate = predicate
    }

    @inlinable
    /// Produces the next element in the drop-while sequence.
    ///
    /// This iterator calls `next()` on its base iterator and evaluates the
    /// result with the `predicate` closure. As long as the predicate returns
    /// `true`, this method returns `nil`. After the predicate returns `false`,
    /// for a value received from the base iterator, this method returns that
    /// value. After that, the iterator returns values received from its
    /// base iterator as-is, and never executes the predicate closure again.
    public mutating func next() async rethrows -> Base.Element? {
      while let predicate = self.predicate {
        guard let element = try await baseIterator.next() else {
          return nil
        }
        if await predicate(element) == false {
          self.predicate = nil
          return element
        }
      }
      return try await baseIterator.next()
    }
  }

  @inlinable
  /// Creates an instance of the drop-while sequence iterator.
  public __consuming func makeAsyncIterator() -> Iterator {
    return Iterator(base.makeAsyncIterator(), predicate: predicate)
  }
}
