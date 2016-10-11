import asyncdispatch, asynchttpserver, httpcore
import nre, options, sequtils, strtabs, strutils
import private/router, private/types

export asynchttpserver, asyncdispatch, httpcore

var 
    routeTable = newSeq[Route]()

proc route*(urlPattern: string, methods: set[HttpMethod], handler: RequestHandler) = 

    var route = parseRoute(urlPattern, caseSensitive = false, strict = false)

    route.requestHandler = handler
    route.methods = methods

    routeTable.add(route)

template get*(urlPattern: string, context: untyped, body: untyped) = 

    block:
        var handler = proc (context: Context): Future[void] =
             body

        route(urlPattern, { HttpGet }, handler)

template post*(urlPattern: string, context: untyped, body: untyped) = 

    block:
        var handler = proc (context: Context): Future[void] =
             body

        route(urlPattern, { HttpPost }, handler)
    
proc send*(context: Context; content: string; code: HttpCode = Http200, headers: HttpHeaders = nil): Future[void] =

    respond(context.request, code, content, headers)

proc cb(request: Request) {.async.} =
    
    var routeMatch = findRoute(request, routeTable, caseSensitive = false, strict = false)

    if isNil(routeMatch): 
        await request.respond(Http404, $Http404)
        return

    var context = Context(request: request, params: routeMatch.params)

    await routeMatch.requestHandler(context)    

proc startServer*(port: Port = Port(3000), address: string = ""): Future[void] =

    var server = newAsyncHttpServer()
   
    waitFor server.serve(port = port, callback = cb, address = address)
    
