import tables, parseUtils, strutils

type
    ValueKind = enum
        vkString, vkSeq, vkUrlEncoded
    UrlEncoded* = distinct TableRef[string, UrlEncodedValue]
    UrlEncodedValue = ref object
        case kind: ValueKind
        of vkString:
            value: string
        of vkSeq:
            seq: seq[string]
        of vkUrlEncoded:
            urlEncoded: UrlEncoded

proc newUrlEncoded(): UrlEncoded =
    
    let 
        tableRef = newTable[string, UrlEncodedValue]()

    result = UrlEncoded(tableRef)

proc `$`*(value: UrlEncodedValue): string =

    result = $value.kind

proc add*(urlEncoded: UrlEncoded, key: string, value: UrlEncodedValue) {.borrow.}
proc hasKey*(urlEncoded: UrlEncoded, key: string): bool {.borrow.}
proc `$`*(t: UrlEncoded): string {.borrow.}
proc `[]=`*(urlEncoded: UrlEncoded, key: string, value: UrlEncodedValue) {.borrow.}

proc `[]`*(urlEncoded: UrlEncoded, key: string): UrlEncodedValue =

    result = getOrDefault(TableRef[string, UrlEncodedValue](urlEncoded), key)

proc `~`*(urlEncoded: UrlEncoded, key: string): UrlEncodedValue =

    result = urlEncoded[key]

proc add*(urlEncoded: var UrlEncoded; key, value: string) =

    if not hasKey(urlEncoded, key):
        add(urlEncoded, key, UrlEncodedValue(kind: vkString, value: value))
    else:
        var
            existingValue = urlEncoded[key]

        if existingValue.kind == vkString:
            urlEncoded[key] = UrlEncodedValue(kind: vkSeq, seq: @[existingValue.value, value])
        elif existingValue.kind == vkSeq:
            add(existingValue.seq, value)
        if existingValue.kind == vkUrlEncoded:
            discard
        else:
            discard

proc get*[T: string|seq[string]|UrlEncoded](urlEncoded: UrlEncoded, keys: varargs[string]): T =

    var 
        current = urlEncoded
        val: UrlEncodedValue
  
    for index, key in keys:

        val = current[key]
          
        if index == high(keys):
            if isNil(val):
                break

            when T is string:
                if val.kind == vkString:
                    result = val.value
                elif val.kind == vkSeq and len(val.seq) > 0:
                    result = val.seq[0]
            elif T is seq[string]:
                if val.kind == vkSeq:
                    result = val.seq
                elif val.kind == vkString:
                    result = @[val.value]
            elif T is UrlEncoded:
                if val.kind == vkUrlEncoded:
                    result = val.urlEncoded

            break
            
        elif val.kind == vkUrlEncoded:
            current = val.urlEncoded
            continue
            
        else:
            break

proc getOrDefault*[T: string|seq[string]|UrlEncoded](urlEncoded: UrlEncoded, keys: varargs[string], default: T): T =

    result = get(urlEncoded, keys)

    if isNil(result):
        result = default

proc get*[T, U](urlEncoded: UrlEncoded, keys: varargs[string], convert: proc (t: T): U): U =

    let
        val = get[T](urlEncoded, keys)

    result = convert(val)

proc getOrDefault*[T, U](urlEncoded: UrlEncoded, keys: varargs[string], convert: proc (t: T): U, default: U): U =

    let
        val = get[T](urlEncoded, keys)

    if isNil(val):
        result = default
    else:
        result = try: convert(val)
                 except: default

proc `~`*(v: UrlEncodedValue, key: string): UrlEncodedValue =

    if not isNil(v) and v.kind == vkUrlEncoded:
        result = v.urlEncoded[key]                 

proc addUrlEcodedValue(urlEncoded: var UrlEncoded; key, value: string) =

    var
        current = urlEncoded
        index = 0
        k: string

    while index < len(key):

        k = ""

        inc(index, parseUntil(key, k, '~', index))
        inc(index) # skip '~'

        if isNilOrWhiteSpace(k):
            break

        if index >= len(key):
            add(current, k, value)
        else:
            if not hasKey(current, k) or current[k].kind != vkUrlEncoded:
                current[k] = UrlEncodedValue(kind: vkUrlEncoded, urlEncoded: newUrlEncoded())

            current = current[k].urlEncoded


proc parseQuery*(s: string): UrlEncoded =
    
    result = newUrlEncoded()

    var
        index = 0
        key, value: string

    while index < len(s):

        key = ""
        value = ""

        inc(index, parseUntil(s, key, '=', index))      
        inc(index) # skip '='

        inc(index, parseUntil(s, value, '&', index))
        inc(index) # skip '&'

        if not isNilOrEmpty(key):
            addUrlEcodedValue(result, key, value)

converter toString*(v: UrlEncodedValue): string =

    if isNil(v):
        return

    if v.kind == vkString:
        result = v.value
    elif v.kind == vkSeq and len(v.seq) > 0:
        result = v.seq[0]
        
converter toString*(v: UrlEncodedValue): seq[string] =

    if isNil(v):
        return

    if v.kind == vkSeq:
        result = v.seq
    elif v.kind == vkString:
        result = @[v.value]

template parse(s: string, t: untyped): untyped =

    if isNil(s):
        return

    try:
        result = `parse t`(s)
    except:
        discard

converter toFloat*(v: UrlEncodedValue): float = parse(v, Float)
converter toBiggestInt*(v: UrlEncodedValue): BiggestInt = parse(v, BiggestInt)
converter toBiggestUInt*(v: UrlEncodedValue): uint64 = parse(v, BiggestUInt)
converter toInt*(v: UrlEncodedValue): int = parse(v, Int)
converter toUInt*(v: UrlEncodedValue): uint = parse(v, UInt)
converter toBool*(v: UrlEncodedValue): bool = parse(v, Bool)

#[
when isMainModule:

    let
        urlEncoded = parseQuery("name~first=943&age=98&name~last=Mbonze&gender=M&age=135")
        v: string = urlEncoded ~ "name" ~ "last"
            
    echo "Value: ", v
]#

