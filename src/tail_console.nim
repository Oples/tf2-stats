#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[os, json, logging]
import regex
import std/[strutils, strformat]
import obj/[Player, Chat, Kill, Weapon, Match, Game]


var logger {.threadvar.}: ConsoleLogger
logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")


type
  TF2Class = enum
    Scout, Soldier, Pyro, Medic, Heavy, Demoman, Engineer, Spy, Sniper, Civilian


type
    TF2ConsoleLogger* = ref object of RootObj
        owner*: string
        fileCursor: int64
        players: int
        maxPlayers: int
        build: string
        server_num: string
        serverIp: string
        mm_id: string
        n_friends: int
        game*: Game
        match*: Match
        connecting: int
        map*: string
        matchStart*: bool
        onNewLine*: proc(self: TF2ConsoleLogger, line: string)
        afterNewLine*: proc(self: TF2ConsoleLogger, line: string)
        onKill*: proc(self: TF2ConsoleLogger, k: Kill)
        onChatMessage*: proc(self: TF2ConsoleLogger, c: Chat)
        onClassSelected*: proc(self: TF2ConsoleLogger, c: TF2Class)
        onConnectingServer*: proc(self: TF2ConsoleLogger)
        onTeamBalance*: proc(self: TF2ConsoleLogger)
        onTeamSwitch*: proc(self: TF2ConsoleLogger)
        onDisconnect*: proc(self: TF2ConsoleLogger)
        onPointCapture*: proc(self: TF2ConsoleLogger)
        onPointDefence*: proc(self: TF2ConsoleLogger)


proc newTF2ConsoleLogger*(): TF2ConsoleLogger =
    new(result)
    result.owner = "" # YOUR NAME HERE!!! or blank for auto
    result.fileCursor = (int64) 0
    result.players = 0
    result.maxPlayers = 0
    result.build = ""
    result.server_num = ""
    result.serverIp = ""
    result.mm_id = ""
    result.n_friends = 0
    result.game = newGame()
    result.match = newMatch()
    # Connecting
    result.connecting = 0
    result.map = ""
    result.matchStart = false
    result.onNewLine = proc(self: TF2ConsoleLogger, line: string) =
        #logger.log(lvlDebug, "onNewLine called! ", line)
        discard
    result.afterNewLine = proc(self: TF2ConsoleLogger, line: string) =
        #logger.log(lvlDebug, "afterNewLine called! ", line)
        discard
    result.onKill = proc(self: TF2ConsoleLogger, k: Kill) =
        #logger.log(lvlInfo, "onKill called! ", k.toJson)
        discard
    result.onChatMessage = proc(self: TF2ConsoleLogger, c: Chat) =
        #logger.log(lvlDebug, "onChatMessage called! ", c.toJson)
        discard
    result.onClassSelected = proc(self: TF2ConsoleLogger, c: TF2Class) =
        #logger.log(lvlInfo, "onClassSelected called! ", c)
        discard
    result.onConnectingServer = proc(self: TF2ConsoleLogger) =
        #logger.log(lvlDebug, "onConnectingServer called! ")
        discard
    result.onTeamBalance = proc(self: TF2ConsoleLogger) =
        #logger.log(lvlInfo, "onTeamBalance called! ")
        discard
    result.onTeamSwitch = proc(self: TF2ConsoleLogger) =
        #logger.log(lvlDebug, "onTeamSwitch called! ")
        discard
    result.onDisconnect = proc(self: TF2ConsoleLogger) =
        #logger.log(lvlDebug, "onDisconnect called! ")
        discard
    result.onPointCapture = proc(self: TF2ConsoleLogger) =
        #logger.log(lvlDebug, "onPointCapture called! ")
        discard
    result.onPointDefence = proc(self: TF2ConsoleLogger) =
        #logger.log(lvlDebug, "onPointDefence called! ")
        discard


method `$`*(self: TF2ConsoleLogger): string {.base.} =
    result = &"ip {self.serverIp}, map {self.map}"


