#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[os, logging]


var logger {.threadvar.} : ConsoleLogger
logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")


type
    BundleFileStructure* = object
        relPath*: string
        parentDir*: string
        fileName*: string
        data*: string


method `parentDir=`*(self: BundleFileStructure, parentDir: string) {.base.} =
    self.parentDir = parentDir
    self.relPath = parentDir / self.fileName

method fileName*(self: BundleFileStructure): string {.base.} =
  result = self.fileName

method `fileName=`*(self: BundleFileStructure, fileName: string) {.base.} =
    self.fileName = fileName
    self.relPath = self.parentDir / fileName


proc bundle*(dirToBundle: string): seq[BundleFileStructure] =
    for relPath in walkDirRec(dirToBundle):
        var fs = BundleFileStructure()
        fs.relPath = relPath
        var (parentDir, fileName) = splitPath(relPath)
        fs.parentDir = parentDir
        fs.fileName = fileName
        fs.data = slurp(relPath)
        result.add(fs)


proc extract*(bundle: seq[BundleFileStructure]) =
    logging.log(lvlDebug, "Extracting a bundle!")
    for d in bundle:
        if not fileExists(d.relPath):
            logging.log(lvlDebug, "Writing ", d.relPath)
            createDir(d.parentDir)
            var tmpF = open(d.relPath, fmWrite)
            tmpF.write d.data
        else:
            logging.log(lvlDebug, "File exists skipping ", d.relPath)


when isMainModule:
    echo ":: TESTING BUNDLES ::"
    const webDir = bundle("web")
    extract(webDir)
