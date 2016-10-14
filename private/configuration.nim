import algorithm, json, parsecfg, os, parseopt2
import sequtils, streams, strutils, strtabs, tables
import xmlparser, xmltree

const
    EnvironmentVarHierarchySeparator* = "__"

type
    Configuration* = ref object of RootObj
        settings: seq[Settings]

    Settings* = ref object of RootObj   

    CommandLineOptionsSettings* = ref object of Settings
        options*: TableRef[string, seq[string]]

    ConfigSettings* = ref object of Settings
        config*: Config

    EnvironmentSettings* = ref object of Settings
        variables*: StringTableRef

    JsonSettings* = ref object of Settings
        node*: JsonNode

    XmlSettings* = ref object of Settings
        node*: XmlNode

method `$`*(settings: Settings): string {.base.} =
    result = $settings

method `$`*(settings: CommandLineOptionsSettings): string =
    result = $settings.options

method `$`*(settings: ConfigSettings): string =
    result = $settings.config

method `$`*(settings: EnvironmentSettings): string =
    result = $settings.variables

method `$`*(settings: JsonSettings): string =
    result = $settings.node

method `$`*(settings: XmlSettings): string =
    result = $settings.node

method get*(settings: Settings, keys: varargs[string]): JsonNode {.base.} =
    discard

method get*(settings: CommandLineOptionsSettings, keys: varargs[string]): JsonNode =

    result = newJNull()

    if len(keys) != 1 or not hasKey(settings.options, keys[0]):
        return

    var vals = settings.options[keys[0]]

    if len(vals) == 0:
        return

    result = newJString(vals[^len(vals)])

method get*(settings: ConfigSettings, keys: varargs[string]): JsonNode =

    result = newJNull()

    if len(keys) != 2:
        return

    var 
        val = getSectionValue(settings.config, keys[0], keys[1])

    if val != "":
        result = newJString(val)

method get*(settings: EnvironmentSettings, keys: varargs[string]): JsonNode =

    result = newJNull() 

    let
        key = join(keys, sep = EnvironmentVarHierarchySeparator)

    if hasKey(settings.variables, key):
        let
            val = settings.variables[key]
    
        if not isNil(val):
            result = newJString(val)

method get*(settings: JsonSettings, keys: varargs[string]): JsonNode =

    result = settings.node{ keys }
    
    if isNil(result):
        result = newJNull()

method get*(settings: XmlSettings, keys: varargs[string]): JsonNode =
    result = newJNull()

    let
        highKeys = len(keys) - 1
    var
        attrz: StringTableRef
        currentNode = settings.node

    for index, key in keys:
        if currentNode == nil:
            return

        if index == highKeys:
            if key == tag(currentNode):
                case len(currentNode):
                of 0:
                    result = newJString("")
                of 1:
                    if currentNode[0].kind in [xnCData, xnEntity, xnText]:
                        result = newJString(currentNode[0].text)
                else:
                    break
            return

        if index == (highKeys - 1):
            attrz = attrs(currentNode)
            if not isNil(attrz) and hasKey(attrz, keys[highKeys]):
                result = newJString(attrz[keys[highKeys]])
                return

        currentNode = child(currentNode, keys[index + 1])

proc hasKey*(settings: CommandLineOptionsSettings, key: string): bool =

    result = hasKey(settings.options, key)

proc values*(settings: CommandLineOptionsSettings, key: string): seq[string] =
    
    result = getOrDefault(settings.options, key)

proc value*(settings: CommandLineOptionsSettings, key: string): string =

    let
        vals = values(settings, key)

    if not isNil(vals) and len(vals) > 0:
        result = vals[^len(vals)]

proc fromCommandLineOptions*(optResults: seq[GetoptResult]): CommandLineOptionsSettings =

    let
        options = newTable[string, seq[string]]()

    for kind, key, val in items(optResults):
        case kind
        of cmdLongOption, cmdShortOption:
            if not hasKey(options, key):
                options[key] = newSeq[string]()

            add(options[key], val)
        else: discard

    result = CommandLineOptionsSettings(options: options)

proc fromConfigFile*(filename: string): ConfigSettings =
    new(result)

    result.config = parsecfg.loadConfig(filename)

proc fromConfig*(config: Config): ConfigSettings =
    new(result)

    result.config = config

proc hasKey*(settings: EnvironmentSettings, key: string): bool =

    result = hasKey(settings.variables, key)

proc value*(settings: EnvironmentSettings, key: string): string =

    if hasKey(settings, key):
        result = settings.variables[key]

