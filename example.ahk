#Requires AutoHotkey v2.0
Persistent
#Include HTTP.ahk

path := Map()
path["/"] := root
path["/logo"] := logo
path["/debug"] := debug
; path["/latency"] := latency

Server := HttpServer(10000)
Server.SetPaths(path)
Server.SetMimeType("mime.types")
Server.web := true	; 开启web服务
Server.RejectExternalIP := false	; 不拒绝外部IP访问

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
    res.Body := req.Request
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