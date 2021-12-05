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
import TeamSwitch

##
## Generic Match data in **chronological** order
##
type
    LogData* = ref object of RootObj
        ldType : int       # 0 = ldChat, 1 = ldKill, etc... (enables the use of generic data loging)
        ldPlayer : Player
        ldChat : Chat
        ldKill : Kill
        ldTeamSwitch : TeamSwitch


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


proc newLogData*(data : TeamSwitch) : LogData =
    new(result)
    result.ldType = 3
    result.ldTeamSwitch = data


method toJson*(self: LogData): JsonNode {.base.} =
    ##[
    **Json sample**
    ```json
    {
        "type": "player",
        "data": {
          "name": "oples",
          "team": 1,
          "teamSwitch": [0, 2]
        }
    }, {
        "type": "ERROR",
        "data": "An explenation of the Error"
    }
    ```
    ]##
    result = newJObject()
    var data = newJObject()

    case self.ldType:
        of 0:
            data = self.ldChat.toJson()
            result.add("type", newJString("chat"))
            result.add("data", data)
        of 1:
            data = self.ldKill.toJson()
            result.add("type", newJString("kill"))
            result.add("data", data)
        of 2:
            data = self.ldPlayer.toJson()
            result.add("type", newJString("player"))
            result.add("data", data)
        of 3:
            data = self.ldTeamSwitch.toJson()
            result.add("type", newJString("teamSwitch"))
            result.add("data", data)

        else:
            result.add("type", newJString("ERROR"))
            result.add("data", newJString("Log obj with id " & $self.ldType & " not supported!"))
