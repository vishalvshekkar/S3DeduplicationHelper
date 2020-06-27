import Foundation
import S3DeduplicationHelperCore

/**
 The instance of `S3DeduplicationHelper` that would be used to run the operations.
 */
let tool = S3DeduplicationHelper()

do {
    try tool.run()
} catch {
    print("Error: \(error)")
}

// This ensures that the CLI operation doesn't exit and waits until other asynchronous operations complete.
dispatchMain()
