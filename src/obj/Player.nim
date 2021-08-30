#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[json, times, deques]


proc oscillate*(num: int):int =
    if (num mod 2 == 0):
        return num - 1 # team A
    else:
        return num + 1 # team B


##
## Team Balance
##
type
    TeamBalance* = ref object
        time: Time

method toJson*(self: TeamBalance): JsonNode {.base.} =
    result = newJObject()
    result.add("time", newJString($self.time))

type
    TeamSwitch* = ref object
        time: Time

method toJson*(self: TeamSwitch): JsonNode {.base.} =
    result = newJObject()
    result.add("time", newJString($self.time))

##
##   Player class
##
type
    Player* = ref object
        name*: string
        team*: int
        #[
            0: Unknown
            1: A # Unknown A
            2: B # Unknown B
            else: Unknown
        ]#
        teamBalance*: seq[TeamBalance]
        teamSwitch*: seq[TeamSwitch]
        kills*: seq[Player]
        team_kills*: seq[Player]
        killed*: seq[Player]
        team_killed*: seq[Player]


method toJson*(self: Player): JsonNode {.base.} =
    var json_node = newJObject()
    json_node.add("name", newJString(self.name))
    json_node.add("team", newJInt(self.team))

    var arr = newJArray()
    for teamBalance in self.teamBalance:
        arr.add(newJString($(teamBalance.time.utc)))
    json_node.add("teamBalance", arr)
    #[arr = newJArray()
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
    json_node.add("team_killed", arr)]#

    return json_node


proc newPlayer*(name: string): Player =
    new(result)
    result.name = name
    result.team = 0
    result.teamBalance = @[]
    result.teamSwitch = @[]
    result.kills = @[]
    result.team_kills = @[]
    result.team_killed = @[]


method newDeath*(self: var Player, player: var Player) {.base.} =
    if (len(self.teamBalance) mod 2) == (len(player.teamBalance) mod 2):
        if not self.killed.contains(player):
            self.killed.add(player)
    else:
        # odd teams switch means opposite team
        if not self.team_killed.contains(player):
            self.team_killed.add(player)


method newKill*(self: var Player, player: var Player) {.base.} =
    player.newDeath(self)

    if (len(self.teamBalance) mod 2) == (len(player.teamBalance) mod 2):
        if not self.kills.contains(player):
            self.kills.add(player)
    else:
        # odd teams switch means opposite team
        if not self.team_kills.contains(player):
            self.team_kills.add(player)


# Team Balance
method switchSide*(self: var Player) {.base.} =
    var team_balance: TeamBalance = TeamBalance(time: getTime())
    self.teamBalance.add(team_balance)


method setKillsTeam*(self: var Player, team: int) {.base.} =
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


method propagateTeams*(self: var Player): bool {.base.} =
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


method updatePropagate*(self: var Player):bool {.base.} =
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
