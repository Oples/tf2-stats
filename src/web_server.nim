#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[asynchttpserver, asyncdispatch, strutils]
import std/[os, json, logging, times, mimetypes]
import ws
import tail_console
import obj/[Game, Kill, Chat]


##[
  Guide:
    required folder /web (If not found create it and dump the slurp)
      from there on-out user generated content
      - /template is templates (loaded with @{include ""})
]##
var logger {.threadvar.} : ConsoleLogger
var chan : Channel[string]
var
    chanTF2Matches : Channel[JsonNode]
    chanTF2Kills : Channel[JsonNode]
    chanTF2Chat : Channel[JsonNode]
var port = 9844.Port
var FilePath* = ""
const WebDir = "web"

logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")



proc createTestHtml(urlWS: string): string =
    result = """<html>
    <body>
        <pre id="consoleOut" style="font-family:monospace;white-space: pre;"></pre>
        <script>
        let socket = new WebSocket("ws://" + window.location.host + "/{urlWS}");
        var out = document.getElementById("consoleOut");

        socket.onmessage = function (evt) {
            //console.log('RESPONSE: ' + evt.data);
            out.innerHTML = evt.data + out.innerHTML;
            try {
                console.log(JSON.parse(evt.data));
            } catch {
            }
        }
        </script>
        </body>
    </html>""".replace("{urlWS}", urlWS)



proc tf2logger() {.thread.} =
    logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")
    var consoleLogger = newTF2ConsoleLogger()

    consoleLogger.onNewLine = proc(self: TF2ConsoleLogger, line: string) =
        chan.send line

    consoleLogger.afterNewLine = proc(self: TF2ConsoleLogger, line: string) =
        chanTF2Matches.send self.game.toJson

    consoleLogger.onKill = proc(self: TF2ConsoleLogger, k: Kill) =
        chanTF2Kills.send k.toJson

    consoleLogger.onChatMessage = proc(self: TF2ConsoleLogger, c: Chat) =
        chanTF2Chat.send c.toJson

    {.gcsafe.}:
        consoleLogger.runWatchdog(FilePath)


proc testWS() {.thread.} =
    logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")
    var consoleLogger = newTF2ConsoleLogger()

    consoleLogger.onNewLine = proc(self: TF2ConsoleLogger, line: string) =
        chan.send line

    consoleLogger.afterNewLine = proc(self: TF2ConsoleLogger, line: string) =
        chanTF2Matches.send self.game.toJson
        logger.log(lvlInfo, line)

    consoleLogger.runWatchdog("test/console.log")

    #[while true:
        echo "TF waiting"
        sleep(4 * 1000) # seconds
        echo "TF done"
        echo "id: ", i
        i += 1
        dispatcher.add("boop" & $i, newJBool(true))
        chan.send dispatcher
        echo "TF signal!"]#


proc getSelfWebPageContent(filePagePath: string): string =
    if fileExists(filePagePath):
        var pageFile = open(filePagePath)


