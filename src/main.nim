#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import web_server
import utils/get_path

when isMainModule:
    FilePath = getTF2Path()
    startTF2Logger()
