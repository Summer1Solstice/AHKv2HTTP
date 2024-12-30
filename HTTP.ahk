#Requires AutoHotkey v2.0
Persistent
#Include <Socket> ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk
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
					req.Body ? "" : res.Body
					for k, v in req.GETQueryArgs{
						res.Body .= k "=" v "`n"
					}
				default: res.Body := "404 Not Found", res.sc := 404, res.msg := "Not Found"
			}
			this.SendText(res.fnLine())
		}
	}
}

class HttpRequest {
	__New() {
		this.Request := ""
		this.Line := {}
		this.Headers := {}
		this.Body := ""
		this.GETQueryArgs := Map()
	}
	fnParse(Request) {
		this.Request := Request
		arrRequest := StrSplit(Request, "`r`n")
		this.fnParseLine(arrRequest[1])
		arrRequest.RemoveAt(1)
		blankLines := 0
		for i in arrRequest {
			if i = "" {
				arrRequest.RemoveAt(1, blankLines + 1)
				break
			}
			this.fnParseHeader(i)
			blankLines += 1
		}
		for i in arrRequest {
			this.Body .= i "`n"
		}
	}
	fnParseLine(Line) {
		Line := StrSplit(Line, A_Space)
		this.Line.Method := Line[1]
		this.Line.Url := Line[2]
		this.Line.HttpVersion := Line[3]
		pos := InStr(this.Line.url, "?")
		if this.Line.Method = "GET" and pos {
			url := SubStr(this.Line.url, 1, pos - 1)
			Queries := SubStr(this.Line.url, pos + 1)
			this.Line.url := url
			Queries := StrSplit(Queries, "&")
			for i in Queries {
				arrQuery := StrSplit(i, "=")
				this.GETQueryArgs[arrQuery[1]] := arrQuery[2]
			}
		}
	}
	fnParseHeader(Header) {
		arrHeader := StrSplit(Header, ": ")
		this.Headers.%arrHeader[1]% := arrHeader[2]
	}
}
class HttpResponse {
	__New() {
		this.Line := "HTTP/1.1 "
		this.sc := 200
		this.msg := "OK"
		this.Headers := Map()
		this.Body := ""
		this.Response := ""
	}
	fnLine() {
		sc := this.sc, msg := this.msg
		this.Headers["Content-Length"] := 0
		if this.Body != "" {
			this.Headers["Content-Length"] := this.GetStrSize(this.Body)
		}
		this.Line .= sc " " msg "`r`n"
		this.Response := this.Line "Server: AutoHotkey`r`n"
		for k, v in this.Headers {
			this.Response .= k ": " v "`r`n"
		}
		this.Response .= "`r`n"
		this.Response .= this.Body
		return this.Response
	}
	GetStrSize(str, encoding := "UTF-8") {
		; https://github.com/zhamlin/AHKhttp/blob/c6267f67d4a3145c352c281bb58e610bcf9e9d77/AHKhttp.ahk#L323-L327
		encodingSize := ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1)
		; length of string, minus null char
		return StrPut(str, encoding) * encodingSize - encodingSize
	}

}
req := HttpRequest()
res := HttpResponse()
server := TestServer(10000)