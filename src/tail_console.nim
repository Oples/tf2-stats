#                                                  #
# Under MIT License                                #
# Author: (c) 2020 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #

import os
import regex
import json
import times
import deques
import logging
import strutils
from get_path import get_tf2_path


var logger = newConsoleLogger(levelThreshold=lvlInfo, fmtStr="[$time] - $levelname: ")


var OWNER = "Oples"
var OWNER_kills = 0
var OWNER_deaths = 0
var file_pos = (int64) 0
var flag_new_game = false


proc oscillate(num: int):int =
    if (num mod 2 == 0):
        return num - 1 # team A
    else:
        return num + 1 # team B

##
## Team Balance class
##
type
    TeamBalance = ref object
        time: Time

##
##   Player class
##
type
    Player = ref object
        name: string
        team: int
            #[
            0: Unknown
            1: A # Unknown A
            2: B # Unknown B
            ]#
        team_switch: seq[TeamBalance]
        kills: seq[Player]
        team_kills: seq[Player]
        killed: seq[Player]
        team_killed: seq[Player]


method toJson(self: Player): JsonNode {.base.} =
    var json_node = newJObject()
    json_node.add("name", newJString(self.name))
    json_node.add("team", newJInt(self.team))

    var arr = newJArray()
    for team_balance in self.team_switch:
        arr.add(newJString($(team_balance.time.utc)))
    json_node.add("team_switch", arr)
    arr = newJArray()
    for p in self.kills:
        arr.add(newJString(p.name))
    json_node.add("kills", arr)
    arr = newJArray()
    for p in self.team_kills:
        arr.add(newJString(p.name))
    json_node.add("team_kills", arr)
    arr = newJArray()
    for p in self.killed:
        arr.add(newJString(p.name))
    json_node.add("killed", arr)
    arr = newJArray()
    for p in self.team_killed:
        arr.add(newJString(p.name))
    json_node.add("team_killed", arr)

    return json_node

proc newPlayer(name: string): Player =
    new(result)
    result.name = name
    result.team = 0
    result.team_switch = @[]
    result.kills = @[]
    result.team_kills = @[]
    result.team_killed = @[]

method newDeath(self: var Player, player: var Player) {.base.} =
    if (len(self.team_switch) mod 2) == (len(player.team_switch) mod 2):
        if not self.killed.contains(player):
            self.killed.add(player)
    else:
        # odd teams switch means opposite team
        if not self.team_killed.contains(player):
            self.team_killed.add(player)

method newKill(self: var Player, player: var Player) {.base.} =
    player.newDeath(self)

    if (len(self.team_switch) mod 2) == (len(player.team_switch) mod 2):
        if not self.kills.contains(player):
            self.kills.add(player)
    else:
        # odd teams switch means opposite team
        if not self.team_kills.contains(player):
            self.team_kills.add(player)

method switchSide(self: var Player) {.base.} =
    var team_balance: TeamBalance = TeamBalance(time: getTime())
    self.team_switch.add(team_balance)

method getTeam(self: Player) {.base.} =
    return

method setKillsTeam(self: var Player, team: int) {.base.} =
    for p in self.kills:
        if p.team == 0 or team < p.team:
            p.team = team
    for p in self.killed:
        if p.team == 0 or team < p.team:
            p.team = team

method setTeamKillsTeam(self: var Player, team: int) {.base.} =
    for p in self.team_kills:
        if p.team == 0 or team < p.team:
            p.team = team
    for p in self.team_killed:
        if p.team == 0 or team < p.team:
            p.team = team


method propagateTeams(self: var Player): bool {.base.} =
    var visited : seq[Player] = @[self]
    var queue : Deque[Player] = initDeque[Player]()
    var cursor = self

    if self.team == 0:
        return false

    queue.addFirst(cursor)

    while queue.len() != 0:
        cursor = queue.popLast

        if(cursor.team != 0):
            setTeamKillsTeam(cursor, cursor.team)
            var k_team = cursor.team
            k_team = oscillate(k_team)

            setKillsTeam(cursor, k_team)

        for p in cursor.kills:
            if not visited.contains(p):
                visited.add(p)
                queue.addFirst(p)
        for p in self.team_kills:
            if not visited.contains(p):
                visited.add(p)
                queue.addFirst(p)
        for p in self.killed:
            if not visited.contains(p):
                visited.add(p)
                queue.addFirst(p)
        for p in self.team_killed:
            if not visited.contains(p):
                visited.add(p)
                queue.addFirst(p)

    return true

