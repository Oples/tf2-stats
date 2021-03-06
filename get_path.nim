#                                                  #
# Under MIT License                                #
# Author: (c) 2020 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import os
from terminal import getch
import rdstdin
import registry

proc getTF2Path*(): string =
    result = ""
    var
        steamlibrary_fp = ""
    let
        TF2Common = "common" / "Team Fortress 2"
        TF2LogPath = "tf"
        TF2LogFilename = "console.log"

    if defined(windows):
        # get hw key
        discard

    if defined(linux):
        steamlibrary_fp = getHomeDir() / ".steam" / "steam" / "steamapps"

    if(dirExists(steamlibrary_fp)):
        result = steamlibrary_fp / TF2Common / TF2LogPath / TF2LogFilename
    else:
        while(result == "" or not fileExists(result)):
            result = readLineFromStdin("dir\r\n: ")

    echo "Are you sure?"
    echo result

    if(getch() != 'y'):
        return ""