method updateInfo(self: TF2ConsoleLogger, line: string) {.base.} =
    var m: RegexMatch

    # don't even bother (usually spam bots send empty lines)
    if line == "":
        discard


    # Connecting to server
    elif line.match(re"^Connecting to (.*?)(?:\.\.\.){0,1}$", m):
        self.serverIp = m.groupFirstCapture(0, line)
        logger.log(lvlInfo, "CONNECTING TO: ", self.serverIp)
        self.n_friends = 0


    elif line == "Team Fortress":
        self.connecting = 1
        logger.log(lvlInfo, "New server connecting...")


    elif self.connecting == 1 and line.match(re"Map: (.*)", m):
        self.connecting += 1
        self.map = m.groupFirstCapture(0, line)


    elif self.connecting == 2 and line.match(re"Players: ([0-9]+) / ([0-9]+)", m):
        self.connecting += 1
        #tf2.players = parseInt(m.groupFirstCapture(0, line))
        self.game.currentMatch().maxPlayers = parseInt(m.groupFirstCapture(1, line))


    elif self.connecting == 3 and line.match(re"Build: ([0-9]+)", m):
        self.connecting += 1
        self.build = m.groupFirstCapture(0, line)


    elif self.connecting == 4 and line.match(re"Server Number: ([0-9]+)", m):
        self.connecting += 1
        self.server_num = m.groupFirstCapture(0, line)
        self.players = 0
        #self.OWNER_kills = 0
        #self.OWNER_deaths = 0

        #if match != cast[Match](nil):
        #    saveJSON(match.toJson(), "match" & $len(tf2.match) & ".json")
        self.match = self.game.newMatch(self.serverIp, self.map)
        self.matchStart = true

        {.gcsafe.}:
            self.onConnectingServer(self)


    elif self.game.match.len < 1:
        # no match was started
        return


    elif line.match(re"^(.*) connected$", m):
        var p = self.match.addPlayer(m.groupFirstCapture(0, line))
        # check if it's a mvm map
        if self.match.map.startsWith("mvm_"):
            # By default the team of the player is RED
            p.team = 1
        if self.owner == "" and self.matchStart:
            # The first connect is the client
            # so the collected username is the one running the game
            self.owner = m.groupFirstCapture(0, line)
            logger.log(lvlNotice, self.owner," IS NOW MY OWNER")
            self.matchStart = false


    # A kill to record
    elif line.match(re"^(.*) killed (.*) with (.*?)\.( \(crit\))*$", m):
        let
            aName : string = m.groupFirstCapture(0, line) # actor
            tName : string = m.groupFirstCapture(1, line) # target
            weapon: string = m.groupFirstCapture(2, line)
            crit  : bool = m.groupFirstCapture(3, line) != ""

        var currentKill = self.match.addKill(
            aName,
            tName,
            newWeapon(weapon),
            crit
        )
        logger.log(lvlDebug, aName , " killed ", tName, " with ", weapon, " ", crit)

        {.gcsafe.}:
            self.onKill(self, currentKill)

        # I added this so I can be even more angry
        #if aName == self.owner:
        #    OWNER_kills += 1

        #if tName == self.owner:
        #    OWNER_deaths += 1
        #    logger.log(lvlInfo, OWNER, " deaths total: ", OWNER_deaths)


    # suicide doesn't solve anything
    elif line.match(re"^(.*) suicided.$", m) or line.match(re"^(.*) died.$", m):
        let sName = m.groupFirstCapture(0, line)
        logger.log(lvlInfo, sName, " called for Valhalla.")
        #if self.owner == sName:
        #    OWNER_deaths += 1


    # a class was selected
    elif line.match(re"(.*) selected", m):
        let class = m.groupFirstCapture(0, line)
        # TODO: implement class statistics
        logger.log(lvlInfo, "Selected class: ", class)

    elif line == "Client reached server_spawn." and self.connecting == 5:
        self.connecting += 1
        logger.log(lvlNotice, ":: CONNECTED TO SERVER")

    elif line.match(re"^Recognizing MM server id (\[.*\])$", m) and self.connecting >= 5:
        self.connecting += 1
        self.mm_id = m.groupFirstCapture(0, line)

    elif line == "Teams have been switched.":
        #saveJSON(match.toJson(), "match" & $len(tf2.match) & ".json")
        self.match.switchSide()
        logger.log(lvlNotice, "HHHHHHHHHHHHHHHH           TEAM SWITCH           HHHHHHHHHHHHHHHH")

    # modded servers have a popular mod that adds the `[SM]` prefix
    elif line.match(re"^(?:.*[SM].*? ){0,1}(.*) was moved to the other team for game balance$", m):
        let pName = m.groupFirstCapture(0, line)
        var player = self.match.addPlayer(pName)

        self.match.addTeamSwitch(player.switchSide(teamBalance = true))
        logger.log(lvlDebug, pName , " team balance")


    # Team Balance
    elif line.match(re"^(?:.*[SM].*? ){0,1}(.*) has been changed to (.*) to balance the teams.$", m):
        let pName = m.groupFirstCapture(0, line)
        let team = m.groupFirstCapture(2, line)
        var player = self.match.addPlayer(pName)

        self.match.addTeamSwitch(player.switchSide(teamBalance = true))

        if team == "RED":
            player.team = 1
            logger.log(lvlInfo, pName, " RED")
        elif team == "BLU":
            player.team = 2
            logger.log(lvlInfo, pName, " BLU")

        discard player.propagateTeams()
        logger.log(lvlDebug, pName , " joined the team ", team)


    # Team Balance
    elif line.match(re"^(?:.*[SM].*? ){0,1}(.*) was moved to the other team for game balance$", m):
        let pName = m.groupFirstCapture(0, line)
        var player = self.match.addPlayer(pName)
        self.match.addTeamSwitch(player.switchSide(teamBalance = true))
        logger.log(lvlDebug, pName, " team balance")


    # CHAT
    elif line.match(re"^\*DEAD\*\(TEAM\) (.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = self.match.addPlayer(pName)
        var msg : Chat = newMsg( false, true, true, message, say_player)
        logger.log(lvlInfo, line)
        self.match.addMsg(msg)
        logger.log(lvlDebug, "r.i.p. (team) message")
        logger.log(lvlDebug, "Player: ", pName)
        logger.log(lvlDebug, "Text: ", message)
        {.gcsafe.}:
            self.onChatMessage(self, msg)


    elif line.match(re"^\*DEAD\* (.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = self.match.addPlayer(pName)
        var msg : Chat = newMsg( false, true, false, message, say_player)
        logger.log(lvlInfo, line)
        self.match.addMsg(msg)
        logger.log(lvlDebug, "r.i.p. message")
        logger.log(lvlDebug, "Player: ", pName)
        logger.log(lvlDebug, "Text: ", message)
        {.gcsafe.}:
            self.onChatMessage(self, msg)


    elif line.match(re"^\(TEAM\) (.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = self.match.addPlayer(pName)
        var msg : Chat = newMsg( false, true, false, message, say_player)
        logger.log(lvlInfo, line)
        self.match.addMsg(msg)
        logger.log(lvlDebug,"team message")
        logger.log(lvlDebug,"Player: ", pName)
        logger.log(lvlDebug,"Text: ", message)
        {.gcsafe.}:
            self.onChatMessage(self, msg)


    elif line.match(re"^\*SPEC\* (.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = self.match.addPlayer(pName)
        var msg : Chat = newMsg( true, false, false, message, say_player)
        logger.log(lvlInfo, line)
        self.match.addMsg(msg)
        {.gcsafe.}:
            self.onChatMessage(self, msg)


    elif line.match(re"^(.*?) :  (.*)$", m):
        let pName = m.groupFirstCapture(0, line)
        let message = m.groupFirstCapture(1, line)
        var say_player: Player = self.match.addPlayer(pName)
        var msg : Chat = newMsg( false, true, false, message, say_player)
        logger.log(lvlInfo, line)
        self.match.addMsg(msg)
        {.gcsafe.}:
            self.onChatMessage(self, msg)


    # Spagetti Code to find how many parties I have to throw
    # 70% of the time it's wrong BE CAREFUL OF THIS INFO
    elif line.match(re"\[PartyClient\] Joining party [0-9]+", m):
        self.n_friends += 1
        logger.log(lvlDebug, "FRIENDS N: ", self.n_friends)


    # 3 types of match end or disconnect
    # why?
    elif line == "Sending request to abandon current match":
        logger.log(lvlInfo, "MATCH END #1")


    elif line == "Disconnecting from abandoned match server":
        logger.log(lvlInfo, "MATCH END #2")


    elif line == "Sending request to exit matchmaking, marking assigned match as ended":
        logger.log(lvlInfo, "MATCH END #3")


    # Capture Point Event
    elif line.match(re"^(.*) defended (.*) for team #([0-9]+){1}$", m) or
         line.match(re"^(.*) captured (.*) for team #([0-9]+){1}$", m):
        let pNames = m.groupFirstCapture(0, line)
        var team = parseInt(m.groupFirstCapture(2, line))

        var players = pNames.split(", ")

        logger.log(lvlInfo, "/////////////////////////////////////////////////////////////////////////////////")
        for player_name in players:
            var player = self.match.addPlayer(player_name)

            logger.log(lvlDebug, "team len(player.teamBalance) ", len(player.teamSwitch))
            #echo "player: ", pretty(player.toJson())
            logger.log(lvlInfo, "PLAYER: ", player.name, " OF TEAM ", player.team," IS:")
            if not (len(player.teamSwitch) mod 2 == 0):
                if team == 2:
                    team = 3
                if team == 3:
                    team = 2

            if team == 2:
                player.team = 1
                logger.log(lvlInfo, "TEAM RED")
            elif team == 3:
                player.team = 2
                logger.log(lvlInfo, "TEAM BLUE")

            logger.log(lvlDebug, "Found a team: propagating...")
            discard player.propagateTeams()

    # Garbage: Ignore this line
    else:
        #logger.log(lvlDebug, "-- IGNORED LINE")
        return


method runWatchdog*(self: TF2ConsoleLogger, filePath: string) {.base.} =
    var file_size = 0'i64
    var f : File

    logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")

    if filePath == "":
        logger.log(lvlFatal, "error file path is empty!")
        raise new(IOError)

    if fileExists(filePath):
        f = open(filePath)

        while true:
            var firstLine = ""

            try:
                if f.endOfFile(): # reached EOF
                    f.flushFile()
                    # save the cursor position
                    self.fileCursor = getFilePos(f)

                    # if the file got smaller (possible conflic/reset)
                    if f.getFileSize() < file_size:
                        logger.log(lvlFatal, fmt":: THE FILE {filePath} WAS MODIFIED/TRIMMED ON RUNTIME! ::")
                        self.fileCursor = 0 # (read everything again)

                    f.setFilePos(self.fileCursor)
                    # wait a bit before another read
                    sleep(15)
                else:
                    # read until EOF
                    firstLine = f.readLine()
                    file_size = f.getFileSize()

            except IOError:
                logger.log(lvlNotice, "IOError while reading the log file")
                if not fileExists(filePath):
                    logger.log(lvlFatal, fmt":: THE FILE {filePath} WAS DELETED ON RUNTIME! ::")
                    break

            if firstLine != "":
                let line = firstLine
                #logger.log(lvlDebug, line)
                {.gcsafe.}:
                    self.onNewLine(self, line)
                self.updateInfo(line)
                {.gcsafe.}:
                    self.afterNewLine(self, line)

        # Close the file object when you are done with it
        f.close()

    else:
        logger.log(lvlFatal, filePath, " not found")
        logger.log(lvlFatal, "Launch Team Fortress 2 with -condebug")


when isMainModule:
    from utils/get_path import get_tf2_path

    echo ":: Compile date: " & CompileDate
    echo ":: Nim version: " & NimVersion
    #echo "Max mem: ", getMaxMem() / 1000
    #echo "Where: ", getAppFilename()
    echo ""

    #var TF2LogFilename = "test/console.log"
    var filePath = ""

    when declared(commandLineParams):
        if commandLineParams().len > 0:
            echo commandLineParams()
            filePath = commandLineParams()[0]
        else:
            filePath = get_tf2_path() #  / TF2LogFilename
    else:
        filePath = get_tf2_path() #  / TF2LogFilename

    newTF2ConsoleLogger().runWatchdog(filePath)
