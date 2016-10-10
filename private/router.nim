import asyncdispatch, asynchttpserver, nre, options, sequtils, strutils, strtabs
import types

type 
    
    Route* = object of RootObj
        requestHandler*: RequestHandler
        keys*: seq[string]
        methods*: seq[string]
        routePathNoKeys*: string
        urlPattern*: string

    RouteMatch* = ref object
        requestHandler*: RequestHandler
        params*: StringTableRef

const
    pathSeparator = '/'
    defaultPathPattern* = "[^<:/]+"
            
let
    pathPattern = re":([^<:/]+)(?:<([^>]+)>)?"
    optionalPathPattern = re":(?:[^<:/])+\?$"

proc parseRoute*(routePath: string, caseSensitive: bool, strict: bool): Route =

    var routePath = routePath

    if not startsWith(routePath, pathSeparator): 
        routePath = pathSeparator & routePath
        
    if not strict:
        routePath = strip(routePath, leading = false, chars = { '/' })

    var optional = false

    if contains(routePath, optionalPathPattern):
        optional = true
        routePath = strip(routePath, leading = false, chars = { '?' })

    var keys = newSeq[string]()

    var patternString = replace(routePath, pathPattern) do (match: RegexMatch) -> string:

        keys.add match.captures[0]

        result = if isNil(match.captures[1]):
                    "$1($2)$1" % [(if optional: "?" else: ""), defaultPathPattern]
                 else:
                    "($1)" % match.captures[1]

    patternString = '^' & patternString & '$'
    
    var 
        pattern = patternString
        routePathNoKeys: string

    if not caseSensitive:
        pattern = "(?i)" & patternString

        if len(keys) == 0:
            routePathNoKeys = toLowerAscii(routePath)

    result.keys = keys
    result.urlPattern = pattern

    if not isNilOrWhiteSpace(routePathNoKeys):
        result.routePathNoKeys = routePathNoKeys


proc findRoute*(request: Request, routeTable: seq[Route], caseSensitive: bool, strict: bool): RouteMatch =

    let 
        reqMethod = toLowerAscii($request.reqMethod)
    
    var
        match: Option[RegexMatch]
        params = newStringTable(modeCaseInsensitive)
        reqPath = request.url.path
        reqPathLower: string

    if not strict: 
        reqPath = strip(reqPath, leading = false, chars = { '/' })

    reqPathLower = toLowerAscii(reqPath)

    for route in routeTable:

        if reqMethod notin route.methods: continue

        if len(route.keys) > 0:

            match = find(reqPath, re(route.urlPattern))

            if isNone(match): continue

            for index, key in route.keys:
                params[key] = match.get().captures[index]           

        elif route.routePathNoKeys != reqPathLower: continue
  
        result = RouteMatch(requestHandler: route.requestHandler, params: params)

        break
