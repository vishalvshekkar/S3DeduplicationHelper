import Foundation
import Files
import S3

/**
 This is the class that contains the logic for listing objects in a bucket and finding duplicate objects. This is present in a package of its own to be included as part of other applications/tools. Currently, it exists as a CLI.
 */
public final class S3DeduplicationHelper {

    /**
     The total number of object keys to fetch per `object-list-v2` call. As of writing this, AWS has a max limit of 1000. So, this cannot be greater than 1000.

     The total number of keys fetched would be
     ```
     min(
        (maxKeyToFetch*maxIterationCount),
        TOTAL_KEYS_UNDER_GIVEN_PREFIX
     )
     ```
     */
    private let maxKeysToFetch = 1000

    /**
    The total number of times `object-list-v2` call will be made. The logic is written in such a way as to fetch the next page of object keys each iteration.

    The total number of keys fetched would be
    ```
    min(
       (maxKeyToFetch*maxIterationCount),
       TOTAL_KEYS_UNDER_GIVEN_PREFIX
    )
    ```
    */
    private let maxIterationCount = 1000

    /**
     Stores the arguments passed during the invocation of the script.
     */
    private let arguments: [String]

    /**
     The object that provides an interface into S3 operations.
     */
    private let s3 = S3(region: .apsouth1)

    /**
     An array that holds info of all the fetched S3 objects.
     */
    private var objects = [(key: String, eTag: String, size: Int64, modifiedDate: String)]()

    /**
     A dictionary that holds all the S3 objects that are grouped by their `ETag`s as the dictionary keys.
     */
    private var commonObjects = [String: [(key: String, size: Int64, modifiedDate: String)]]()

    /**
     The file path where the working CSV would be stored.
     */
    private var csvStorageURL: URL?

    /**
     Holds the S3 bucket name on which the operation is being done.
     */
    private var bucketName = ""

    /**
     An initializer with CLI arguments as parameters.
     */
    public init(arguments: [String] = CommandLine.arguments) {
        self.arguments = arguments
    }

    /**
     The function that is invoked when the scipt is invoked. This starts the operations.
     */
    public func run() throws {

        //Checking for predetermined argument count. The first one would be the name of the script.
        guard arguments.count == 4 else {
            throw Error.missingArguments
        }
        bucketName = arguments[1]
        let bucketKey = arguments[2]
        let workingDirectory = arguments[3]
        self.csvStorageURL = URL(fileURLWithPath: workingDirectory).appendingPathComponent("\(bucketName)-ObjectsList-\(Int(Date().timeIntervalSince1970)).csv")
        print("---Started---")
        createCSVFile()

        //The list object process is started with the first page.
        listObjects(bucketName: bucketName, continuationToken: nil, prefix: bucketKey, iterationCount: 0, isInitial: true)
    }

    /**
     This fucntion fetches the S3 bucket objects. Each call to this function will make one call to list-objects-v2, either the first page or one of the subsequent pages. This is a function that calls itself recursively until eithert the iteration limit has been reached, or the S3 bucklet has no more objects to list.
     - parameter bucketName: Name of the S3 bucket to perform list operation on.
     - parameter continuationToken: The token returned by a previous call to list-objects-v2 that specifies a marker to fetch the next page.
     - parameter prefix: The bucket key prefix to fetch keys only under the given prefix.
     - parameter iterationCount: An index to keep track of the iteration.
     - parameter isInitial: A boolean that tells the fucntion if this was the starting call or on of the subsequent ones.
     */
    private func listObjects(bucketName: String, continuationToken: String?, prefix: String, iterationCount: Int, isInitial: Bool = false) {
        if !isInitial && continuationToken == nil {
            print("End of bucket objects")
            print("---Completed---")
            print("\(self.objects.count) Keys obtained.")
            self.findUniqueKeys()
            print("\(self.commonObjects.count) Unique Keys found.")
            print("Exiting...")

            //This ensures that the CLI interface exits since the tool has completed its operations.
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

                //This ensures that the CLI interface exits since the tool has completed its operations.
                exit(EXIT_SUCCESS)
            }
        })
    }

    /**
     Creates the skeleton CSV file at the relevant location. This would be used by following operations to write into.
     */
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

    /**
     This function finds the unique keys by grouping them by their `ETag`s.
     */
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

    /**
     This fucntion adds data to the previously created CSV additively.
     - parameter objectsToAdd: the array of data to add on to the CSV.
     */
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

/**
 An extension of `S3DeduplicationHelper` that defines the Error pertaining to this operation.
 */
public extension S3DeduplicationHelper {

    enum Error: Swift.Error {

        case missingArguments
        case failedToCreateFile

    }

}
