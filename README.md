# S3DeduplicationHelper

A swift-cli tool to fetch all objects in an S3 bucket filtered by a key prefix and provide mechasnisms to find duplicates among those keys using eTag and size of each objects.

## What does this tool do?

Each object added to an AWS S3 bucket has something called an `ETag` (Entity Tag) attributed to it. This is a hash of the file content without considering the meta data. This hash is not always md5.

This is what the [AWS doc](https://docs.aws.amazon.com/AmazonS3/latest/API/RESTCommonResponseHeaders.html) has to say about `ETag`.
> The entity tag is a hash of the object. The ETag reflects changes only to the contents of an object, not its metadata. The ETag may or may not be an MD5 digest of the object data. Whether or not it is depends on how the object was created and how it is encrypted as described below:
>Objects created by the PUT Object, POST Object, or Copy operation, or through the AWS Management Console, and are encrypted by SSE-S3 or plaintext, have ETags that are an MD5 digest of their object data.
>Objects created by the PUT Object, POST Object, or Copy operation, or through the AWS Management Console, and are encrypted by SSE-C or SSE-KMS, have ETags that are not an MD5 digest of their object data.
>If an object is created by either the Multipart Upload or Part Copy operation, the ETag is not an MD5 digest, regardless of the method of encryption.
>Type: String

This script first fetches the ETags of all the qualifying objects under the given key prefix. It then groups the keys based on exact match of their `ETag`s. It outputs the total number of keys found, the total number of unique keys (by omitting the keys with duplicate `ETag`s), and the highest duplicate count of any `ETag`. Beyond this, it generates a `.csv` file with all the data required to analyze this and stores it in the directory specific to the tool during invocation. The CSV file names are timestamped (with second precision) so you can run the tool multiple times without the risk of overwriting the older ones.

## Features

- This tool is able to handle large buckets without any issues. (Tested with over 1 Million objects.)
- This tool writes into large CSV files without issues as the writes happen in batches. (Make sure you don't modify the file while the script is running to ensure integrity.)

## Warning ⚠️

This tool would perform `object-list-v2` calls on your S3 bucket. These calls are chargeable by AWS. Beware.

## Suggested Running Mechanism

Modify `maxKeyToFetch` and `maxIterationCount` values to limit the maxinum bumber of `object-list-v2` calls that would be made by the tool. Before you do this, have a basic idea about how many objects would exist in the said bucket under the given prefix and modify the parameters accordingly.

Parameter | Description
----|----
`maxKeyToFetch` | Maximum number of keys to fetch per call made to `object-list-v2`. The upper limit set by AWS is 1000.
`maxIterationCount` | Maximum number of iterations of `object-list-v2` to make. The final number of keys obtained would be `min((maxKeyToFetch*maxIterationCount), TOTAL_KEYS_UNDER_GIVEN_PREFIX)`

## Prerequisites

- A system running a compatible OS with swift >=5 installed.
- `.aws` directory in your home directory holding a credentials file with credentials to your AWS account. This user credentials must have permissions to the S3 bucket operations required by this script. As of now, that's `list-objects` (Not tested thoroughly, may need more permissions).
- Basic expereince with using swift, SPM (swift package manager), and git.

## Installation

1. Clone the repository to a desired place in your file system.
```
git clone https://github.com/vishalvshekkar/S3DeduplicationHelper.git
```

2. Then, `cd` into the cloned directory.
```
cd S3DeduplicationHelper
```

3. Run a package update on the swift packages.
Ensure that you have swift >=5 installed.
```
swift package update
```

4. (Optional) Generate an Xcode project from these files, if you like using Xcode. You can skip otherwise.
```
swift package generate-xcodeproj
```

5. Build your tool.
```
swift build
```

6. (Optional | Not required) Run your tool just for the sake of it.
```
swift run
```
Note: This would not do anything meaningful as the tool was invoked without any parameters.

7. Create a release build.
```
swift build -c release
```

8. Change directory to where your executable exists. That would be under the `.build` folder which is hidden.
```
cd .build/release
```

9. Invoke the CLI tool as shown below
```
swift run S3DeduplicationHelper <S3_BUCKET_NAME> <S3_BUCKET_KEY_PREFIX> <PATH_TO_A_LOCAL_DIRECTORY_TO_STORE_OUTPUT_CSV>
```

Parameter | Description
--- | ---
`<S3_BUCKET_NAME>` | Replace this with your bucket name.
`<S3_BUCKET_KEY_PREFIX>` | Add a key prefix to fetch objects only under a certain key prefix.
`<PATH_TO_A_LOCAL_DIRECTORY_TO_STORE_OUTPUT_CSV>` | A local directory on your machine where the generate CSV would be stored.

## TO-Do

- [X] List all objects given a bucket and key prefix.
- [X] Generate CSV forn posterity and out-of-tool use and analysis.
- [X] Find duplicates in listed objets using `ETag`.
- [ ] Add tests.
- [ ] Document code better.
- [ ] Improvement to the exposed CLI.
- [ ] Add help to the CLI.
- [ ] Consider size of file as a parameter in finding duplicates
- [ ] Allow a delete, move, or tag option on the duplicates found.

## Contributions
Any contribution to the tool is welcome and much-appreciated.
No need for elaborate processes, raise an issue or a merge-request with enough info for me to go on about it.

As Dwight would say,
![Dwight_Says](/images/dwight-says.jpg)
>KISS - Keep it simple stupid.

## (personal use of the author)

The tool was created by starting with the following command.
```
swift package init --type executable
```
