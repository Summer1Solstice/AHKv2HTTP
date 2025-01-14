#Requires AutoHotkey v2.0
Persistent
#Include HTTP.ahk

path := Map()
path["/logo"] := logo
path["/hi"] := hi
hi(req, res) {
	res.Body := "这是一个用AHK写的HTTP服务器，非常简陋，功能仅支持传递消息文本，不支持文件传输。"
	res.sCode := 200
	res.sMsg := "OK"
}
logo(req, res) {
	Server.SetBodyFile("test.ahk")
}
Server := HttpServer(10000)
Server.Path := path
Server.MimeFile := "mime.types"