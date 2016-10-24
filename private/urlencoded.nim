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

proc add(urlEncoded: UrlEncoded, key: string, value: UrlEncodedValue) {.borrow.}
proc hasKey*(urlEncoded: UrlEncoded, key: string): bool {.borrow.}
proc `$`*(t: UrlEncoded): string {.borrow.}
proc `[]=`(urlEncoded: UrlEncoded, key: string, value: UrlEncodedValue) {.borrow.}

proc `[]`*(urlEncoded: UrlEncoded, key: string): UrlEncodedValue =

    result = getOrDefault(TableRef[string, UrlEncodedValue](urlEncoded), unicode.toLower(key))

proc `->`*(urlEncoded: UrlEncoded, key: static[string]): UrlEncodedValue =

    result = urlEncoded[key]

proc add(urlEncoded: var UrlEncoded; key, value: string) =

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

proc get[T: string|seq[string]|UrlEncoded](urlEncoded: UrlEncoded, keys: varargs[string]): T =

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

proc get[T, U](urlEncoded: UrlEncoded, keys: varargs[string], convert: proc (t: T): U): U =

    let
        val = get[T](urlEncoded, keys)

    result = convert(val)           

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

template parse(s: string, t: untyped): untyped =

    if isNil(s):
        return

    try:
        result = `parse t`(s)
    except:
        discard            

converter toString*(v: UrlEncodedValue): string =

    if isNil(v):
        return

    if v.kind == vkString:
        result = v.value
    elif v.kind == vkSeq and len(v.seq) > 0:
        result = v.seq[0]
        
converter toSeqString*(v: UrlEncodedValue): seq[string] =

    if isNil(v):
        return

    if v.kind == vkSeq:
        result = v.seq
    elif v.kind == vkString:
        result = @[v.value]


converter toBiggestInt*(v: UrlEncodedValue): BiggestInt = parse(v, BiggestInt)
converter toBiggestUInt*(v: UrlEncodedValue): uint64 = parse(v, BiggestUInt)
converter toBool*(v: UrlEncodedValue): bool = parse(v, Bool)
converter toInt*(v: UrlEncodedValue): int = parse(v, Int)
converter toFloat*(v: UrlEncodedValue): float = parse(v, Float)
converter toUInt*(v: UrlEncodedValue): uint = parse(v, UInt)        

proc getEnumerationOrdinal(prop: Any, value: string): int =

    if isNil(value):
        return

    var
        ordinl: int
                
    if contains(value, re"^\d+$"):
        ordinl = parseInt(value)
        let
            enumFldName = getEnumField(prop, ordinl)
        if enumFldName == value:
            return           
    else:
        ordinl = getEnumOrdinal(prop, value)
        if ordinl == low(int):
            return
                
    result = ordinl

proc castToSeqCString(ss: seq[string]): seq[cstring] =

    result = mapIt(ss, cstring(it))

proc castToSeqChar(ss: seq[string]): seq[char] =

    var
        charz = filterIt(ss, len(strip(it)) == 1)
    result = mapIt(charz, strip(it)[0])

proc castToSeqBool(ss: seq[string]): seq[bool] =

    result = mapIt(ss, (try: parseBool(it) except: false))

proc castToSeqInt(ss: seq[string]): seq[int] =

    result = mapIt(ss, (try: parseInt(it) except: 0))

proc castToSeqInt8(ss: seq[string]): seq[int8] =

    result = mapIt(ss, (try: int8(parseInt(it)) except: 0))

proc castToSeqInt16(ss: seq[string]): seq[int16] =

    result = mapIt(ss, (try: int16(parseInt(it)) except: 0))

proc castToSeqInt32(ss: seq[string]): seq[int32] =

    result = mapIt(ss, (try: int32(parseInt(it)) except: 0))

proc castToSeqInt64(ss: seq[string]): seq[int64] =

    result = mapIt(ss, (try: int64(parseInt(it)) except: 0))

proc castToSeqUInt(ss: seq[string]): seq[uint] =

    result = mapIt(ss, (try: parseUInt(it) except: 0))

proc castToSeqUInt8(ss: seq[string]): seq[uint8] =

    result = mapIt(ss, (try: uint8(parseUInt(it)) except: 0))

proc castToSeqUInt16(ss: seq[string]): seq[uint16] =

    result = mapIt(ss, (try: uint16(parseUInt(it)) except: 0))

proc castToSeqUInt32(ss: seq[string]): seq[uint32] =

    result = mapIt(ss, (try: uint32(parseUInt(it)) except: 0))

proc castToSeqUInt64(ss: seq[string]): seq[uint64] =

    result = mapIt(ss, (try: uint64(parseUInt(it)) except: 0))

proc castToSeqFloat(ss: seq[string]): seq[float] =

    result = mapIt(ss, (try: parseFloat(it) except: 0))

proc castToSeqFloat32(ss: seq[string]): seq[float32] =

    result = mapIt(ss, (try: float32(parseFloat(it)) except: 0))

proc castToSeqFloat64(ss: seq[string]): seq[float64] =

    result = mapIt(ss, (try: float64(parseFloat(it)) except: 0))

