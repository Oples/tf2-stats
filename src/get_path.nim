#                                                  #
# Under MIT License                                #
# Author: (c) 2020 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import os
from terminal import getch
import rdstdin
import logging
import strutils
import regex
when defined(windows):
    import registry

var logger = newConsoleLogger(levelThreshold=lvlAll, fmtStr="[$time] - $levelname: ")

proc getCustomConsoleLogPath*(): string =
    if(appType == "console"):
        while(result == "" or not fileExists(result)):
            echo "Custom location (console.log)"
            result = readLineFromStdin("$ ")

        echo "You confirm this directory?"
        stdout.write result & " [Y/n] "

        let answer = getch()
        echo answer

        if(answer != 'y' and answer != 'Y' and answer != '\n'):
            return ""


proc getTF2Path*(): string =
    var
        steamLauncherInstallPath: string
        steamPossibleLibraries : seq[string]
    let
        SteapApps = "steamapps"
        LibraryLocationFile = "libraryfolders.vdf"
        TF2Common = "common" / "Team Fortress 2"
        TF2LogPath = "tf"

    logger.log(lvlInfo, "Trying to search for the Team Fortress 2 directory")

    when defined(windows):
        var steamInstallDir: string
        # get hw key
        # https://github.com/coalpha/lang-archives/blob/master/nim/steam_install.nim
        # ty coalpha
        logger.log(lvlDebug, "(Windows) getting the Steam Launcher location")
        try:
            steamInstallDir = (
                getUnicodeValue(
                    r"SOFTWARE\Wow6432Node\Valve\Steam",
                    "InstallPath",
                    HKEY_LOCAL_MACHINE
                )
            )
        except OSError:
            logger.log(lvlError, "Got beaned trying to get a reg val:")
            echo getCurrentExceptionMsg()

        steamLauncherInstallPath = steamInstallDir / SteapApps

    when defined(linux):
        logger.log(lvlDebug, "(Linux) getting the Steam Launcher location")
        steamLauncherInstallPath = getHomeDir() / ".steam" / "steam" / SteapApps


    if(dirExists(steamLauncherInstallPath)):
        # in the steam launcher get the library location file
        logger.log(lvlDebug, "Auto found the Steam Launcher location\n")
        logger.log(lvlDebug, steamLauncherInstallPath,"\n")

        steamPossibleLibraries.add(steamLauncherInstallPath)

        let libraryLocationPath = steamLauncherInstallPath / LibraryLocationFile

        logger.log(lvlDebug, "Checking ", LibraryLocationFile, " for other locations")
        if fileExists(libraryLocationPath):
            # red the vdf file
            var libraryVdfFile : File
            var m : RegexMatch
            var vdfAll : string
            var vdfSplit : seq[string]

            libraryVdfFile = open(libraryLocationPath)
            vdfAll = readAll(libraryVdfFile)
            libraryVdfFile.close()

            vdfSplit = vdfAll.split("\n")

            for vdfLine in vdfSplit:
                if vdfLine.match(re"""^[\t: ]*?"[0-9]+"[\t: ]*?"(.*)"$""", m): #" # Atom syntax parser goes nuts with """
                    steamPossibleLibraries.add(m.groupFirstCapture(0, vdfLine) / SteapApps)

        else:
            logger.log(lvlWarn, LibraryLocationFile, " is missing")

        var TF2InstallPath : seq[string]

        for sLib in steamPossibleLibraries:
            logger.log(lvlDebug, sLib)
            if dirExists(sLib  / TF2Common / TF2LogPath):
                TF2InstallPath.add(sLib  / TF2Common / TF2LogPath)


        logger.log(lvlDebug, "Libraries found:\n")

        for sLib in TF2InstallPath:
            logger.log(lvlDebug, sLib)

        if TF2InstallPath.len() == 1:
            result = TF2InstallPath[0]
        else:
            # ambiguity multiple installs or none?
            result = getCustomConsoleLogPath()
    else:
        logger.log(lvlWarn, "No Steam Launcher install path found")
        result = getCustomConsoleLogPath()


when isMainModule:
    var (dir, module_name, ext) = splitFile(currentSourcePath())

    logger.log(lvlInfo, "HHHHHHHHHH ", module_name, " HHHHHHHHHH")
    logger.log(lvlInfo, "")

    let res = getTF2Path()

    logger.log(lvlInfo, "")
    logger.log(lvlInfo, "HHHHHHHHHH result HHHHHHHHHH")
    logger.log(lvlInfo, "")
    logger.log(lvlInfo, res)
    logger.log(lvlInfo, "")

