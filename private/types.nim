import asynchttpserver, asyncdispatch, strtabs

type
    RequestHandler* = proc (context: Context): Future[void] {.closure.}

    Context* = ref object
        request*: Request
        params*: StringTableRef

    Settings* = distinct JsonNode
