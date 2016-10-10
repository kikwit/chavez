import asyncdispatch, asynchttpserver, httpcore
import nre, options, sequtils, strutils
import private/router

export asynchttpserver, asyncdispatch, httpcore

var 
    routeTable = newSeq[Route]()

proc route*(urlPattern: string, methods: seq[string], callback: proc (request: Request): Future[void]) = 

    var route = parseRoute(urlPattern, caseSensitive = false, strict = false)

    route.callback = callback
    route.methods = methods

    routeTable.add(route)

template get*(urlPattern: string, request: untyped, body: untyped) = 

    block:
        var callback = proc (request: Request): Future[void] =
             body

        route(urlPattern, @["get"], callback)

template post*(urlPattern: string, request: untyped, body: untyped) = 

    block:
        var callback = proc (request: Request): Future[void] =
             body

        route(urlPattern, @["post"], callback)

proc cb(request: Request) {.async.} =
    
    var route = findRoute(request, routeTable, caseSensitive = false, strict = false)

    if isNil(route): 
        await request.respond(Http404, $Http404)
        return

    await route.callback(request)
    
proc respond*(request: Request; content: string; code: HttpCode = Http200, headers: HttpHeaders = nil): Future[void] =

    respond(request, code, content, headers)

proc startServer*(port: Port = Port(3000), address: string = ""): Future[void] =

    var server = newAsyncHttpServer()
   
    waitFor server.serve(port = port, callback = cb, address = address)
    
