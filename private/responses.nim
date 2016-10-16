import asyncdispatch, asynchttpserver, json, uri
import types

const
    HdrContentType = "content-type"
    HdrLocation = "location"

proc setHeader*(headers: HttpHeaders; name, val: string; replace = false): HttpHeaders = 

    result = headers

    if isNil(result):
        result = newHttpHeaders()

    if replace or not hasKey(result, name):
        result[name] = val

proc redirect*(context: Context; location: string; code: HttpCode = Http303): Future[void] =

    let 
        hdrs = setHeader(nil, HdrLocation, location)
        
    sendHeaders(context.request, hdrs)    
    
proc redirect*(context: Context; url: Uri; code: HttpCode = Http303): Future[void] =

    redirect(context, $url, code)    

proc send*(context: Context; content: string; code: HttpCode = Http200, headers: HttpHeaders = nil): Future[void] =

    let 
        hdrs = setHeader(headers, HdrContentType, "text/plain")
        c = if isNil(content): "" else: content

    addResponseCookies(context, hdrs)
        
    respond(context.request, code, c, hdrs)

proc sendJson*(context: Context; content: string; escape: bool = false; code: HttpCode = Http200; headers: HttpHeaders = nil): Future[void] =

    let 
        hdrs = setHeader(headers, HdrContentType, "application/json", true)
    var 
        s = content

    if escape:
        s = escapeJson(s)

    send(context, s, code, hdrs)

proc sendJson*(context: Context; node: JsonNode; format = false, code: HttpCode = Http200; headers: HttpHeaders = nil): Future[void] =

    let 
        content = if format: pretty(node) else: $node
        
    sendJson(context = context, content = content, code = code, headers = headers)
