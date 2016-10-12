import json, parsecfg, sequtils, streams

type
    Configuration* = ref object of RootObj
        settings: seq[Settings]

    Settings* = ref object of RootObj   

    ConfigSettings* = ref object of Settings
        config*: Config

    JsonSettings* = ref object of Settings
        node*: JsonNode

method `$`*(settings: Settings): string {.base.} =

    result = $settings

method `$`*(settings: ConfigSettings): string =

    result = $settings.config

method `$`*(settings: JsonSettings): string =

    result = $settings.node

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

proc add*(configuration: Configuration, settings: Settings) =

    add(configuration.settings, settings)

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