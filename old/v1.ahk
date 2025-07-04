#Requires AutoHotkey v2.0
/************************************************************************
 * @date 2025/01/01
 * @version 1.1.1
 ***********************************************************************/
; HTTP请求
class HttpRequest {
	__New() {
		this.Request := ""
		this.Line := {}
		this.Headers := Map()
		this.Body := ""
		this.GETQueryArgs := Map()
	}
	fnParse(Request := this.Request) {
		this.Request := Request
		; Body
		boby := SubStr(Request, InStr(Request, "`r`n`r`n") + 4)
		this.fnParseBody(boby)
		Request := StrReplace(Request, "`r`n`r`n" boby)
		; Line
		Request := StrSplit(Request, "`r`n")
		this.fnParseLine(Request[1])
		Request.RemoveAt(1)
		; Header
		this.fnParseHeader(Request)
	}
	fnParseLine(Line) {
		Line := StrSplit(Line, A_Space)
		this.Line.Method := Line[1]
		this.Line.Url := Line[2]
		this.Line.HttpVersion := Line[3]
		pos := InStr(this.Line.url, "?")
		if this.Line.Method = "GET" and pos {
			Queries := SubStr(this.Line.url, pos + 1)
			this.Line.url := SubStr(this.Line.url, 1, pos - 1)
			; https://github.com/thqby/ahk2_lib/blob/244adbe197639f03db314905f839fd7b54ce9340/HttpServer.ahk#L473-L484
			Queries := StrSplit(Queries, ["&", "="])
			for i in Queries {
				if InStr(i, "%") {
					DllCall('shlwapi\UrlUnescape', 'str', i, 'ptr', 0, 'uint*', 0, 'uint', 0x140000)
					Queries[A_Index] := i
				}
			}
			m := Map()
			this.GETQueryArgs := m.Set(Queries*)
		}
	}
	fnParseHeader(Header) {
		Headers := Map()
		for i in Header {
			kv := StrSplit(i, ": ")
			Headers.Set(kv*)
		}
		return this.Headers := Headers
	}
	fnParseBody(Body) {
		this.Body := Body
	}
}
; HTTP响应
class HttpResponse {
	__New() {
		this.Line := "HTTP/1.1"
		this.sc := 200
		this.msg := "OK"
		this.Headers := Map()
		this.Body := ""
		this.Response := ""
	}
	fnGenerate(line := this.Line, sc := this.sc, msg := this.msg, Headers := this.Headers, Body := this.Body) {
		line := Format("{1} {2} {3}", Line, sc, msg)
		Headers["Content-Length"] := 0
		if this.Body != "" {
			this.Headers["Content-Length"] := GetStrSize(this.Body)
		}
		if not Headers.Get("Server", 0)
			Headers["Server"] := "AutoHotkey/" A_AhkVersion
		Response := line "`r`n"
		for k, v in Headers {
			Response .= k ": " v "`r`n"
		}
		Response .= "`r`n"
		if Body != "" {
			Response .= Body
		}
		return this.Response := Response
	}
}
GetStrSize(str, encoding := "UTF-8") {
	; https://github.com/zhamlin/AHKhttp/blob/c6267f67d4a3145c352c281bb58e610bcf9e9d77/AHKhttp.ahk#L323-L327
	encodingSize := ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1)
	; length of string, minus null char
	return StrPut(str, encoding) * encodingSize - encodingSize
}