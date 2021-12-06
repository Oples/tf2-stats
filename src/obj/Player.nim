#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[json, times, deques]
import TeamSwitch
import ../utils/teamCalc

## Player card
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
        teamSwitch*: seq[TeamSwitch]
        kills*: seq[Player]
        team_kills*: seq[Player]
        killed*: seq[Player]
        teamKilled*: seq[Player]


method toJson*(self: Player): JsonNode {.base.} =
    ##[
    - **name** is the ID of the player
    - **team** the team the player joined as
    - **teamSwitch** list of the player's team switch or team balance
    ```json
    {
        "name" : "oples",
        "team" : 1,
        "teamSwitch" : [
            {
                "time" : "",
                "teamBalance" : false
            }
        ]
    }
    ```
    ]##
    var json_node = newJObject()
    json_node.add("name", newJString(self.name))
    json_node.add("team", newJInt(self.team))

    var arr = newJArray()
    for teamSwitch in self.teamSwitch:
        var teamSObj = newJObject()
        teamSObj.add("time", newJString($(teamSwitch.time.utc)))
        teamSObj.add("teamBalance", newJBool(teamSwitch.teamBalance))
        arr.add(teamSObj)
    json_node.add("teamSwitch", arr)
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
    for p in self.teamKilled:
        arr.add(newJString(p.name))
    json_node.add("teamKilled", arr)]#

    return json_node


proc newPlayer*(name: string): Player =
    new(result)
    result.name = name
    result.team = 0
    result.teamSwitch = @[]
    result.kills = @[]
    result.team_kills = @[]
    result.teamKilled = @[]


method newDeath*(self: var Player, player: var Player) {.base.} =
    if (len(self.teamSwitch) mod 2) == (len(player.teamSwitch) mod 2):
        if not self.killed.contains(player):
            self.killed.add(player)
    else:
        # odd teams switch means opposite team
        if not self.teamKilled.contains(player):
            self.teamKilled.add(player)


method newKill*(self: var Player, player: var Player) {.base.} =
    player.newDeath(self)

    if (len(self.teamSwitch) mod 2) == (len(player.teamSwitch) mod 2):
        if not self.kills.contains(player):
            self.kills.add(player)
    else:
        # odd teams switch means opposite team
        if not self.team_kills.contains(player):
            self.team_kills.add(player)


# Team Balance
method switchSide*(self: var Player, teamBalance = false): TeamSwitch {.base.} =
    ## Make the player switch teams
    ## **Note:**
    ## This affects the `kills` and `team_kills` as well as `killed` and `teamKilled`
    let tmb: TeamSwitch = TeamSwitch(
                    player: self.name, time: getTime(), teamBalance: teamBalance)
    self.teamSwitch.add(tmb)
    return tmb


method setKillsTeam*(self: var Player, team: int) {.base.} =
    ## Set the teams of the killed players by the player
    for p in self.kills:
        if p.team == 0 or team < p.team:
            p.team = team
    for p in self.killed:
        if p.team == 0 or team < p.team:
            p.team = team


method setTeamKillsTeam(self: var Player, team: int) {.base.} =
    ## Set the teams of the killed players (ex-teamates) by the player
    for p in self.team_kills:
        if p.team == 0 or team < p.team:
            p.team = team
    for p in self.teamKilled:
        if p.team == 0 or team < p.team:
            p.team = team


method propagateTeams*(self: var Player): bool {.base.} =
    ## Propagate the teams to the players linked to self
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
        for p in self.teamKilled:
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
        for p in self.teamKilled:
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