method updatePropagate(self: var Player):bool {.base.} =
    var visited : seq[Player] = @[self]
    var queue : Deque[Player] = initDeque[Player]()
    var cursor = self

    queue.addFirst(cursor)

    while queue.len() != 0:
        cursor = queue.popLast

        if(cursor.team != 0):
            setTeamKillsTeam(cursor, cursor.team)
            var k_team = cursor.team
            k_team = oscillate(k_team)
            setKillsTeam(cursor, k_team)

        for p in cursor.kills:
            if not visited.contains(p):
                visited.add(p)
                queue.addFirst(p)
        for p in self.team_kills:
            if not visited.contains(p):
                visited.add(p)
                queue.addFirst(p)
        for p in self.killed:
            if not visited.contains(p):
                visited.add(p)
                queue.addFirst(p)
        for p in self.team_killed:
            if not visited.contains(p):
                visited.add(p)
                queue.addFirst(p)


    var min_t = self.team
    var min_p = self

    for p in visited:
        if p.team != 0:
            if min_t == 0:
                min_t = p.team
            if p.team < min_t:
                min_t = p.team
                min_p = p


    return min_p.propagateTeams()

method copy(self: Player) {.base.} =
    discard

##
##   chat class
##
type
    Chat = ref object
        time: Time
        spectator: bool
        dead: bool # (dead) the player wrote when he was dead
        team: bool # (team) yes or no
        text: string
        player: Player

proc newMsg(spectator: bool, dead: bool, team: bool, text: string, player: Player): Chat =
    new(result)
    result.time = getTime()
    result.spectator = spectator
    result.dead = dead
    result.team = team
    result.text = text
    result.player = player


method toJson(self: Chat): JsonNode {.base.} =
    var json_node = newJObject()
    #json_node.add("time", newJString($self.time.utc))
    json_node.add("dead", newJBool(self.dead))
    json_node.add("team", newJBool(self.team))
    json_node.add("text", newJString(self.text))
    json_node.add("player", newJString(self.player.name))
    return json_node


##
##  Weapon class
##
type
    Weapon = ref object
        str: string
        name: string

method toJson(self: Weapon): JsonNode {.base.} =
    var json_node = newJObject()
    json_node.add("console_name", newJString(self.str))
    return json_node

proc newWeapon(str: string): Weapon =
    var weapon: Weapon = Weapon(str: str, name: str)
    return weapon


##
##   Kill class
##
type
    Kill = ref object
        time: Time
        subject: Player
        subject_side: bool
        target: Player
        target_side: bool
        weapon: Weapon
        crit: bool

method toJson(self: Kill): JsonNode {.base.} =
    var json_node = newJObject()
    json_node.add("time", newJString($self.time.utc))
    json_node.add("subject", newJString(self.subject.name))
    json_node.add("subject_side", newJBool(self.subject_side))
    json_node.add("target", newJString(self.target.name))
    json_node.add("target_side", newJBool(self.target_side))
    json_node.add("weapon", newJString(self.weapon.name))
    json_node.add("crit", newJBool(self.crit))
    return json_node


##
##  Match class
##

##[ Match
default:
    side: false
        side A (odd numbers) = RED
        side B (even numbers) = BLU
    side: true
]##
type
    Match = ref object
        ip: string
        map: string
        time: Time
        players: seq[Player]
        side : bool
        side_id : int
        chat: seq[Chat]
        kills: seq[Kill]


method toJson(self: Match): JsonNode {.base.} =
    var json_node = newJObject()
    json_node.add("ip", newJString(self.ip))
    json_node.add("map", newJString(self.map))
    json_node.add("time", newJString($self.time.utc))
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
    for k in self.kills:
        arr.add(k.toJson())
    json_node.add("kills", arr)
    return json_node

method containsPlayer(self: Match, player_name: string): bool {.base.} =
    for p in self.players:
        if p.name == player_name:
            return true
    return false

method addPlayer(self: var Match, player_name: string): Player {.base.} =
    for p in self.players:
        if p.name == player_name:
            return p

    var new_player:Player = newPlayer(player_name)
    self.players.add(new_player)
    return new_player

