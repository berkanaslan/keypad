extension KeyedDecodingContainer {
    /// The value for `key`, or `nil` when it is missing or unreadable, so one bad field never discards the rest.
    func value<Value: Decodable>(_ type: Value.Type, for key: Key) -> Value? {
        (try? decodeIfPresent(type, forKey: key)) ?? nil
    }
}
