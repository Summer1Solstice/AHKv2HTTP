#Requires AutoHotkey v2.0
Persistent
#Include HTTP.ahk
#Include <XZ\GetFileHash>
path := Map()
path["/"] := root
path["/logo"] := logo
path["/debug"] := debug
path["/hash"] := hash
path["/echo"] := echo
; path["/latency"] := latency

Server := HttpServer(10000)
Server.SetPaths(path)
Server.SetMimeType("mimetypes")
Server.web := false	; 是否开启web服务
Server.IPRestrict := true	; 拒绝外部IP访问

root(req, res) {
    if Server.web {
        Server.SetBodyFile(".\index.html")
    } else {
        HelloWorld(req, res)
    }
}
HelloWorld(req, res) {
    Server.SetBodyText("Hello World!")
    res.sCode := 200
}
logo(req, res) {
    Server.SetBodyFile("logo.png")
}
debug(req, res) {
    for k, v in req.headers
        res.Body .= k ": " v "`n"
}
echo(req, res) { 
    OutputDebug req.Body
}
; latency(req, res) {
;     n := req.Body
;     if IsInteger(n) and n >= 1 {
;         res.Body := Collatz_Conjecture(n)
;         HTTP.Log("latency: " n, 1)
;         return true
;     }
;     HTTP.Log("latency:`n" n, 1)
; }
hash(req, res) {
    try FileDelete "hash.txt"
    FileAppend(req.Body, "hash.txt", "utf-8 Raw")
    OutputDebug req.Headers["hash"] "`n"
    OutputDebug md5sum("hash.txt") "`n"
    if req.Headers["hash"] = md5sum("hash.txt") {
        OutputDebug "Yes"
    } else {
        OutputDebug "No"
    }
}