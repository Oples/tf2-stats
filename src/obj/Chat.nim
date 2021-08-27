#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import times
import json
import Player


##
##   chat class
##
type
    Chat* = ref object
        time: Time
        spectator: bool
        dead: bool # (dead) the player wrote when he was dead
        team: bool # (team) message sent to team
        text: string # The message itself
        player: Player # The player who sent it


proc newMsg*(spectator: bool, dead: bool, team: bool, text: string, player: Player): Chat =
    new(result)
    result.time = getTime()
    result.spectator = spectator
    result.dead = dead
    result.team = team
    result.player = player
    result.text = text


method toJson*(self: Chat): JsonNode {.base.} =
    ##[
        ```json
        {
            "spectator" : false,
            "dead" : true,
            "team" : true,
            "player" : "Oples"
            "text" : "gg"
        }
        ```
    ]##
    var json_node = newJObject()
    #json_node.add("time", newJString($self.time.utc))
    json_node.add("spectator", newJBool(self.spectator))
    json_node.add("dead", newJBool(self.dead))
    json_node.add("team", newJBool(self.team))
    json_node.add("player", newJString(self.player.name))
    json_node.add("text", newJString(self.text))
    return json_node
