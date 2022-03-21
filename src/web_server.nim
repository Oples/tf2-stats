#                                                  #
# Under MIT License                                #
# Author: (c) 2022 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[asynchttpserver, asyncdispatch, strutils, asyncfutures, asyncstreams]
import std/[os, json, logging, times, mimetypes]
import ws
import tail_console
import obj/[Game, Kill, Chat]
import std/strformat

##[
  Guide:
    required folder /web (If not found create it and dump the slurp)
      from there on-out user generated content
      - /template is templates (loaded with @{include ""})
]##
var logger {.threadvar.} : ConsoleLogger
#var chan : Channel[string]
#var
#    chanTF2Matches : Channel[JsonNode]
#    chanTF2Kills : Channel[JsonNode]
#    chanTF2Chat : Channel[JsonNode]
# https://nim-lang.org/docs/asyncstreams.html#newFutureStream%2Cstring
var chatAsync : JsonNode
var WebPort = 9844
var FilePath* = ""
const WebDir = "web"

logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")


proc createTestJson(urlWS: string): string =
    result = """<html>
    <body>
        <pre id="consoleOut" style="font-family:monospace;white-space: pre;"></pre>
        <script>
        let socket = new WebSocket("ws://" + window.location.host + "/{urlWS}");
        var out = document.getElementById("consoleOut");

        socket.onmessage = function (evt) {
            //console.log('RESPONSE: ' + evt.data);
            try {
                out.innerHTML = JSON.stringify(JSON.parse(evt.data), null, 4) + out.innerHTML;
                console.log(JSON.parse(evt.data));
            } catch {
            }
        }
        </script>
        </body>
    </html>""".replace("{urlWS}", urlWS)

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

proc toLog(data: JsonNode, logType: string): JsonNode =
    result = newJObject()
    result.add("type", newJString(logType))
    result.add("data", data)

proc tf2logger() {.thread.} =
    var asyncLogger = proc () {.async.} =
        logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")
        var consoleLogger = newTF2ConsoleLogger()
        var wsRaw = await newWebSocket(fmt"ws://127.0.0.1:{WebPort}/setRawWS")
        var wsUpdate = await newWebSocket(fmt"ws://127.0.0.1:{WebPort}/newUpdateWS")

        consoleLogger.onNewLine = proc(self: TF2ConsoleLogger, line: string) =
            when isMainModule:
                sleep(300)
            waitFor wsRaw.send($line)

        consoleLogger.afterNewLine = proc(self: TF2ConsoleLogger, line: string) =
            #chanTF2Matches.send self.game.toJson
            discard

        consoleLogger.onKill = proc(self: TF2ConsoleLogger, k: Kill) =
            waitFor wsUpdate.send $toLog(k.toJson, "kill")
            discard

        consoleLogger.onChatMessage = proc(self: TF2ConsoleLogger, c: Chat) =
            waitFor wsUpdate.send $toLog(c.toJson, "chat")

        when isMainModule:
            consoleLogger.runWatchdog("test/console.log")
        else:
            consoleLogger.runWatchdog(FilePath)

    waitFor asyncLogger()

proc testWS() {.thread.} =
    var asyncLoggerTest = proc () {.async.} =
        logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")
        var consoleLogger = newTF2ConsoleLogger()
        var wsRaw = await newWebSocket(fmt"ws://127.0.0.1:{WebPort}/setRawWS")

        consoleLogger.onNewLine = proc(self: TF2ConsoleLogger, line: string) =
            waitFor wsRaw.send($line)

        consoleLogger.afterNewLine = proc(self: TF2ConsoleLogger, line: string) =
            #logger.log(lvlInfo, line)
            discard

        consoleLogger.runWatchdog("test/console.log")

    waitFor asyncLoggerTest()


proc getSelfWebPageContent(filePagePath: string): string =
    if fileExists(filePagePath):
        var pageFile = open(filePagePath)


