#                                                  #
# Under MIT License                                #
# Author: (c) 2021 Oples                           #
# Original repo can be found at:                   #
#      https://github.com/Oples/tf2-stats          #
#                                                  #
import std/[asynchttpserver, asyncdispatch, strutils]
import std/[os, htmlgen, json, logging, times]
import ws
import tail_console
import obj/Game


##[
  Guide:
    required folder /web (If not found create it and dump the slurp)
      from there on-out user generated content
      - /template is templates (loaded with @{include ""})
]##
var logger {.threadvar.} : ConsoleLogger
var chan : Channel[string]
var chanTF2Matches : Channel[JsonNode]
var port = 9742.Port
var FilePath* = ""

logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")



const docTestHtml = """<html>
<body>
    <pre id="consoleOut" style="font-family:monospace;white-space: pre;"></pre>
    <script>
    let socket = new WebSocket("ws://" + window.location.host + "/ws");
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
</html>"""


const docTestMatchHtml = """<html>
<body>
    <pre id="consoleOut" style="font-family:monospace;white-space: pre;"></pre>
    <script>
    let socket = new WebSocket("ws://" + window.location.host + "/getMatchesWS");
    var out = document.getElementById("consoleOut");

    socket.onmessage = function (evt) {
        //console.log('RESPONSE: ' + evt.data);
        out.innerHTML = evt.data;
        try {
            console.log(JSON.parse(evt.data));
        } catch {
        }
    }
    </script>
    </body>
</html>"""


proc tf2logger() {.thread.} =
    logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")
    var consoleLogger = newTF2ConsoleLogger()

    consoleLogger.onNewLine = proc(self: TF2ConsoleLogger, line: string) =
        chan.send line

    consoleLogger.afterNewLine = proc(self: TF2ConsoleLogger, line: string) =
        chanTF2Matches.send self.tf2.toJson

    {.gcsafe.}:
        consoleLogger.runWatchdog(FilePath)


proc testWS() {.thread.} =
    logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")
    var consoleLogger = newTF2ConsoleLogger()

    consoleLogger.onNewLine = proc(self: TF2ConsoleLogger, line: string) =
        chan.send line

    consoleLogger.afterNewLine = proc(self: TF2ConsoleLogger, line: string) =
        chanTF2Matches.send self.tf2.toJson
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


proc runHTTPServer() {.thread.} =
    ## Start listener server for incoming HTTP requests
    var server = newAsyncHttpServer()
    var matchesLog = newJObject()
    var lineRawLog : seq[string]

    proc cb(req: Request) {.async.} =
        let headerTime = now()
        let headers = {"Date": headerTime.format("ddd, dd MMM YYYY HH:mm:ss ") &  headerTime.timezone.name,
                       "Content-type": "text/html; charset=utf-8"}

        var dataToSend = "Hello World!"

        if req.url.path == "/raw":
            dataToSend = docTestHtml
            await req.respond(Http200, dataToSend, headers.newHttpHeaders())

        elif req.url.path == "/ws":
            var ws = await newWebSocket(req)
            await ws.send("Welcome to Team Fortress 2 Logger")
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

        elif req.url.path == "/":
            dataToSend = $req.headers & "\n<br/>" & dataToSend
            dataToSend = dataToSend & matchesLog.pretty
            #html(body(pre(dataToSend)))
            await req.respond(Http200, docTestMatchHtml, headers.newHttpHeaders())

        else:
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
                else: await sleepAsync(20)

        proc updateRawLog() {.async.} =
            while true:
                let lineLog = chan.tryRecv()
                if lineLog.dataAvailable:
                    lineRawLog.add($lineLog.msg) #.pretty
                else: await sleepAsync(20)
                

        asyncCheck updateMatches()
        asyncCheck updateRawLog()

    var activity : seq[Future[void]]

    activity.add(listenerHTTP())
    activity.add(updateTF2Console())
    runForever()


proc startTF2Logger*() =
    var thr : array[0..1, Thread[void]]

    logger.log(lvlDebug, ":: Starting Treads ::")

    chan.open()
    chanTF2Matches.open()

    when isMainModule:
        createThread(thr[0], testWS)
    else:
        createThread(thr[0], tf2logger)

    createThread(thr[1], runHTTPServer)

    joinThreads thr
    chan.close()


when isMainModule:
    startTF2Logger()
