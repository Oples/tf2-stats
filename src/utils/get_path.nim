#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import os
from terminal import getch
import rdstdin
import logging
import strutils
import regex
import std/strformat
when defined(windows):
    import registry
when(appType == "gui"):
    import nigui
    import nigui/msgbox


var logger {.threadvar.} : ConsoleLogger
logger = newConsoleLogger(levelThreshold=lvlAll, fmtStr="[$time] - $levelname: ")

const ConsoleFName = "console.log"

when(appType == "gui"):
    proc getFileWindow(): string =
        var logPath {.threadvar.} : string
        logPath = ""

        app.init()

        var window = newWindow("TF2 Logger")

        proc quitMsgProc() =
            case window.msgBox("Do you want to quit?", "Quit", "Quit", "Cancel")
            of 1:
                window.dispose()
                app.quit()
                quit(0)
            else: discard

        window.onCloseClick = proc(event: CloseClickEvent) =
            quitMsgProc()

        window.width = 400.scaleToDpi
        window.height = 300.scaleToDpi
        # window.iconPath = "tf2logger-ico.png"

        var container = newLayoutContainer(Layout_Vertical)
        container.heightMode = HeightMode_Fill
        container.widthMode = WidthMode_Fill
        container.padding = 0.scaleToDpi
        container.spacing = 0.scaleToDpi
        window.add(container)

        var setupDescTextBox = newTextArea()
        container.add(setupDescTextBox)
        setupDescTextBox.editable = false
        setupDescTextBox.text = (fmt"""
            WARNING!

            The Steam installation path was not found or Team Fortress 2 is not installed

            please select the `{ConsoleFName}` file to load it's contents!

            """.unindent)

        var buttons = newLayoutContainer(Layout_Horizontal)
        buttons.widthMode = WidthMode_Fill
        buttons.xAlign = XAlign_Right
        buttons.padding = 8.scaleToDpi
        buttons.spacing = 2.scaleToDpi
        container.add(buttons)

        var buttonOpen = newButton("Open ...")
        buttons.add(buttonOpen)

        var buttonCancel = newButton("Cancel")
        buttons.add(buttonCancel)

        var buttonFinish = newButton("Continue")
        buttons.add(buttonFinish)
        buttonFinish.enabled = false


        buttonOpen.onClick = proc(event: ClickEvent) =
            var dialog = newOpenFileDialog()
            dialog.title = "Open file"
            dialog.multiple = false
            dialog.run()
            if dialog.files.len > 0:
                for file in dialog.files:
                    setupDescTextBox.text = setupDescTextBox.text & "\n\n" & (file)
                    buttonFinish.enabled = true
                    logPath = file

        buttonFinish.onClick = proc(event: ClickEvent) =
            window.dispose()
            app.quit()

        buttonCancel.onClick = proc(event: ClickEvent) =
            quitMsgProc()

        window.show()
        app.run()

        result = logPath


proc getCustomConsoleLogPath*(): string =
    when(appType == "console"):
        while(result == ""):
            while(result == "" or not fileExists(result)):
                echo fmt"Custom log path ({ConsoleFName})"
                result = readLineFromStdin("$ ")
                if result == "ls" or result.startsWith("ls "):
                    # TODO: Add a parameter option for ls to list files in directories
                    for pathWalk in walkFiles("*"):
                      echo pathWalk
                elif not fileExists(result):
                    echo "ERROR: File not found ", result

            echo ""
            #echo "(The program will search for the {ConsoleFName} file or wait if it doesn't exist)" # TODO:
            echo "Do you confirm this path?"
            stdout.write "\"" & result & "\" [Y/n] "

            let answer = getch()
            echo answer

            if(answer != 'y' and answer != 'Y' and answer != '\r'):
                result = ""

    when(appType == "gui"):
        result = getFileWindow()

    logger.log(lvlDebug, "manual log path: " & result)


