import Player
import json
import times


##
##  Weapon class
##
type
    Weapon* = ref object
        obj_str*: string
        name*: string

method toJson*(self: Weapon): JsonNode {.base.} =
    var json_node = newJObject()
    json_node.add("console_name", newJString(self.obj_str))
    return json_node

proc newWeapon*(obj_str: string): Weapon =
    new(result)
    result.obj_str = obj_str
    result.name = obj_str


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

##
##{
##  "kill": {
##    "time": "",
##    "actor": {
##      "name" : "Op",
##      "altSide" : false,
##      "weapon" : "boom",
##      "crit" : true
##    },
##    "target": {
##      "name" : "Op",
##      "altSide" : true
##    }
##  }
##}
##
method toJson*(self: Kill): JsonNode {.base.} =
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
