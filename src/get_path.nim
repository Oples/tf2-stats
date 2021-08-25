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
when(appType == "gui"):
    import nigui
    import nigui/msgbox

var logger = newConsoleLogger(levelThreshold=lvlAll, fmtStr="[$time] - $levelname: ")


proc getFileWindow(): string =
    var logPath {.threadvar.} : string
    logPath = ""

    when(appType == "gui"):
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
        setupDescTextBox.editable = false
        setupDescTextBox.text = ("""
            WARNING! The Steam installation path was not found
            or Team Fortress 2 is not installed

            please select a `console.log` file to load it's contents!
            """.unindent)
        container.add(setupDescTextBox)

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
                echo "Custom location (console.log)"
                result = readLineFromStdin("$ ")

            echo "You confirm this directory?"
            stdout.write result & " [Y/n] "

            let answer = getch()
            echo answer

            if(answer != 'y' and answer != 'Y' and answer != '\r'):
                result = ""

    when(appType == "gui"):
        getFileWindow()


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
