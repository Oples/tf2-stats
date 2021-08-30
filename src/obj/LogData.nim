#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[json]
import Player
import Chat
import Kill

##
## Generic data to log in chronological order
##
type
    LogData* = ref object of RootObj
        ldType : int       # 0 = ldChat, 1 = ldKill, etc... (enables the use of generic data loging)
        ldPlayer : Player
        ldChat : Chat
        ldKill : Kill
        #ldTeam : TeamBalance


proc newLogData*(data : Chat) : LogData =
    new(result)
    result.ldType = 0
    result.ldChat = data


proc newLogData*(data : Kill) : LogData =
    new(result)
    result.ldType = 1
    result.ldKill = data


proc newLogData*(data : Player) : LogData =
    new(result)
    result.ldType = 2
    result.ldPlayer = data


#[proc newLogData(data : TeamBalance) : LogData =
    new(result)
    result.ldType = 3
    result.ldTeam = data]#


method toJson*(self: LogData): JsonNode {.base.} =
    result = newJObject()
    var data = newJObject()

    case self.ldType:
        of 0:
            data = self.ldChat.toJson()
            result.add("type", newJString($type self.ldChat))
            result.add("data", data)
        of 1:
            data = self.ldKill.toJson()
            result.add("type", newJString($type self.ldKill))
            result.add("data", data)
        of 2:
            data = self.ldPlayer.toJson()
            result.add("type", newJString($type self.ldPlayer))
            result.add("data", data)
        #of 3:
        #    result = self.ldTeam.toJson()
        else:
            result.add("type", newJString("ERROR"))
            result.add("data", newJString("Log obj not supported!"))
