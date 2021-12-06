#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import Player
import Weapon
import std/[json, times]

##
##   Kill class
##
type
    Kill* = ref object
        time: Time
        subject: Player
        subject_side: bool
        target: Player
        target_side: bool
        weapon: Weapon
        crit: bool


proc newKill*(
        subject : Player,
        subject_side : bool,
        target : Player,
        target_side : bool,
        time : Time = Time(),
        weapon : string = "world",
        crit : bool = false) : Kill =

    new(result)
    result.subject = subject
    result.subject_side = subject_side
    result.target = target
    result.target_side = target_side
    result.time = time
    result.weapon = newWeapon(weapon)
    result.crit = crit


method toJson*(self: Kill): JsonNode {.base.} =
    ## **Json sample**
    ##```json
    ##{
    ##  "actor": "Laykeen",
    ##  "weapon" : "quake_rl",
    ##  "crit" : true,
    ##  "target": "Oples"
    ##}
    ##```
    ## Ouch! :D
    var json_node = newJObject()
    #json_node.add("time", newJString($self.time.utc)) # TODO: needs ORM implementation
    json_node.add("actor", newJString(self.subject.name))
    #json_node.add("actorAltSide", newJBool(self.subject_side)) # backend info
    json_node.add("weapon", newJString(self.weapon.name))
    json_node.add("crit", newJBool(self.crit))
    json_node.add("target", newJString(self.target.name))
    #json_node.add("targetAltSide", newJBool(self.target_side)) # backend info

    return json_node
