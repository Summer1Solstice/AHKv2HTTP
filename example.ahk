#Requires AutoHotkey v2.0
Persistent
#Include HTTP.ahk
#Include <XZ\GetFileHash>
path := Map()
path["/"] := root
path["/logo"] := logo
path["/hello"] := HelloWorld
; path["/debug"] := debug
path["/hash"] := hash
path["/echo"] := echo

Server := HttpServer(10000)
Server.SetPaths(path)
Server.LoadMimeType("mimetypes")
Server.Web := true	; 是否开启web服务
Server.EnableIPCheck := true	; 是否开启IP限制
IPAudit(ip) {
    static AllowIP := Map("127.0.0.1", true, "0.0.0.0", true)   ; 允许的IP
    if AllowIP.Has(ip) {
        return true
    } else {
        ip := StrSplit(ip, ".")
        if ip[1] = 192 and ip[2] = 168 {
            return true
        }
        if ip[1] = 172 and (ip[2] > 15 and ip[2] < 32) {
            return true
        }
    }
}
Server.CallbackFunc["isIPAllowed"] := IPAudit

root(req, res) {
    ; MsgBox "Hello World!"
    res.Body := "Hello World!(TestVersion)"
}
HelloWorld(req, res) {
    if Server.web {
        res.SetBodyFile(".\index.html")
    } else {
        res.SetBodyText("Hello World!")
    }
}
logo(req, res) {
    res.SetBodyFile("logo.png")
}
debug(req, res) {
    for k, v in req.headers
        res.Body .= k ": " v "`n"
}
echo(req, res) {
    OutputDebug req.Body("utf-8")
}
hash(req, res) {
    try FileDelete "hash"
    FileAppend(req.Body, "hash", "Raw")
    OutputDebug req.Headers["hash"] "`n"
    OutputDebug md5sum("hash") "`n"
    if req.Headers["hash"] = md5sum("hash") {
        OutputDebug "Yes"
    } else {
        OutputDebug "No"
    }
}