proc fromEnvironmentVariables*(prefix: string = nil, stripPrefix = true): EnvironmentSettings =
    new(result)
    
    let
        variables = newStringTable(modeCaseInsensitive)
        shouldFilter = not isNilOrWhiteSpace(prefix)
        shouldStrip = shouldFilter and stripPrefix 
        prefixLen = len(prefix)
    var
        key: string

    for name, val in envPairs():
        if shouldFilter and not startsWith(name, prefix):
            continue

        if shouldStrip:
            key = substr(name, prefixLen)
        else:
            key = name

        variables[key] = val

    result.variables = variables

proc getOrDefault*(settings: JsonSettings; key: string): JsonSettings =
    new(result)
  
    result.node = getOrDefault(settings.node, key)

proc hasKey*(settings: JsonSettings, key: string): bool =

    result = hasKey(settings.node, key)

proc `[]=`*(settings: JsonSettings; key: string; val: JsonSettings) =

    settings.node[key] = val.node


proc `{}`*(settings: JsonSettings; keys: varargs[string]): JsonSettings =
    new(result)
  
    result.node = settings.node{keys}

proc `{}=`*(settings: JsonSettings; keys: varargs[string]; value: JsonSettings) =

    settings.node{keys} = value.node

proc fromJsonString*(buffer: string): JsonSettings = 
    new(result)

    result.node = parseJson(buffer)

proc fromJsonStream*(s: Stream; filename: string): JsonSettings = 
    new(result)

    result.node = parseJson(s, filename)

proc fromJsonFile*(filename: string): JsonSettings =
    new(result)

    result.node = parseFile(filename)

proc fromJsonNode*(node: JsonNode): JsonSettings = 
    new(result)

    result.node = node

proc fromXmlStream*(stream: Stream): XmlSettings = 
    new(result)

    result.node = parseXml(stream)

proc fromXmlString*(buffer: string): XmlSettings = 
    
    result = fromXmlStream(newStringStream(buffer))

proc fromXmlFile*(filename: string): XmlSettings =
    new(result)

    result.node = loadXml(filename)

proc fromXmlNode*(node: XmlNode): XmlSettings = 
    new(result)

    result.node = node

proc newConfiguration*(settings: seq[Settings] = @[]): Configuration =
    new(result)

    result.settings = settings

proc `$`*(configuration: Configuration): string =

    result = $configuration.settings

proc add*(configuration: Configuration, config: Configuration) =

    configuration.settings = concat(configuration.settings, config.settings)

proc add*(configuration: Configuration, settings: Settings) =

    add(configuration.settings, settings)

proc addCommandLineOptions*(configuration: Configuration) =
    
    let
        settings = fromCommandLineOptions(toSeq(getopt()))
    
    add(configuration, settings)  

proc addConfig*(configuration: Configuration, config: Config) =

    let settings = fromConfig(config)

    add(configuration, settings)    

proc addConfigFile*(configuration: Configuration, filename: string) =

    let settings = fromConfigFile(filename)

    add(configuration, settings)

proc addEnvironmentVariables*(configuration: Configuration, prefix: string = nil, stripPrefix = true) =

    let settings = fromEnvironmentVariables(prefix, stripPrefix)

    add(configuration, settings)  

proc addJsonFile*(configuration: Configuration, filename: string) =

    let settings = fromJsonFile(filename)

    add(configuration, settings)    

proc addJsonNode*(configuration: Configuration, node: JsonNode) =

    let settings = fromJsonNode(node)

    add(configuration, settings) 

proc addJsonStream*(configuration: Configuration, s: Stream; filename: string) =

    let settings = fromJsonStream(s, filename)

    add(configuration, settings)

proc addJsonString*(configuration: Configuration, buffer: string) =

    let settings = fromJsonString(buffer)

    add(configuration, settings)

proc addXmlFile*(configuration: Configuration, filename: string) =

    let settings = fromXmlFile(filename)

    add(configuration, settings)    

proc addXmlNode*(configuration: Configuration, node: XmlNode) =

    let settings = fromXmlNode(node)

    add(configuration, settings) 

proc addXmlStream*(configuration: Configuration, stream: Stream) =

    let settings = fromXmlStream(stream)

    add(configuration, settings)

proc addXmlString*(configuration: Configuration, buffer: string) =

    let settings = fromXmlString(buffer)

    add(configuration, settings)

proc get*(configuration: Configuration, keys: varargs[string]): JsonNode =
    
    result = newJNull()

    for settings in reversed(configuration.settings):

        result = get(settings, keys)

        if result.kind != JNull:
            break

