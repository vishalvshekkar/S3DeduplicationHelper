import Foundation
import Files
import S3

public final class S3DeduplicationHelper {

    private let maxKeysToFetch = 1000
    private let maxIterationCount = 1000

    private let arguments: [String]
    private let s3 = S3(region: .apsouth1)
    private var objects = [(key: String, eTag: String, size: Int64, modifiedDate: String)]()
    private var commonObjects = [String: [(key: String, size: Int64, modifiedDate: String)]]()
    private var csvStorageURL: URL?
    private var bucketName = ""

    public init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }

    public func run() throws {
        guard arguments.count == 4 else {
            throw Error.missingArguments
        }
        bucketName = arguments[1]
        let bucketKey = arguments[2]
        let workingDirectory = arguments[3]
        self.csvStorageURL = URL(fileURLWithPath: workingDirectory).appendingPathComponent("\(bucketName)-ObjectsList-\(Int(Date().timeIntervalSince1970)).csv")
        print("---Started---")
        createCSVFile()
        listObjects(bucketName: bucketName, continuationToken: nil, prefix: bucketKey, iterationCount: 0, isInitial: true)
    }

    private func listObjects(bucketName: String, continuationToken: String?, prefix: String, iterationCount: Int, isInitial: Bool = false) {
        if !isInitial && continuationToken == nil {
            print("End of bucket objects")
            print("---Completed---")
            print("\(self.objects.count) Keys obtained.")
            self.findUniqueKeys()
            print("\(self.commonObjects.count) Unique Keys found.")
            print("Exiting...")
            exit(EXIT_SUCCESS)
        }
        let request = S3.ListObjectsV2Request(bucket: bucketName, continuationToken: continuationToken, maxKeys: maxKeysToFetch, prefix: prefix)
        print("S3 Request made: \(iterationCount)")
        s3.listObjectsV2(request).whenSuccess({ output in
            print("S3 Request responded: \(iterationCount) with \(String(describing: output.keyCount))")
            let nextContinuationToken = output.nextContinuationToken
            let contents = output.contents
            var batchObjects = [(key: String, eTag: String, size: Int64, modifiedDate: String)]()
            contents?.forEach({ (object) in
                if let key = object.key, let eTag = object.eTag, let size = object.size, let lastModified = object.lastModified?.stringValue {
                    batchObjects.append((key, eTag, size, lastModified))
                    self.objects.append((key, eTag, size, lastModified))
                }
            })
            self.addToCSV(objectsToAdd: batchObjects)
            if let nextContinuationToken = nextContinuationToken, iterationCount < self.maxIterationCount {
                self.listObjects(bucketName: bucketName, continuationToken: nextContinuationToken, prefix: prefix, iterationCount: iterationCount+1)
            } else {
                print("End of iteration count or no continuationToken")
                print("---Completed---")
                print("\(self.objects.count) Keys obtained.")
                self.findUniqueKeys()
                print("Exiting...")
                exit(EXIT_SUCCESS)
            }
        })
    }

    private func createCSVFile() {
        print("Creating CSV at \(String(describing: csvStorageURL?.path))")
        let csvHeaders = "key,eTag,size,modifiedDate\n"
        if let csvStorageURL = csvStorageURL {
            do {
                try csvHeaders.write(to: csvStorageURL, atomically: true, encoding: .utf8)
                print("Success: Created CSV at \(String(describing: csvStorageURL.path))")
            } catch {
                print("Failure: CSV Could not write to \(csvStorageURL.path)")
            }
        } else {
            print("Failure: CSV Could not write to \(csvStorageURL?.path ?? "given path")")
        }
    }

    private func findUniqueKeys() {
        print("Finding Unique keys")
        print("\(Date())")
        objects.forEach { (object) in
            if let _ = commonObjects[object.eTag] {
                commonObjects[object.eTag]?.append((object.key, object.size, object.modifiedDate))
            } else {
                commonObjects[object.eTag] = [(object.key, object.size, object.modifiedDate)]
            }
        }
        var highestCount = (0, "")
        commonObjects.forEach { (object) in
            let objectRepeatCount = object.value.count
            if objectRepeatCount > highestCount.0 {
                highestCount = (objectRepeatCount, object.key)
            }
        }
        print("Highest Repeated count = \(highestCount.0) : ETag: \(highestCount.1)")
        print("Total Unique Keys found. = \(commonObjects.count)")
        print("Finished finding Unique keys")
        print("\(Date())")
    }

    private func addToCSV(objectsToAdd: [(key: String, eTag: String, size: Int64, modifiedDate: String)]) {
        guard let csvStorageURL = csvStorageURL else { return }
        let csvString = objectsToAdd.reduce("") { (result, object) -> String in
            return result + "\(object.key),\(object.eTag),\(object.size),\(object.modifiedDate)\n"
        }
        guard let csvData = csvString.data(using: .utf8) else { return }
        do {
            let fileHandle = try FileHandle(forWritingTo: csvStorageURL)
            if #available(OSX 10.15, *) {
                try fileHandle.seekToEnd()
            }
            fileHandle.write(csvData)
            fileHandle.closeFile()
        } catch {
            print(error)
        }
    }

//    private func writeCSV() {
//        print("Writing to Csv...")
//        let csvString = objects.reduce("key,eTag,size,modifiedDate\n") { (result, object) -> String in
//            return result + "\(object.key),\(object.eTag),\(object.size),\(object.modifiedDate)\n"
//        }
//        if let workingDirectory = workingDirectory {
//            let fileName = "\(bucketName)-ObjectsList-\(Int(Date().timeIntervalSince1970)).csv"
//            do {
//                try csvString.write(to: workingDirectory.appendingPathComponent(fileName), atomically: true, encoding: .utf8)
//            } catch {
//                print("Failed to write to \(workingDirectory.path)")
//            }
//        } else {
//            print("Failed to write to \(workingDirectory?.path ?? "given path")")
//        }
//    }

}

public extension S3DeduplicationHelper {
    enum Error: Swift.Error {
        case missingArguments
        case failedToCreateFile
    }
}
