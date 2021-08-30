#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/json

##
##  Weapon class
##
type
    Weapon* = ref object
        obj_str*: string
        name*: string


proc newWeapon*(obj_str: string): Weapon =
    new(result)
    result.obj_str = obj_str
    result.name = obj_str


method toJson*(self: Weapon): JsonNode {.base.} =
    ##```json
    ##{
    ##  "obj": "tf_projectile"
    ##}
    ##```
    var json_node = newJObject()
    json_node.add("obj", newJString(self.obj_str))
    return json_node
