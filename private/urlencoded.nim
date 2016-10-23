import nre, parseUtils, sequtils, strutils, tables, typeinfo, unicode

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

    result = getOrDefault(TableRef[string, UrlEncodedValue](urlEncoded), unicode.toLower(key))

proc `->`*(urlEncoded: UrlEncoded, key: string): UrlEncodedValue =

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
            addUrlEcodedValue(result, unicode.toLower(key), value)

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

converter toBiggestInt*(v: UrlEncodedValue): BiggestInt = parse(v, BiggestInt)
converter toBiggestUInt*(v: UrlEncodedValue): uint64 = parse(v, BiggestUInt)
converter toBool*(v: UrlEncodedValue): bool = parse(v, Bool)
converter toInt*(v: UrlEncodedValue): int = parse(v, Int)
converter toFloat*(v: UrlEncodedValue): float = parse(v, Float)
converter toUInt*(v: UrlEncodedValue): uint = parse(v, UInt)

proc setValue*(prop: Any, value: string) =
    case prop.kind
    of akChar:
    #[
        if len(value) > 0:
            let
                c = value[0]
    ]#
        discard
    of akString:
        setString(prop, value)
    of akInt, akInt64, akInt32, akInt16, akInt8, akBool, akEnum:
        setBiggestInt(prop, parseBiggestInt(value))
    of akUInt, akUInt64, akUInt32, akUInt16, akUInt8: 
        setBiggestUint(prop, parseBiggestUInt(value))    
    of akFloat, akFloat32, akFloat64, akFloat128:
        var
            bf: BiggestFloat
        discard parseBiggestFloat(value, bf)
        setBiggestFloat(prop, bf)
    else:
        discard


proc `->`*(v: UrlEncodedValue, key: string): UrlEncodedValue =

    if not isNil(v) and v.kind == vkUrlEncoded:
        result = v.urlEncoded[key]  

proc `->`(value: UrlEncodedValue, target: Any) =
    
    var
        v: UrlEncodedValue

    for name, prop in fields(target):

        v = value -> name

        if isNil(v):
            continue
     
        case v.kind
        of vkUrlEncoded:
            if prop.kind == akTuple or prop.kind == akObject:
                v -> prop      
            continue
        of vkString:
            if prop.kind == akSequence:
                var
                    sq = @[v.value]

                target[name] = toAny(sq)

            else:
                setValue(prop, v.value)
        of vkSeq:
            if prop.kind == akSequence:
                target[name] = toAny(v.seq)
            
            elif len(v.seq) > 0 and prop.kind in [akBool, akChar, akString, akCString, akInt, akInt8, akInt16, akInt32, akInt64, akFloat, akFloat32, akFloat64, akFloat128, akUInt, akUInt8, akUInt16, akUInt32, akUInt64]:
                # target[name] = getAnyValue(v.seq[0], prop.kind)
                discard
        else:
            discard

proc `->`*(value: UrlEncodedValue, target: var object) =

    value -> toAny(target)

proc `->`*(value: UrlEncoded, target: var object) =

    for key, val in TableRef[string, UrlEncodedValue](value):
        for name, prop in fields(toAny(target)):
            if cmpRunesIgnoreCase(key, name) != 0:
                continue
            
            case prop.kind
            of akObject, akTuple:
                val -> prop
            of akChar, akString, akInt, akInt64, akInt32, akInt16, akInt8, akBool, 
               akUInt, akUInt64, akUInt32, akUInt16, akUInt8, 
               akFloat, akFloat32, akFloat64, akFloat128:
                
                case val.kind:
                of vkString:
                    setValue(prop, val.value)
                of vkSeq:
                    if len(val.seq) > 0:
                        setValue(prop, val.seq[0])
                else:
                    discard
            of akEnum:

                var
                    queryVal: string
                    ordinl: int

                case val.kind:
                of vkString:
                    queryVal = val.value
                of vkSeq:
                    if len(val.seq) > 0:
                        queryVal = val.seq[0]
                else:
                    continue
                
                if contains(queryVal, re"^\d+$"):
                    ordinl = parseInt(queryVal)
                    let
                        enumFldName = getEnumField(prop, ordinl)
                    if enumFldName  == queryVal:
                        continue              
                else:
                    ordinl = getEnumOrdinal(prop, queryVal)
                    if ordinl == low(int):
                        continue
                

                setValue(prop, $ordinl)

            else:
                discard


when isMainModule:

    type
        Gender = enum
            F, T, M
        UserDetails = object
            first: string
            last: string
            age: int
        User = object
            age: int
            gender: Gender
            details: UserDetails
    var
        u: User
        urlEncoded = parseQuery("details~firSt=zzzuy&AGE=98&details~LaSt=Mbonze&details~AGE=135&gender=1")

    urlEncoded -> u
    assert u.gender == Gender.T
    assert u.details.first == "zzzuy"
    assert u.details.last == "Mbonze"
    assert u.details.age == 135

    let age: int = urlEncoded -> "age"
    assert age == 98

