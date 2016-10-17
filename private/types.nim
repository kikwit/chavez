import asynchttpserver, asyncdispatch, cookies, httpcore, md5, sequtils, strtabs, strutils, times
import configuration

const
    COOKIE = "Cookie" 
    SET_COOKIE = "Set-Cookie"

type
    RequestHandler* = proc (context: Context): Future[void] {.closure.}

    Context* = ref object
        config*: Configuration
        cookies*: Cookies
        params*: StringTableRef
        request*: Request                

        responseCookies: seq[string]

    Cookies* = distinct StringTableRef

proc getCookieSignedKey(key: string): string {.inline.} =
    
    result = key & ".signed"

proc getCookieSignedValue(key, value, secret: string): string {.inline.} =
    
    result = getMD5(value & "." & key & "." & secret)

proc toHttpDate(timeInfo: TimeInfo): string {.inline.} =
    
    result = format(timeInfo, "ddd',' dd MMM yyyy HH:mm:ss 'UTC'")

proc parseCookies*(request: Request): Cookies =

    if hasKey(request.headers, COOKIE):
        let 
            cookiesHeaderVal = request.headers[COOKIE]

        result = Cookies(parseCookies(cookiesHeaderVal))
    else:
        result = Cookies(newStringTable())

# proc `$`*(cookies: Cookies): string {.borrow.}
proc hasKey*(cookies: Cookies, key: string): bool {.borrow.}

proc getCookieInternal(context: Context, key: string, default: string = nil): string =
    
    if hasKey(context.cookies, key):
        result = StringTableRef(context.cookies)[key]
    else:
        result = default        

proc getCookie*(context: Context, key: string, default: string = nil): string =
    
    let
        signedKey = getCookieSignedKey(key)

    if not hasKey(context.cookies, signedKey):
        result = getCookieInternal(context, key, default)

proc getSignedCookie*(context: Context, key: string, default: string = nil): string =
    
    let
        value = getCookieInternal(context, key)
        valueSigned = if not isNil(value): getCookieInternal(context, getCookieSignedKey(key)) else: nil
 
    if isNil(value) or isNil(valueSigned):
        result = default
        return

    let
        secrets = split(get(context.config, "secretKeys").str, ',')

    for secret in secrets:
        if valueSigned == getCookieSignedValue(key, value, secret):
            result = value
            return

    result = default            

proc addResponseCookies*(context: Context, headers: HttpHeaders) =

    for val in context.responseCookies:
        add(headers, SET_COOKIE, val)

proc setCookie*(context: Context, key, value: string; domain = "", path = "", expires = "", secure = false, httpOnly = true) =
    
    if isNil(context.responseCookies):
        context.responseCookies = @[]

    let
        cookieStr = cookies.setCookie(key, value, domain, path, expires, true, secure, httpOnly)

    context.responseCookies.add(cookieStr)
    
proc setCookie*(context: Context, key, value: string; expires: TimeInfo, domain = "", path = "", secure = false, httpOnly = true) =
    
    let
        expiresStr = toHttpDate(expires)

    setCookie(context, key, value, domain, path, expiresStr, secure, httpOnly)

proc setSignedCookie*(context: Context, key, value: string; domain = "", path = "", expires = "", secure = false, httpOnly = true) =
    
    let
        secrets = get(context.config, "secretKeys").str
        secret = split(secrets, ',')[0]
        signedKey = getCookieSignedKey(key)
        signedValue = getCookieSignedValue(key, value, secret)

    setCookie(context, key, value, domain, path, expires, secure, httpOnly)
    setCookie(context, signedKey, signedValue, domain, path, expires, secure, httpOnly)

proc setSignedCookie*(context: Context, key, value: string, expires: TimeInfo, domain = "", path = "", secure = false, httpOnly = true) =
    
    let
        expiresStr = toHttpDate(expires)

    setSignedCookie(context, key, value, domain, path, expiresStr, secure, httpOnly)

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

    setCookie(context, realKey, "", expires, httpOnly = false)

proc clearCookies*(context: Context) =
    
    for key in StringTableRef(context.cookies).keys:
        removeCookie(context, key)    
                    