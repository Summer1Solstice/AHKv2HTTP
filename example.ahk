#Requires AutoHotkey v2.0
Persistent
#Include HTTP.ahk

path := Map()
path["/"] := root
path["/logo"] := logo
path["/debug"] := debug

Server := HttpServer(10000)
Server.Path := path
Server.MimeFile := "mime.types"

root(req, res) {
	res.Body := "Hello World!"
	res.sCode := 200
	res.sMsg := "OK"
}
logo(req, res) {
	Server.SetBodyFile("logo.png")
}
debug(req, res) {
	body := ""
	for k, v in req.GetQueryArgs {
		body .= k "=" v
	}
	res.Body := body
}