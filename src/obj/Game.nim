#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[json, logging]
import Match


var logger {.threadvar.}: ConsoleLogger
logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")


##
##   Game class
##
type
    Game* = ref object of RootObj
        match*: seq[Match]


proc newGame*(): Game =
    new(result)
    result.match = @[]


method newMatch*(self: var Game, server_ip: string, map_name: string = ""): Match {.base.} =
    var new_match: Match

    new_match = newMatch(
        server_ip,
        map_name,
        side = false,
        sideId = 3,
    )
    self.match.add(new_match)
    return new_match


method currentMatch*(self: var Game): Match {.base.} =
    var last_i = len(self.match) - 1
    if not (last_i < 0):
        return self.match[last_i]
    else:
        return newMatch()


method toJson*(self: Game): JsonNode {.base.} =
    var json_node = newJObject()
    var arr = newJArray()
    for m in self.match:
        arr.add(m.toJson)
    json_node.add("matches", arr)

    return json_node


proc saveJSON*(json_par: JsonNode, filePath: string) =
    try:
        writeFile(filePath, pretty(json_par))
    except IOError:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        logger.log(lvlError, "ERROR: ", repr(e), " with ", msg)
