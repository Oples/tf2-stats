#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[json, times, sequtils]
import Player
import Chat
import Kill
import Weapon
import TeamSwitch
import LogData


type
    Match* = ref object
        ##  Match class
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


    Minimum requirements to meet for the frontend Match Update
    ```json
    {
        "ip" : "127.0.0.1",
        "map" : "ctf_hydro",
        "switchSide" : false,
        "players" : {
            "oples" : {
                "team" : 1,
                "teamBalance" : [0, 1 , 2],
                "kills" : [
                    {
                        "weapon" : "quake_rl",
                        "crit" : false,
                        "target" : "laykeenNoob"
                    }
                ],
                "deaths" : [
                    {
                        "weapon" : "quake_rl",
                        "crit" : false,
                        "target" : "laykeenNoob"
                    }
                ],
                "chat" : [
                    {
                        "dead" : false,
                        "spectator" : false,
                        "team" : true,
                        "text" : "gg"
                    }
                ]
            }
        },
        "log" : [
            {
                "type" : "player",
                "data" : {
                    "name" : "oples",
                    "team" : 1,
                    "teamBalance" : [0, 2]
                }
            },
            {
                "type" : "chat",
                "data" : {
                    "dead" : false,
                    "spectator" : false,
                    "team" : true,
                    "player" : "oples",
                    "text" : "gg"
                }
            },
            {
                "type" : "teamBalance",
                "data" : {
                    "player" : "oples",
                }
            },
            {
                "type" : "kill",
                "data" : {
                    "actor" : "laykeen",
                    "crit" : true,
                    "weapon" : "quack_rl",
                    "target" : "oples"
                }
            },
            {
                "type" : "ERROR",
                "data" : "An explenation of the Error"
            }
        ]
    }
    ```
    ]##
    var json_node = newJObject()
    # TODO: ORM to save the time (only in real-time)
    #json_node.add("time", newJString($self.time.utc))
    json_node.add("ip", newJString(self.ip))
    json_node.add("map", newJString(self.map))
    json_node.add("switchSide", newJBool(self.side))

    var pList_obj = newJObject()
    for p in self.players:

        var p_obj = newJObject()
        p_obj.add("team", newJInt(p.team))

        var p_balance = newJArray()
        for balance in p.teamSwitch:
            p_balance.add(balance.toJson)
        p_obj.add("teamSwitch", p_balance)

        var p_kills = newJArray()
        for k in p.kills.concat(p.teamKills):
            p_kills.add(k.toJson)
        p_obj.add("kills", p_kills)

        pList_obj.add(p.name, p_obj)

    json_node.add("players", pList_obj)

    var log = newJArray()
    for l in self.log:
        log.add(l.toJson())
    json_node.add("log", log)

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


#method addTeamBalance*(self: var Match, tmb: TeamSwitch) {.base.} =
#    self.log.add(newLogData(tmb))


method addTeamSwitch*(self: var Match, tms: TeamSwitch) {.base.} =
    self.log.add(newLogData(tms))


method switchSide*(self: var Match) {.base.} =
    for p in self.players:
        var player:Player = p
        # THIS IS NOT A TEAM BALANCE!
        self.addTeamSwitch(player.switchSide(teamBalance = false))

method printChat*(self: Match) {.base.} =
    for msg in self.chat:
        echo pretty(msg.toJson())
