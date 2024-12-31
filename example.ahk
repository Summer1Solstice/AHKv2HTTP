#Requires AutoHotkey v2.0

Persistent
#Include Socket.ahk ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk
#Include HTTP.ahk
; #Include <print>
class TestServer extends Socket.Server {
	onACCEPT(err) {
		this.client := this.AcceptAsClient()
		this.client.onREAD := onread
		onread(this, err) {
			req.fnParse(this.RecvText())
			; OutputDebug("receive from client`n" this.RecvText())
			switch req.Line.url {
				case "/": res.Body := "这是一个用AHK写的HTTP服务器，非常简陋，功能仅支持传递消息文本，不支持文件传输。"
				case "/hi": res.Body := "Hello World!"
				case "/date":
					date := FormatTime(, "ddd, d MMM yyyy HH:mm:ss")
					res.Headers["Date"] := date
					res.Body := date
				case "/echo":
					(res.Body) ? (res.Body "" req.Body) : (req.Body)
					for k, v in req.GETQueryArgs {
						res.Body .= k "=" v "`n"
					}
				default: res.Body := "404 Not Found", res.sc := 404, res.msg := "Not Found"
			}
			this.SendText(res.fnLine())
		}
	}
}
req := HttpRequest()
res := HttpResponse()
server := TestServer(10000)