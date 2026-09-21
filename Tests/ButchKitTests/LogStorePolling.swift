import Foundation

/// The unified logging system takes a message asynchronously, so it is not guaranteed to be
/// readable on the very next statement. Poll until `read` returns a value rather than reading
/// once and failing on a loaded machine.
func waitForResult<T>(
    timeout: Duration = .seconds(15),
    _ read: () async throws -> T?
) async throws -> T? {
    let deadline = ContinuousClock.now + timeout
    while ContinuousClock.now < deadline {
        if let result = try await read() { return result }
        try await Task.sleep(for: .milliseconds(200))
    }
    return try await read()
}
