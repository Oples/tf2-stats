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
    ##```json
    ##{
    ##  "time": "",
    ##  "actor": {
    ##    "name" : "Op",
    ##    "altSide" : false,
    ##    "weapon" : "boom",
    ##    "crit" : true
    ##  },
    ##  "target": {
    ##    "name" : "Op",
    ##    "altSide" : true
    ##  }
    ##}
    ##```
    var json_node = newJObject()
    #json_node.add("time", newJString($self.time.utc))

    var actor = newJObject()
    actor.add("name", newJString(self.subject.name))
    actor.add("altSide", newJBool(self.subject_side))
    actor.add("weapon", newJString(self.weapon.name))
    actor.add("crit", newJBool(self.crit))

    var target = newJObject()
    target.add("name", newJString(self.target.name))
    target.add("altSide", newJBool(self.target_side))

    json_node.add("actor", actor)
    json_node.add("target", actor)

    return json_node