method addKill(self: var Match, subject: string, target: string, weapon: Weapon, crit: bool) {.base.} =
    var subj_p = self.addPlayer(subject)
    var subj_p_side = false

    if not len(subj_p.team_switch) mod 2 == 0:
        subj_p_side = true

    var subj_t = self.addPlayer(target)
    var subj_t_side = false

    if not len(subj_t.team_switch) mod 2 == 0:
        subj_t_side = true

    var new_kill = Kill(
        time: getTime(),
        subject: subj_p, subject_side: subj_p_side,
        target: subj_t, target_side: subj_t_side,
        weapon: weapon, crit: crit)

    subj_p.newKill(subj_t)
    self.kills.add(new_kill)

    if not subj_p.updatePropagate():
        #echo "ERROR!!!"
        subj_p.team = self.side_id
        self.side_id += 2
        #echo "side updated! " , self.side_id
        discard subj_p.updatePropagate()
        echo "PLAYER NOT TEAM: ", $subj_p.name, "   TEAM: ", $subj_p.team
    else:
        echo pretty(subj_p.toJson())
        echo "PLAYER: ", $subj_p.name, "   TEAM: ", $subj_p.team

method addMsg(self: var Match, msg: Chat) {.base.} =
    self.chat.add(msg)

method switchSide(self: var Match) {.base.} =
    for p in self.players:
        var player:Player = p
        player.switchSide()


method printChat(self: Match) {.base.} =
    for msg in self.chat:
        echo pretty(msg.toJson())


##
##   Game class
##
type
    Game = ref object
        match: seq[Match]

proc newGame(): Game =
    new(result)
    result.match = @[]

method newMatch(self: var Game, server_ip: string, map_name: string): Match {.base.} =
    var new_match: Match

    new_match = Match(
        ip: server_ip,
        map: map_name,
        time: getTime(),
        players: @[],
        side: false,
        side_id : 3,
        chat: @[],
        kills: @[]
    )
    self.match.add(new_match)
    return new_match

method currentMatch(self: var Game): Match {.base.} =
    var last_i = len(self.match)-1
    if not (last_i < 0):
        return self.match[last_i]
    else:
        return cast[Match](nil)


proc saveJSON(json_par:JsonNode, file_path:string) =
    try:
        writeFile(file_path, pretty(json_par))
    except IOError:
        let
            e = getCurrentException()
            msg = getCurrentExceptionMsg()
        echo("ERROR: ", repr(e), " with ", msg)



# GLOBAL VARIABLES (shame ;-;)
var connecting = 0
var map = ""
var players = 0
var max_players = 0
var build = ""
var server_num = ""
var server_ip = ""
var mm_id = ""
var n_friends = 0
var tf2 = newGame()
var match = cast[Match](nil)


