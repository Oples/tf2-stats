#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[json, times]

type
    TeamSwitch* = ref object
        ## A mark to log a player switching sides
        player*: string
        time*: Time
        teamBalance*: bool

method toJson*(self: TeamSwitch): JsonNode {.base.} =
    result = newJObject()
    result.add("player", newJString($self.player))
    result.add("time", newJString($self.time))
    result.add("teamBalance", newJString($self.teamBalance))
