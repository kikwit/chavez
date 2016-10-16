import asynchttpserver, asyncdispatch, cookies, httpcore, sequtils, strtabs, strutils, times
import configuration

const
    COOKIE = "Cookie" 
    SET_COOKIE = "Set-Cookie"

type
    RequestHandler* = proc (context: Context): Future[void] {.closure.}

    Context* = ref object
        request*: Request
        params*: StringTableRef
        config*: Configuration
        cookies*: Cookies

        responseCookies: seq[string]

    Cookies* = distinct StringTableRef

proc parseCookies*(request: Request): Cookies =

    if hasKey(request.headers, COOKIE):
        let 
            cookiesHeaderVal = request.headers[COOKIE]

        result = Cookies(parseCookies(cookiesHeaderVal))
    else:
        result = Cookies(newStringTable())

# proc `$`*(cookies: Cookies): string {.borrow.}
proc hasKey*(cookies: Cookies, key: string): bool {.borrow.}

proc get*(cookies: Cookies, key: string, default: string = nil): string =
    
    if hasKey(cookies, key):
        result = StringTableRef(cookies)[key]
    else:
        result = default

proc addResponseCookies*(context: Context, headers: HttpHeaders) =

    for val in context.responseCookies:
        add(headers, SET_COOKIE, val)

proc setCookie*(context: Context, key, value: string; domain = "", path = "", expires = "", secure = false, httpOnly = false) =
    
    if isNil(context.responseCookies):
        context.responseCookies = @[]

    let
        cookieStr = cookies.setCookie(key, value, domain, path, expires, true, secure, httpOnly)

    context.responseCookies.add(cookieStr)
    
proc setCookie*(context: Context, key, value: string, expires: TimeInfo, domain = "", path = "", noName = false, secure = false, httpOnly = false) =
    
    let
        expiresStr = format(expires, "ddd',' dd MMM yyyy HH:mm:ss 'UTC'")

    setCookie(context, key, value, domain, path, expiresStr, secure, httpOnly)

proc removeCookie*(context: Context, key: string) =
    
    let
        expires = getGmTime(getTime()) - 2.days
    var
        realKey: string 

    for k in StringTableRef(context.cookies).keys:
        if cmpIgnoreCase(key, k) == 0:
            realKey = k
            break 

    if isNil(realKey):
        return

    setCookie(context, realKey, "", expires)

proc clearCookies*(context: Context) =
    
    for key in StringTableRef(context.cookies).keys:
        removeCookie(context, key)    
                    