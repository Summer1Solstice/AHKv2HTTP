#Requires AutoHotkey v2.0
Persistent
#Include ../lib/Socket.ahk ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk
#Include HTTP.ahk

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
				case "/echo": res.Body := "echo: `n" req.Request
				default: res.Body := "404 Not Found", res.sc := 404, res.msg := "Not Found"
			}
			this.SendText(res.fnGenerate())
			; DeBug(req, res)
		}
	}
}
req := HttpRequest()
res := HttpResponse()
server := TestServer(10000)

; client := Socket.client("127.0.0.1", 10000)
; client.SendText("GET / HTTP/1.1`r`nContent-Length: 0`r`n`r`n")
; OutputDebug client.RecvText()

