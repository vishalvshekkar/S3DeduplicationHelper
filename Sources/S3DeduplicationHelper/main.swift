import Foundation
import S3DeduplicationHelperCore

let tool = S3DeduplicationHelper()

do {
    try tool.run()
} catch {
    print("Error: \(error)")
}

dispatchMain()
