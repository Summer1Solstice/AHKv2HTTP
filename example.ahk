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
Server.web := false	; 关闭web服务
Server.RejectExternalIP := true	; 拒绝外部IP访问

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