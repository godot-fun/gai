class_name SearchResult
extends RefCounted

## One ranked search row: what [WebServer.SearchResponse] returns for the browser path and what
## [BingRssParser] fills for the degraded Bing RSS path, so a fallback list is handed over as-is.
##
## Lives in its own file instead of inside [WebServer] because a signature reference to WebServer
## makes every parser load it, and its async static init races the test runner's shutdown.

var position: int
var title: String
var url: String
var snippet: String
pass
