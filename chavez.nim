import asyncdispatch, asynchttpserver, httpcore, json
import nre, options, sequtils, strtabs, strutils
import private/router, private/types

export asynchttpserver, asyncdispatch, httpcore, json, strtabs

const
    ContentType = "content-type"
    
var 
    routeTable = newSeq[Route]()
    
proc setHeader*(headers: HttpHeaders; name, val: string; replace = false): HttpHeaders = 

    result = headers

    if isNil(result):
        result = newHttpHeaders()

    if replace or not hasKey(result, name):
        result[name] = val

proc route*(urlPattern: string, httpMethods: set[HttpMethod], handler: RequestHandler) = 

    var 
        route = parseRoute(urlPattern, caseSensitive = false, strict = false)

    route.requestHandler = handler
    route.httpMethods = httpMethods

    routeTable.add(route)
    
proc route*(urlPattern: string, httpMethod: HttpMethod, handler: RequestHandler) = 

    route(urlPattern, { httpMethod }, handler)

template get*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpGet) do (context: Context) -> Future[void]:
        body

template post*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpPost) do (context: Context) -> Future[void]:
        body
        
proc redirect*(context: Context; location: string; code: HttpCode = Http303): Future[void] =

    let 
        hdrs = setHeader(headers, Location, location)
        
    sendHeaders(context.request, headers)        

proc send*(context: Context; content: string; code: HttpCode = Http200, headers: HttpHeaders = nil): Future[void] =

    let 
        hdrs = setHeader(headers, ContentType, "text/plain")
        
    respond(context.request, code, content, hdrs)

proc sendJson*(context: Context; content: string; escape: bool = false; code: HttpCode = Http200; headers: HttpHeaders = nil): Future[void] =

    let 
        hdrs = setHeader(headers, ContentType, "application/json", true)
    var 
        s = content

    if escape:
        s = escapeJson(s)

    send(context, s, code, hdrs)

proc sendJson*(context: Context; node: JsonNode; format = false, code: HttpCode = Http200; headers: HttpHeaders = nil): Future[void] =

    let 
        content = if format: pretty(node) else: $node
        
    sendJson(context = context, content = content, code = code, headers = headers)

proc cb(request: Request) {.async.} =
    
    var routeMatch = findRoute(request, routeTable, caseSensitive = false, strict = false)

    if isNil(routeMatch): 
        await request.respond(Http404, $Http404)
        return

    var 
        context = Context(request: request, params: routeMatch.params)
        
    await routeMatch.requestHandler(context)    

proc startServer*(port: Port = Port(3000), address: string = ""): Future[void] =

    var 
        server = newAsyncHttpServer()
        
    waitFor server.serve(port = port, callback = cb, address = address)
    