proc runHTTPServer() {.thread.} =
    ## Start listener server for incoming HTTP requests
    var server = newAsyncHttpServer()
    var matchesLog = newJObject()
    var killsLog : seq[JsonNode]
    var chatLog : seq[JsonNode]
    var lineRawLog : seq[string]

    proc cb(req: Request) {.async.} =
        var mime = newMimetypes()

        let headerTime = now()
        var headers = {"Date": headerTime.format("ddd, dd MMM YYYY HH:mm:ss ") & headerTime.timezone.name,
                       "Content-type": "text/html; charset=utf-8"}

        var dataToSend = "TF2 Logger! If you are seeing this I genuinely don't know how you did that"


        if req.url.path == "/raw":
            dataToSend = createTestHtml("rawWS")
            await req.respond(Http200, dataToSend, headers.newHttpHeaders())


        if req.url.path == "/testMatches":
            dataToSend = createTestHtml("getMatchesWS")
            await req.respond(Http200, dataToSend, headers.newHttpHeaders())


        elif req.url.path == "/rawWS":
            var ws = await newWebSocket(req)
            await ws.send(":: Welcome to Team Fortress 2 Logger")
            await ws.send("")
            var lineRawLogIndex = 0
            while ws.readyState == Open:
                if lineRawLog.len > lineRawLogIndex:
                    dataToSend = ""
                    for i in lineRawLogIndex..<lineRawLog.len:
                        dataToSend = lineRawLog[i] & "\n" & dataToSend
                        lineRawLogIndex += 1
                    await ws.send(dataToSend)
                else: await sleepAsync(20)


        elif req.url.path == "/getMatchesWS":
            var ws = await newWebSocket(req)
            var noMatches = 0
            while ws.readyState == Open:
                if matchesLog["matches"].len > noMatches:
                    await ws.send(matchesLog.pretty)
                    noMatches += 1
                else: await sleepAsync(20)


        elif req.url.path == "/hookMatchWS":
            var ws = await newWebSocket(req)
            var noMatches = 0
            var updates : seq[JsonNode]
            if matchesLog.haskey "matches":
                for m in matchesLog["matches"]:
                    updates.add(m)
            while ws.readyState == Open:
                var currentNumMatch = 0
                if matchesLog.haskey "matches":
                    currentNumMatch = matchesLog["matches"].len
                if currentNumMatch > noMatches:
                    for match in noMatches..<currentNumMatch:
                        updates.add(matchesLog["matches"][match])
                    var msg : string
                    for up in updates:
                        msg.add(up.pretty)
                    await ws.send(msg)
                    noMatches += 1
                    for up in noMatches..<currentNumMatch:
                        updates.del(0)
                else: await sleepAsync(20)

        elif req.url.path == "/hookKillWS":
            var ws = await newWebSocket(req)
            var noMatches = 0
            var updates : seq[JsonNode]
            for m in killsLog:
                updates.add(m)
            while ws.readyState == Open:
                var currentNumMatch = killsLog.len
                if currentNumMatch > noMatches:
                    for i in noMatches..<currentNumMatch:
                        updates.add(killsLog[i])
                    var msg : string
                    for up in updates:
                        msg.add(up.pretty)
                    await ws.send(msg)
                    noMatches += 1
                    for up in noMatches..<currentNumMatch:
                        updates.del(0)
                else: await sleepAsync(20)

        elif req.url.path == "/hookChatWS":
            var ws = await newWebSocket(req)
            var noMatches = 0
            var updates : seq[JsonNode]
            for m in chatLog:
                updates.add(m)
            while ws.readyState == Open:
                var currentNumMatch = chatLog.len
                if currentNumMatch > noMatches:
                    for i in noMatches..<currentNumMatch:
                        updates.add(chatLog[i])
                    var msg : string
                    for up in updates:
                        msg.add(up.pretty)
                    await ws.send(msg)
                    noMatches += 1
                    for up in noMatches..<currentNumMatch:
                        updates.del(0)
                else: await sleepAsync(20)

        elif req.url.path == "/":
            #dataToSend = $req.headers & "\n<br/>" & dataToSend
            #dataToSend = dataToSend & matchesLog.pretty
            #html(body(pre(dataToSend)))
            var headResp = headers.newHttpHeaders()
            headResp["location"] = "/index.html"
            await req.respond(Http307, "", headResp)

        else:
            var filePagePath = WebDir / strip(req.url.path, trailing = false, chars = {'/'})
            try:
                var pageFile = open(filePagePath)
                var (dir, name, extension) = splitFile(filePagePath)
                headers = {"Date": headerTime.format("ddd, dd MMM YYYY HH:mm:ss ") & headerTime.timezone.name,
                       "Content-type": $mime.getMimetype(extension)}
                await req.respond(Http200, pageFile.readAll, headers.newHttpHeaders())
            except:
                await req.respond(Http404, "Not found")

    server.listen port

    proc listenerHTTP {.async.} =
        while true:
            if server.shouldAcceptRequest():
                await server.acceptRequest(cb)
                echo "NEW CLIENT"
            else:
                poll()

    proc updateTF2Console {.async.} =
        proc updateMatches() {.async.} =
            while true:
                let tmp = chanTF2Matches.tryRecv()
                if tmp.dataAvailable:
                    matchesLog = tmp.msg
                else: await sleepAsync(40)

        proc updateKills() {.async.} =
            while true:
                let tmp = chanTF2Kills.tryRecv()
                if tmp.dataAvailable:
                    killsLog.add(tmp.msg)
                else: await sleepAsync(20)

        proc updateChat() {.async.} =
            while true:
                let tmp = chanTF2Chat.tryRecv()
                if tmp.dataAvailable:
                    chatLog.add(tmp.msg)
                else: await sleepAsync(20)

        proc updateRawLog() {.async.} =
            while true:
                let lineLog = chan.tryRecv()
                if lineLog.dataAvailable:
                    lineRawLog.add($lineLog.msg) #.pretty
                else: await sleepAsync(20)


        asyncCheck updateMatches()
        asyncCheck updateKills()
        asyncCheck updateChat()
        asyncCheck updateRawLog()

    var activity : seq[Future[void]]

    while true:
        try:
            activity.add(listenerHTTP())
            activity.add(updateTF2Console())
            runForever()
        except:
            discard
            echo repr(getCurrentException())
            echo "Error??????"


proc startTF2Logger*() =
    var thr : array[0..1, Thread[void]]

    logger.log(lvlDebug, ":: Starting Treads ::")

    chan.open()
    chanTF2Matches.open()
    chanTF2Kills.open()
    chanTF2Chat.open()

    createThread(thr[1], runHTTPServer)

    when isMainModule:
        logger.log(lvlDebug, ":: Server starting wait 10 seconds ::")
        sleep(10*1000) # wait 10 sec
        createThread(thr[0], testWS)
    else:
        createThread(thr[0], tf2logger)


    joinThreads thr
    chan.close()


when isMainModule:
    startTF2Logger()
