import std/[asynchttpserver, asyncdispatch, strutils]
import std/[os, htmlgen, json, logging]
import ws
import tail_console


##[
  Guide:
    required folder /web (If not found create it and dump the slurp)
      from there on-out user generated content
      - /template is templates (loaded with @{include ""})
]##
var logger {.threadvar.} : ConsoleLogger
var chan : Channel[JsonNode]

logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")



const doc = """<html>
<body>
    <pre id="consoleOut" style="font-family:monospace;white-space: pre;"></pre>
    <script>
    let socket = new WebSocket("ws://oples.ml:9742/ws");
    var out = document.getElementById("consoleOut");

    socket.onmessage = function (evt) {
        //console.log('RESPONSE: ' + evt.data);
        out.innerHTML = evt.data + '<br/>' + out.innerHTML;
        try {
            console.log(JSON.parse(evt.data));
        } catch {
        }
    }
    </script>
    </body>
</html>"""

#waitFor(sleepAsync(2 * 1000)) # 10s
#let packet = await ws.receiveStrPacket()

proc tf2logger() {.thread.} =
    logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")
    var consoleLogger = newTF2ConsoleLogger()
    consoleLogger.runWatchdog("test/console.log")


proc testWS() {.thread.} =
    logger = newConsoleLogger(levelThreshold=lvlDebug, fmtStr="[$time] - $levelname: ")
    var consoleLogger = newTF2ConsoleLogger()
    var i = 0

    consoleLogger.onNewLine = proc(self: TF2ConsoleLogger, line: string) =
        var dispatcher = newJObject()
        logger.log(lvlDebug, "onNewLine called! ", line)
        dispatcher.add("line" & $i, newJString(line))
        chan.send dispatcher
        sleep(2 * 1000) # seconds
        i += 1

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
    let port = 9742.Port

    var server = newAsyncHttpServer()
    proc cb(req: Request) {.async.} =
        let headers = {"Date": "Tue, 29 Apr 2021 23:40:08 GMT",
                       "Content-type": "text/html; charset=utf-8"}

        var dataToSend = "Hello World!"

        if req.url.path == "/test":
            dataToSend = doc
            await req.respond(Http200, dataToSend, headers.newHttpHeaders())

        elif req.url.path == "/ws":
            dataToSend = doc
            var ws = await newWebSocket(req)
            await ws.send("Welcome to Team Fortress 2 Logger")
            while ws.readyState == Open:
                let readAttempt = chan.recv()
                dataToSend = readAttempt.pretty

                await ws.send(dataToSend)

        elif req.url.path == "/":
            let readAttempt = chan.tryRecv()
            if readAttempt.dataAvailable:
                dataToSend = $readAttempt.msg

            dataToSend = $req.headers & dataToSend
            await req.respond(Http200, dataToSend, headers.newHttpHeaders())

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

    asyncCheck listenerHTTP()
    runForever()


proc startTF2Logger*() =
    var thr : array[0..1, Thread[void]]

    logger.log(lvlDebug, ":: Starting Treads ::")

    chan.open()

    when isMainModule:
        createThread(thr[0], testWS)
    else:
        createThread(thr[0], tf2logger)

    createThread(thr[1], runHTTPServer)

    joinThreads thr
    chan.close()

when isMainModule:
    startTF2Logger()