proc runHTTPServer() {.thread.} =
    ## Start listener server for incoming HTTP requests
    var server = newAsyncHttpServer()
    var lineRawLog : seq[string]
    var logHistory = newJObject()
    var futureRawLine = newFutureStream[string]("setRaw")
    var futureUpdate = newFutureStream[string]("newUpdate")
    var conClients : seq[WebSocket]

    logHistory.add("old", newJArray())

    proc cb(req: Request) {.async, gcsafe.} =
        var mime = newMimetypes()

        let headerTime = now()
        var headers = {"Date": headerTime.format("ddd, dd MMM YYYY HH:mm:ss ") & headerTime.timezone.name,
                       "Content-type": "text/html; charset=utf-8"}

        var dataToSend = "TF2 Logger! If you are seeing this I genuinely don't know how this happened"

        if req.url.path == "/raw":
            dataToSend = createTestHtml("rawWS")
            await req.respond(Http200, dataToSend, headers.newHttpHeaders())

        if req.url.path == "/update":
            dataToSend = createTestJson("updateWS")
            await req.respond(Http200, dataToSend, headers.newHttpHeaders())

        if req.url.path == "/testMatches":
            dataToSend = createTestHtml("getMatchesWS")
            await req.respond(Http200, dataToSend, headers.newHttpHeaders())

        elif req.url.path == "/rawWS":
            var ws = await newWebSocket(req)
            await ws.send(":: Welcome to Team Fortress 2 Logger")
            await ws.send("")
            if ws.readyState == Open:
                dataToSend = ""
                for logLine in lineRawLog:
                    dataToSend = logLine & "\n" & dataToSend
                await ws.send(dataToSend)
            while ws.readyState == Open:
                var (newData, dataToSend) = await futureRawLine.read()
                await ws.send(dataToSend)
                #await sleepAsync(2000)

        elif req.url.path == "/setRawWS":
            var ws = await newWebSocket(req)
            while ws.readyState == Open:
                let dataRecv = await ws.receiveStrPacket()
                #echo ":: dataRecv ",dataRecv
                lineRawLog.add dataRecv
                await futureRawLine.write(dataRecv & "\n")

        elif req.url.path == "/updateWS":
            var ws = await newWebSocket(req)
            conClients.add ws
            if ws.readyState == Open:
                dataToSend = $logHistory
                await ws.send(dataToSend)
            while ws.readyState == Open:
                var (dataFlag, dataToSend) = await futureUpdate.read()
                if dataFlag:
                    var newData = newJObject()
                    newData.add("new", parseJson(dataToSend))
                    for cli in conClients:
                        await cli.send($newData)
                    #await sleepAsync(2000)

        elif req.url.path == "/newUpdateWS":
            var ws = await newWebSocket(req)
            while ws.readyState == Open:
                let dataRecv = await ws.receiveStrPacket()
                echo ":: updateData ",dataRecv
                logHistory["old"].add parseJson(dataRecv)
                await futureUpdate.write(dataRecv)

        elif req.url.path == "/":
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

    server.listen WebPort.Port

    proc listenerHTTP {.async.} =
        while true:
            if server.shouldAcceptRequest():
                await server.acceptRequest(cb)
                echo "NEW CLIENT"
            else:
                poll()

    waitFor listenerHTTP()


proc startTF2Logger*(filePath: string) =
    var thr : array[0..1, Thread[void]]

    logger.log(lvlDebug, ":: Starting Treads ::")
    FilePath = filePath

    createThread(thr[1], runHTTPServer)

    when isMainModule:
        logger.log(lvlDebug, ":: Server starting wait 8 seconds ::")
        sleep(8*1000) # wait 8 sec
        createThread(thr[0], tf2logger)
    else:
        createThread(thr[0], tf2logger)

    when(appType == "gui"):
        import std/browsers
        openDefaultBrowser("http://127.0.0.1:" & $WebPort)

    joinThreads(thr)
    #chan.close()


when isMainModule:
    startTF2Logger("")
