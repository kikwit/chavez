import asyncdispatch, asynchttpserver, nre, options, sequtils, strutils, tables

type 
    Route* = ref object of RootObj
        callback*: proc (request: Request): Future[void] {.closure.}
        keys*: seq[string]
        methods*: seq[string]
        params: Table[string, string]
        routePathNoKeys*: string
        urlPattern*: RegEx
        
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
        pattern: RegEx
        routePathNoKeys: string

    if caseSensitive:
        pattern = re(patternString)
    else:
        pattern = re("(?i)" & patternString)

        if len(keys) == 0:
            routePathNoKeys = toLowerAscii(routePath)

    new(result)
    
    result.keys = keys
    result.urlPattern = pattern

    if not isNilOrWhiteSpace(routePathNoKeys):
        result.routePathNoKeys = routePathNoKeys


proc findRoute*(request: Request, routeTable: seq[Route], caseSensitive: bool, strict: bool): Route =

    let 
        reqMethod = toLowerAscii($request.reqMethod)
    
    var
        match: Option[RegexMatch]
        params = initTable[string, string]()
        reqPath = request.url.path
        reqPathLower: string

    if not strict: 
        reqPath = strip(reqPath, leading = false, chars = { '/' })

    reqPathLower = toLowerAscii(reqPath)

    for route in routeTable:

        if reqMethod notin route.methods: continue

        if len(route.keys) > 0:

            match = find(reqPath, route.urlPattern)

            if isNone(match): continue

            for index, key in route.keys:
                params[key] = match.get().captures[index]           

        elif route.routePathNoKeys != reqPathLower: continue
  
        new(result)

        deepCopy(result, route)

        result.params = params
        
        break
