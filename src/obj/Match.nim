#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[json, times]
import Player
import Chat
import Kill
import Weapon
import LogData

##
##  Match class
##
type
    Match* = ref object
        ip: string
        map*: string
        time*: DateTime
        playersNum*: int
        maxPlayers*: int
        players*: seq[Player]
        side*: bool
        sideId*: int
        chat*: seq[Chat]
        kills*: seq[Kill]
        log*: seq[LogData]


proc newMatch*(ip = "",
               map = "",
               time = now(),
               playersNum = 0,
               maxPlayers = 0,
               side = false,
               sideId = 0): Match =
    new(result)

    result.ip = ip
    result.map = map
    result.time = time
    result.playersNum = playersNum
    result.maxPlayers = maxPlayers
    result.side = side
    result.sideId = sideId


method toJson*(self: Match): JsonNode {.base.} =
    ##[
    Match
    default:
        side: false
            side A (odd numbers) = RED
            side B (even numbers) = BLU
        side: true

    ```json
    {
        "time": "",
        "ip" : "127.0.0.1",
        "map" : "ctf_hydro",
        "players" : 16,
        "side" : false,
        "chat" : [{
                "spectator" : false,
                "dead" : true,
                "team" : true,
                "player" : "Oples"
                "text" : "gg"
            }],
        "kills" : [{
            "time": "",
            "actor": {
                "name" : "OplesBot 2.0",
                "altSide" : false,
                "weapon" : "sniper_rifle",
                "crit" : true
            },
            "target": {
                "name" : "Oples",
                "altSide" : false
            }
        }],
        "log" : [{
            "event" : "Kill",
            "data" : {
                "time": "",
                "actor": {
                    "name" : "OplesBot 2.0",
                    "altSide" : false,
                    "weapon" : "sniper_rifle",
                    "crit" : true
                },
                "target": {
                    "name" : "Oples",
                    "altSide" : false
                }
            },
        }]
    }
    ```
    ]##
    var json_node = newJObject()
    json_node.add("time", newJString($self.time.utc))
    json_node.add("ip", newJString(self.ip))
    json_node.add("map", newJString(self.map))
    var obj = newJObject()
    for p in self.players:
        var team = newJInt(p.team)
        if not (len(p.team_switch) mod 2) == 0:
            team = newJInt(oscillate(p.team))
        obj.add(p.name, team)
    json_node.add("players", obj)
    json_node.add("side", newJBool(self.side))
    var arr = newJArray()
    for c in self.chat:
        arr.add(c.toJson())
    json_node.add("chat", arr)
    arr = newJArray()
    #for k in self.kills:
    #    arr.add(k.toJson())
    #json_node.add("kills", arr)
    for l in self.log:
        arr.add(l.toJson())
    json_node.add("log", arr)
    return json_node


method containsPlayer*(self: Match, player_name: string): bool {.base.} =
    for p in self.players:
        if p.name == player_name:
            return true
    return false


method addPlayer*(self: var Match, player_name: string): Player {.base.} =
    for p in self.players:
        if p.name == player_name:
            return p

    var new_player : Player = newPlayer(player_name)
    self.players.add(new_player)
    self.log.add(newLogData(new_player))
    return new_player


method addKill*(self: var Match, subject: string, target: string, weapon: Weapon, crit: bool): Kill {.base.} =
    new(result)
    var subj_p = self.addPlayer(subject)
    var subj_p_side = false

    if not len(subj_p.team_switch) mod 2 == 0:
        subj_p_side = true

    var subj_t = self.addPlayer(target)
    var subj_t_side = false

    if not len(subj_t.team_switch) mod 2 == 0:
        subj_t_side = true

    var new_kill : Kill = newKill(
        subj_p, subj_p_side,
        subj_t, subj_t_side,
        time = getTime(),
        weapon = weapon.obj_str,
        crit = crit)

    result = new_kill
    subj_p.newKill(subj_t)
    self.kills.add(new_kill)
    self.log.add(newLogData(new_kill))

    if not subj_p.updatePropagate():
        #echo "ERROR!!!"
        subj_p.team = self.side_id
        self.side_id += 2
        #echo "side updated! " , self.side_id
        discard subj_p.updatePropagate()
        #echo "PLAYER NOT TEAM: ", $subj_p.name, "   TEAM: ", $subj_p.team
    else:
        #echo pretty(subj_p.toJson())
        #echo "PLAYER: ", $subj_p.name, "   TEAM: ", $subj_p.team
        discard


method addMsg*(self: var Match, msg: Chat) {.base.} =
    self.chat.add(msg)
    self.log.add(newLogData(msg))


method switchSide*(self: var Match) {.base.} =
    for p in self.players:
        var player:Player = p
        player.switchSide()


method printChat*(self: Match) {.base.} =
    for msg in self.chat:
        echo pretty(msg.toJson())
