import json, nativesockets, parsecfg, sequtils, streams

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

proc newConfiguration*(settings: seq[Settings]): Configuration =
    new(result)

    result.settings = settings

proc add*(configuration: Configuration, settings: Settings) =

    configuration.add(settings)

proc `$`*(configuration: Configuration): string =

    result = $configuration.settings

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

proc fromJson*(buffer: string): JsonSettings = 
    new(result)

    result.node = json.parseJson(buffer)

proc fromJson*(s: Stream; filename: string): JsonSettings = 
    new(result)

    result.node = json.parseJson(s, filename)

proc fromJsonFile*(filename: string): JsonSettings =
    new(result)

    result.node = json.parseFile(filename)

proc fromJson*(node: JsonNode): JsonSettings = 
    new(result)

    result.node = node

proc fromConfigFile*(filename: string): ConfigSettings =
    new(result)

    result.config = parsecfg.loadConfig(filename)

proc fromConfig*(config: Config): ConfigSettings =
    new(result)

    result.config = config