proc getTF2Path*(): string =
    var
        steamLauncherInstallPath: string
    let
        SteapApps = "steamapps"
        TF2Common = "common" / "Team Fortress 2"
        TF2LogPath = "tf"
        TF2SteamID = "440"

    logger.log(lvlInfo, "Trying to search for the Team Fortress 2 directory")

    when defined(windows):
        var steamInstallDir: string
        # get hw key
        # https://github.com/coalpha/lang-archives/blob/master/nim/steam_install.nim
        # thank you coalpha
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
            logger.log(lvlError, "Got blocked or resource not found while reading a registry value:")
            echo getCurrentExceptionMsg()

        steamLauncherInstallPath = steamInstallDir / SteapApps

    when defined(linux):
        logger.log(lvlDebug, "(Linux) getting the Steam Launcher location")
        steamLauncherInstallPath = getHomeDir() / ".steam" / "steam" / SteapApps


    if(dirExists(steamLauncherInstallPath)):
        let LibraryLocationFile = "libraryfolders.vdf"
        var steamPossibleLibraries : seq[string]

        # in the steam launcher get the library location file
        logger.log(lvlInfo, ":: Auto :: [success!]: found the Steam Launcher location")
        logger.log(lvlInfo, "")
        logger.log(lvlDebug, steamLauncherInstallPath)
        logger.log(lvlDebug, "")

        steamPossibleLibraries.add(steamLauncherInstallPath)

        let libraryLocationPath = steamLauncherInstallPath / LibraryLocationFile

        logger.log(lvlDebug, "Checking ", LibraryLocationFile, " for other locations")
        logger.log(lvlDebug, "")
        if fileExists(libraryLocationPath):
            # red the vdf file
            var libraryVdfFile : File
            var m : RegexMatch
            var vdfAll : string
            var vdfSplit : seq[string]

            libraryVdfFile = open(libraryLocationPath)
            vdfAll = readAll(libraryVdfFile)
            libraryVdfFile.close()

            logger.log(lvlDebug, LibraryLocationFile & "\n", vdfAll)
            vdfSplit = vdfAll.split("\n")

            var path = ""
            for vdfLine in vdfSplit:
                if vdfLine.match(re"""^[\t ]*?"path"[\t: ]*?"(.*)".*?$""", m):
                    path = m.groupFirstCapture(0, vdfLine)
                    logger.log(lvlDebug, "Steam path: ", path)
                    steamPossibleLibraries.add(path)

                if vdfLine.match(re"""^[\t ]*?"([0-9]+)"[\t: ]*?"(.*)".*?$""", m):
                    let appID = m.groupFirstCapture(0, vdfLine)
                    #logger.log(lvlDebug, "app id: ", appID)
                    if appID == TF2SteamID:
                        # Make the possible TF2 path the first one in the search
                        logger.log(lvlDebug, "")
                        logger.log(lvlDebug, "Found the TF2 install folder in: ", path)
                        steamPossibleLibraries.insert(path, 0)
                        discard steamPossibleLibraries.pop()
        else:
            logger.log(lvlWarn, LibraryLocationFile, " is missing")

        var TF2InstallPath : seq[string]

        logger.log(lvlDebug, "")
        logger.log(lvlDebug, "Libraries found:")
        for sLib in steamPossibleLibraries:
            logger.log(lvlDebug, "Lib: ", sLib)
            let tf2ThericalPath = sLib / SteapApps / TF2Common / TF2LogPath
            if dirExists(tf2ThericalPath):
                if not fileExists(tf2ThericalPath / ConsoleFName):
                    logger.log(lvlWarn, "File ", ConsoleFName, " NOT FOUND!")
                else:
                    TF2InstallPath.add(tf2ThericalPath / ConsoleFName)

        # logging
        logger.log(lvlDebug, "")
        logger.log(lvlDebug, "Absolute path of " & ConsoleFName)
        for sLib in TF2InstallPath:
            logger.log(lvlDebug, sLib)
        logger.log(lvlDebug, "")

        if TF2InstallPath.len == 1:
            # Team Fortress 2 Install path found
            result = TF2InstallPath[0]
        else:
            if TF2InstallPath.len > 1:
                # ambiguity multiple installs or none?
                logger.log(lvlWarn, "")
                logger.log(lvlWarn, "Auto fetch found multiple TF2 folders!")
                logger.log(lvlWarn, "Falling back to manual input")
                logger.log(lvlWarn, "")
                #raise newException(RangeDefect , "Ambiguity error: Multiple installs detected!")
            else:
                logger.log(lvlError, "")
                logger.log(lvlError, "Auto fetch found Steam but not the game")
                logger.log(lvlError, "Is the game even installed?")
                logger.log(lvlError, "Anyway fallback to manual input ¯\\_(ツ)_/¯")
                logger.log(lvlError, "")
                #raise newException(RangeDefect , "The Team Fortress 2 folder was not found!")

            result = getCustomConsoleLogPath()

    else:
        logger.log(lvlDebug, "Steam path: ", steamLauncherInstallPath)
        logger.log(lvlWarn, "")
        logger.log(lvlWarn, "The Steam Launcher was not found")
        logger.log(lvlWarn, "Falling back to manual input")
        logger.log(lvlWarn, "")
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
