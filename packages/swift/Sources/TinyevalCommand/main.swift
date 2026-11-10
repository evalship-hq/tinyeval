// `swift run tinyeval`: runs the bundled runner with bash, in place of this process, so stdin, stdout, stderr,
// Ctrl-C and the exit code are bash's.
import Foundation
#if canImport(Glibc)
import Glibc  // Foundation may not re-export it on Linux
#endif

let runner = Bundle.module.path(forResource: "tinyeval", ofType: nil)!  // packages/swift/mirror.sh puts it there
setenv("TINYEVAL_PACKAGE_UPDATE", "swift package update tinyeval-swift", 1)
var argv = (["bash", runner] + CommandLine.arguments.dropFirst()).map { strdup($0) } + [nil]
execvp("bash", &argv)
FileHandle.standardError.write(Data("tinyeval needs bash 3.2 or later\n".utf8))
exit(2)
