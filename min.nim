import asyncdispatch, asynchttpserver, httpcore, json
import nre, options, sequtils, strtabs, strutils, uri
import private/configuration, private/responses, private/router, private/types

export asynchttpserver, asyncdispatch, httpcore, json, strtabs
export configuration, responses, types

const
    DefaultEnvironment = "development"
    DefaultPort = 3000
    DefaultAddress = ""
    
var 
    defaultSettings: Settings = fromJsonNode(%*{ "environment": DefaultEnvironment, "server": { "port": DefaultPort, "address": DefaultAddress } })
    config: Configuration
    routeTable = newSeq[Route]()

proc route*(urlPattern: string, httpMethods: set[HttpMethod], handler: RequestHandler) = 

    var 
        route = parseRoute(urlPattern, caseSensitive = false, strict = false)

    route.requestHandler = handler
    route.httpMethods = httpMethods

    routeTable.add(route)
    
proc route*(urlPattern: string, httpMethod: HttpMethod, handler: RequestHandler) = 

    route(urlPattern, { httpMethod }, handler)

template connect*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpConnect) do (context: Context) -> Future[void]:
        body
        
template delete*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpDelete) do (context: Context) -> Future[void]:
        body
        
template head*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpHead) do (context: Context) -> Future[void]:
        body             
        
template get*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpGet) do (context: Context) -> Future[void]:
        body
        
template options*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpOptions) do (context: Context) -> Future[void]:
        body        

template patch*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpPatch) do (context: Context) -> Future[void]:
        body
        
template post*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpPost) do (context: Context) -> Future[void]:
        body
            
template put*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpPut) do (context: Context) -> Future[void]:
        body   
        
template trace*(urlPattern: string, context: untyped, body: untyped) = 

    route(urlPattern, HttpTrace) do (context: Context) -> Future[void]:
        body        

proc cb(request: Request) {.async.} =
    
    var 
        routeMatch = findRoute(request, routeTable, caseSensitive = false, strict = false)

    if isNil(routeMatch): 
        await request.respond(Http404, $Http404)
        return

    var 
        cookies = types.parseCookies(request)
        context = Context(config: config, cookies: cookies, request: request, params: routeMatch.params)
        
    await routeMatch.requestHandler(context)    

proc startServer*(configuration: Configuration = nil): Future[void] =

    config = newConfiguration(@[defaultSettings])

    if not isNil(configuration):
        add(config, configuration)

    var 
        port = getNum(get(config, "server", "port"), DefaultPort)
        address = getStr(get(config, "server", "address"), DefaultAddress)
        server = newAsyncHttpServer()
        
    waitFor server.serve(port = Port(port), callback = cb, address = address)
    