proc update_info(line: string, print: bool) =
    var m: RegexMatch

    if line.match(re"^Connecting to (.*?)(?:\.\.\.){0,1}$", m):
        server_ip = m.groupFirstCapture(0, line)
        echo "CONNECTING TO: ", server_ip
        n_friends = 0

    elif line == "Team Fortress":
        echo "New server connecting..."
        connecting = 1
    elif line.match(re"Map: (.*)", m) and connecting == 1:
        map = m.groupFirstCapture(0, line)
        connecting += 1
    elif line.match(re"Players: ([0-9]+) / ([0-9]+)", m) and connecting == 2:
        players = parseInt(m.groupFirstCapture(0, line))
        max_players = parseInt(m.groupFirstCapture(1, line))
        connecting += 1
    elif line.match(re"Build: ([0-9]+)", m) and connecting == 3:
        build = m.groupFirstCapture(0, line)
        connecting += 1
    elif line.match(re"Server Number: ([0-9]+)", m) and connecting == 4:
        connecting += 1
        server_num = m.groupFirstCapture(0, line)
        flag_new_game = true
        OWNER_kills = 0
        OWNER_deaths = 0
        if match != cast[Match](nil):
            saveJSON(match.toJson(), "match" & $len(tf2.match) & ".json")
        match = tf2.newMatch(server_ip, map)

    elif match == cast[Match](nil):
        return

    elif line.match(re"^(.*) connected$", m):
        var p = match.addPlayer(m.groupFirstCapture(0, line))
        if match.map.startsWith("mvm_"):
            p.team = 1
        if OWNER == "" and flag_new_game:
            OWNER = m.groupFirstCapture(0, line)
            logger.log(lvlInfo, OWNER," IS NOW MY OWNER")
            flag_new_game = false

    elif line.match(re"^(.*) killed (.*) with (.*?)\.( \(crit\))*$", m):
        let
            sName : string = m.groupFirstCapture(0, line)
            tName : string = m.groupFirstCapture(1, line)
            weapon : string = m.groupFirstCapture(2, line)
            crit : bool = m.groupFirstCapture(3, line) != ""

        match.addKill(
                sName,
                tName,
                newWeapon(weapon),
                crit
        )
        if sName == OWNER:
            OWNER_kills += 1

        if tName == OWNER:
            OWNER_deaths += 1
            if print:
                echo OWNER, " deaths total: ", OWNER_deaths


    elif line.match(re"^(.*) suicided.$", m) or line.match(re"^(.*) died.$", m):
        let sName = m.groupFirstCapture(0, line)

        if print:
            echo sName, " needs ze healing."
        if OWNER == sName:
            OWNER_deaths += 1

    elif line.match(re"(.*) selected", m):
        let class = m.groupFirstCapture(0, line)
        # to do implement class statistics
        if print: echo("CLASS: ", class)

    elif line == "":
        discard

    elif line == "Client reached server_spawn." and connecting == 5:
        connecting += 1
        if print: echo "CONNECTED TO SERVER"
    elif line.match(re"^Recognizing MM server id (\[.*\])$", m) and connecting >= 5:
        connecting += 1
        mm_id = m.groupFirstCapture(0, line)
        #echo "OFFICIAL SERVER OF MATCHMAKING ", mm_id


    elif line == "Teams have been switched.":
        saveJSON(match.toJson(), "match" & $len(tf2.match) & ".json")
        match.switchSide()
        if print: echo "HHHHHHHHHHHHHHHH           TEAM SWITCH           HHHHHHHHHHHHHHHH"

    elif line.match(re"^(?:.*[SM].*? ){0,1}(.*) was moved to the other team for game balance$", m):
        let pName = m.groupFirstCapture(0, line)
        var player = match.addPlayer(pName)
        player.switchSide()
        discard

    elif line.match(re"^(?:.*[SM].*? ){0,1}(.*) has been changed to (.*) to balance the teams.$", m):
        let pName = m.groupFirstCapture(0, line)
        let team = m.groupFirstCapture(2, line)
        var player = match.addPlayer(pName)

        player.switchSide()

        if print: stdout.write pName

        if team == "RED":
            player.team = 1
            if print: echo " RED"
        elif team == "BLU":
            player.team = 2
            if print: echo " BLU"

        discard player.propagateTeams()

    elif line.match(re"^(?:.*[SM].*? ){0,1}(.*) was moved to the other team for game balance$", m):
        let pName = m.groupFirstCapture(0, line)
        var player = match.addPlayer(pName)
        player.switchSide()
        if print:
            echo "TEAM BALACE FTW ", pName


    elif line.match(re"^\*DEAD\*\(TEAM\) (.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = match.addPlayer(pName)
        var msg : Chat = newMsg( false, true, true, message, say_player)
        match.addMsg(msg)
        if print:
            echo "r.i.p. teamate message"
            echo("Player: ", pName)
            echo("Text: ", message)
        #[let p_say = newJObject()
        p_say.add( matches[0], newJString(matches[1]))
        chat["chat"].add(p_say)
        saveJSON(chat,"info.json")]#

    elif line.match(re"^\*DEAD\* (.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = match.addPlayer(pName)
        var msg : Chat = newMsg( false, true, false, message, say_player)
        match.addMsg(msg)
        if print:
            echo("r.i.p. message")
            echo("Player: ", pName)
            echo("Text: ", message)

    elif line.match(re"^\(TEAM\) (.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = match.addPlayer(pName)
        var msg : Chat = newMsg( false, true, false, message, say_player)
        match.addMsg(msg)
        if print:
            echo("team message")
            echo("Player: ", pName)
            echo("Text: ", message)

    elif line.match(re"^\*SPEC\* (.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = match.addPlayer(pName)
        var msg : Chat = newMsg( true, false, false, message, say_player)
        match.addMsg(msg)
        if print:
            echo("global message")
            echo("Player: ", pName)
            echo("Text: ", message)

    elif line.match(re"^(.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = match.addPlayer(pName)
        var msg : Chat = newMsg( false, true, false, message, say_player)
        match.addMsg(msg)
        if print:
            echo("global message")
            echo("Player: ", pName)
            echo("Text: ", message)


    elif line.match(re"\[PartyClient\] Joining party [0-9]+", m):
        n_friends += 1
        if print:
            echo "FRIENDS?????? ", n_friends

    elif line == "Sending request to abandon current match":
        if print:
            echo "MATCH END #1"

    elif line == "Disconnecting from abandoned match server":
        if print:
            echo "MATCH END #2"

    elif line == "Sending request to exit matchmaking, marking assigned match as ended":
        saveJSON(match.toJson(), "match" & $len(tf2.match) & ".json")
        if print:
            echo "MATCH END #3"


    elif line.match(re"^(.*) defended (.*) for team #([0-9]+){1}$", m) or
         line.match(re"^(.*) captured (.*) for team #([0-9]+){1}$", m):
        let pNames = m.groupFirstCapture(0, line)
        var team = parseInt(m.groupFirstCapture(2, line))

        var players = pNames.split(", ")

        logger.log(lvlInfo, "/////////////////////////////////////////////////////////////////////////////////")
        for player_name in players:
            var player = match.addPlayer(player_name)

            if print: echo "team len(player.team_switch) ", len(player.team_switch)
            #echo "player: ", pretty(player.toJson())
            logger.log(lvlInfo, "PLAYER: ", player.name, " OF TEAM ",player.team," IS:")
            if not (len(player.team_switch) mod 2 == 0):
                if team == 2:
                    team = 3
                if team == 3:
                    team = 2
            if print: stdout.write "TEAM "

            if team == 2:
                player.team = 1
                if print: echo " RED"
            elif team == 3:
                player.team = 2
                if print: echo " BLU"

            discard player.propagateTeams()


    #[elif line.match(re"^(.*) captured (.*) for team #([0-9]+){1}$"):
        var players = matches[0].split(", ")
        for player_name in players:
            var player = match.addPlayer(player_name)
            var team = parseInt(matches[2])
            if print: echo "PLAYER: ", player.name, " OF TEAM ",player.team," IS:"

            if not ((len(player.team_switch) mod 2) == 0):
                if team == 2:
                    team = 3
                if team == 3:
                    team = 2

            if team == 2:
                player.team = 1
                if print: echo "RED"
            if team == 3:
                player.team = 2
                if print: echo "BLU"

            discard player.propagateTeams()]#

    else:
        return


proc main() =
    var TF2LogFilename = "console.log"

    var file_path = get_tf2_path()  / TF2LogFilename
    var file_size = 0'i64

    when declared(commandLineParams):
        echo commandLineParams()
        file_path = commandLineParams()[0]

    if file_path == "":
        echo "error file path is empty!"
        quit(1)

    var f : File

    if fileExists(file_path):
        f = open(file_path)

        while true:
            var firstLine = ""

            try:
                if f.endOfFile(): # reached EOF
                    f.flushFile()
                    file_pos = getFilePos(f) # save the cursor position

                    if f.getFileSize() < file_size: # the file got smaller
                        file_pos = 0 # (read everything again)

                    f.setFilePos(file_pos)
                    sleep(15) # wait a bit before another read
                else:
                    firstLine = f.readLine()
                    file_size = f.getFileSize()
            except IOError:
                if not fileExists(file_path):
                    break

            if firstLine != "":
                let line = firstLine
                #print_console(line)
                logger.log(lvlDebug, line)
                update_info(line, true)

        # Close the file object when you are done with it
        f.close()

    else:
        logger.log(lvlError, TF2LogFilename, " not found")
        logger.log(lvlError, "Launch Team Fortress 2 with -condebug")


when isMainModule:
    echo "Compile date: " & CompileDate
    echo "Nim version: " & NimVersion
    #echo "Max mem: ", getMaxMem() / 1000
    #echo "Where: ", getAppFilename()
    echo ""
    main()
