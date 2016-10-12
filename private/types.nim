import asynchttpserver, asyncdispatch, strtabs
import configuration

type
    RequestHandler* = proc (context: Context): Future[void] {.closure.}

    Context* = ref object
        request*: Request
        params*: StringTableRef
        config*: Configuration