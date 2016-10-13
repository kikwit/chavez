import algorithm, json, parsecfg, parseopt2, sequtils, streams, tables

type
    Configuration* = ref object of RootObj
        settings: seq[Settings]

    Settings* = ref object of RootObj   

    CommandLineOptionsSettings* = ref object of Settings
        options*: TableRef[string, seq[string]]

    ConfigSettings* = ref object of Settings
        config*: Config

    JsonSettings* = ref object of Settings
        node*: JsonNode

method `$`*(settings: Settings): string {.base.} =
    result = $settings

method `$`*(settings: CommandLineOptionsSettings): string =

    result = $settings.options

method `$`*(settings: ConfigSettings): string =

    result = $settings.config

method `$`*(settings: JsonSettings): string =

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

    var val = settings.config.getSectionValue(keys[0], keys[1])

    if val != "":
        result = newJString(val)

method get*(settings: JsonSettings, keys: varargs[string]): JsonNode =

    result = settings.node{ keys }
    
    if isNil(result):
        result = newJNull()

proc hasKey*(settings: CommandLineOptionsSettings, key: string): bool =

    result = hasKey(settings.options, key)

proc values*(settings: CommandLineOptionsSettings, key: string): seq[string] =
    
    result = getOrDefault(settings.options, key)

proc value*(settings: CommandLineOptionsSettings, key: string): string =

    let
        vals = values(settings, key)

    if not isNil(vals) and len(vals) > 0:
        result = vals[^len(vals)]

proc fromCommandLineOptions*(optResults: seq[GetoptResult]): Settings =

    let
        options = newTable[string, seq[string]]()

    for kind, key, val in optResults:
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

    result.node = json.parseJson(buffer)

proc fromJsonStream*(s: Stream; filename: string): JsonSettings = 
    new(result)

    result.node = json.parseJson(s, filename)

proc fromJsonFile*(filename: string): JsonSettings =
    new(result)

    result.node = json.parseFile(filename)

proc fromJsonNode*(node: JsonNode): JsonSettings = 
    new(result)

    result.node = node

proc fromConfigFile*(filename: string): ConfigSettings =
    new(result)

    result.config = parsecfg.loadConfig(filename)

proc fromConfig*(config: Config): ConfigSettings =
    new(result)

    result.config = config

proc newConfiguration*(settings: seq[Settings] = @[]): Configuration =
    new(result)

    result.settings = settings

proc `$`*(configuration: Configuration): string =

    result = $configuration.settings

proc add*(configuration: Configuration, config: Configuration) =

    configuration.settings = concat(configuration.settings, config.settings)

proc add*(configuration: Configuration, settings: Settings) =

    add(configuration.settings, settings)

proc addCommandLineOptions*(configuration: Configuration, options: seq[GetoptResult]) =
    
    let
        settings = fromCommandLineOptions(options)
    
    add(configuration, settings)  

proc addConfig*(configuration: Configuration, config: Config) =

    let settings = fromConfig(config)

    add(configuration, settings)    

proc addConfigFile*(configuration: Configuration, filename: string) =

    let settings = fromConfigFile(filename)

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

proc get*(configuration: Configuration, keys: varargs[string]): JsonNode =
    new(result)

    result = newJNull()

    for settings in reversed(configuration.settings):

        result = get(settings, keys)

        if result.kind != JNull:
            break