converter toSeqCString*(v: UrlEncodedValue): seq[cstring] = castToSeqCString(v)
converter toSeqChar*(v: UrlEncodedValue): seq[char] = castToSeqChar(v)
converter toSeqBool*(v: UrlEncodedValue): seq[bool] = castToSeqBool(v)
converter toSeqInt*(v: UrlEncodedValue): seq[int] = castToSeqInt(v)
converter toSeqInt8*(v: UrlEncodedValue): seq[int8] = castToSeqInt8(v)
converter toSeqInt16*(v: UrlEncodedValue): seq[int16] = castToSeqInt16(v)
converter toSeqInt32*(v: UrlEncodedValue): seq[int32] = castToSeqInt32(v)
converter toSeqInt64*(v: UrlEncodedValue): seq[int64] = castToSeqInt64(v)
converter toSeqFloat*(v: UrlEncodedValue): seq[float] = castToSeqFloat(v)
converter toSeqFloat32*(v: UrlEncodedValue): seq[float32] = castToSeqFloat32(v)
converter toSeqFloat64*(v: UrlEncodedValue): seq[float64] = castToSeqFloat64(v)

proc setValue(prop: Any, value: string) =
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

proc setEnum(prop: Any, value: string) =

    let
        ordinl = getEnumerationOrdinal(prop, value)
                
    setValue(prop, $ordinl)

proc bindSequence(target: Any, name: string, ss: seq[string]) =

    case target[name].baseTypeKind
    of akString:
        var sz = ss
        target[name] = toAny(sz)
    of akCString:
        var
            seqCString = castToSeqCString(ss)
        target[name] = toAny(seqCString)
    of akChar:
        var
            seqChar = castToSeqChar(ss)
        target[name] = toAny(seqChar)
    of akBool:
        var
            seqBool = castToSeqBool(ss)
        target[name] = toAny(seqBool)
    of akInt:
        var
            seqInt = castToSeqInt(ss)
        target[name] = toAny(seqInt)
    of akInt8:
        var
            seqInt8 = castToSeqInt8(ss)
        target[name] = toAny(seqInt8)
    of akInt16:
        var
            seqInt16 = castToSeqInt16(ss)
        target[name] = toAny(seqInt16)
    of akInt32:
        var
            seqInt32 = castToSeqInt32(ss)
        target[name] = toAny(seqInt32)
    of akInt64:
        var
            seqInt64 = castToSeqInt64(ss)
        target[name] = toAny(seqInt64)
    of akUInt:
        var
            seqUInt = castToSeqUInt(ss)
        target[name] = toAny(seqUInt)
    of akUInt8:
        var
            seqUInt8 = castToSeqUInt8(ss)
        target[name] = toAny(seqUInt8)
    of akUInt16:
        var
            seqUInt16 = castToSeqUInt16(ss)
        target[name] = toAny(seqUInt16)
    of akUInt32:
        var
            seqUInt32 = castToSeqUInt32(ss)
        target[name] = toAny(seqUInt32)
    of akUInt64:
        var
            seqUInt64 = castToSeqUInt64(ss)
        target[name] = toAny(seqUInt64)
    of akFloat:
        var
            seqFloat = castToSeqFloat(ss)
        target[name] = toAny(seqFloat)
    of akFloat32:
        var
            seqFloat32 = castToSeqFloat32(ss)
        target[name] = toAny(seqFloat32)
    of akFloat64, akFloat128:
        var
            seqFloat64 = castToSeqFloat64(ss)
        target[name] = toAny(seqFloat64)
    else:
        discard

proc `->`*(v: UrlEncodedValue, key: static[string]): UrlEncodedValue =

    if not isNil(v) and v.kind == vkUrlEncoded:
        result = v.urlEncoded[key]  

proc `->`(value: UrlEncodedValue, target: Any) =
    
    var
        v: UrlEncodedValue

    for name, prop in fields(target):

        if not isNil(value) and value.kind == vkUrlEncoded:
            v = value.urlEncoded[name]          

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
                 bindSequence(target, name, v.seq)
            
            elif len(v.seq) > 0 and prop.kind in [akBool, akChar, akString, akCString, akInt, akInt8, akInt16, akInt32, akInt64, akFloat, akFloat32, akFloat64, akFloat128, akUInt, akUInt8, akUInt16, akUInt32, akUInt64]:
                # target[name] = getAnyValue(v.seq[0], prop.kind)
                discard
        else:
            discard

proc `->`*(value: UrlEncodedValue, target: var object) =

    value -> toAny(target)

proc `->`*(value: UrlEncoded, target: var object) =

    var
        tAny = toAny(target)

    for key, val in TableRef[string, UrlEncodedValue](value):

        for name, prop in fields(tAny):
            if cmpRunesIgnoreCase(key, name) != 0:
                continue
            
            case prop.kind
            of akObject, akTuple:
                val -> prop
            of akSequence:
                case val.kind
                of vkSeq:
                    bindSequence(tAny, name, val.seq)
                of vkString:
                    bindSequence(tAny, name, @[val.value])
                else:
                    discard
            of akBool, akChar, akString, akCString, akInt, akInt8, akInt16, akInt32, akInt64, akFloat, akFloat32, akFloat64, akFloat128, akUInt, akUInt64, akUInt32, akUInt16, akUInt8:
                
                case val.kind:
                of vkString:
                    setValue(prop, val.value)
                of vkSeq:
                    if len(val.seq) > 0:
                        setValue(prop, val.seq[0])
                else:
                    discard

            of akEnum:

                setEnum(prop, val)

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
            perms: seq[int16]
    var
        u: User
        urlEncoded = parseQuery("perms=991&perms=755&details~firSt=zzzuy&AGE=98&details~LaSt=Mbonze&details~AGE=135&gender=2&perms=435")

    urlEncoded -> u
    assert u.gender == Gender.M
    assert u.perms == @[991'i16, 755'i16, 435'i16]
    assert u.details.first == "zzzuy"
    assert u.details.last == "Mbonze"
    assert u.details.age == 135

    let age: int = urlEncoded -> "age"
    assert age == 98
