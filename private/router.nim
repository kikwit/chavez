import asyncdispatch, asynchttpserver, nre, strutils

type 
    Route* = ref object
        callback*: proc (request: Request): Future[void] {.closure.}
        keys*: seq[string]
        methods*: seq[string]
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

    if isNilOrWhiteSpace(routePath): 
        return nil

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
            routePathNoKeys = toLower(routePath)

    new(result)
    
    result.keys = keys
    result.urlPattern = pattern

    if not isNilOrWhiteSpace(routePathNoKeys):
        result.routePathNoKeys = routePathNoKeys
        
        
