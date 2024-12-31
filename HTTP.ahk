#Requires AutoHotkey v2.0

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
		this.Body := ""
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
			; https://github.com/thqby/ahk2_lib/blob/244adbe197639f03db314905f839fd7b54ce9340/HttpServer.ahk#L473-L484
			Queries := StrSplit(Queries, ["&", "="])
			for i in Queries {
				if InStr(i, "%"){
					DllCall('shlwapi\UrlUnescape', 'str', i, 'ptr', 0, 'uint*', 0, 'uint', 0x140000)
					Queries[A_Index] := i
				}
			}
			this.GETQueryArgs.Clear
			this.GETQueryArgs.Set(Queries*)
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
		this.Headers.Clear
		this.Headers["Content-Length"] := 0
		if this.Body != "" {
			this.Headers["Content-Length"] := this.GetStrSize(this.Body)
		}
		this.Line .= this.sc " " this.msg "`r`n"
		this.Response := this.Line
		this.Headers["Server"] := A_AhkVersion
		for k, v in this.Headers {
			this.Response .= k ": " v "`r`n"
		}
		this.Response .= "`r`n"
		this.Response .= this.Body
		this.Body := ""
		return this.Response
	}
	GetStrSize(str, encoding := "UTF-8") {
		; https://github.com/zhamlin/AHKhttp/blob/c6267f67d4a3145c352c281bb58e610bcf9e9d77/AHKhttp.ahk#L323-L327
		encodingSize := ((encoding = "utf-16" || encoding = "cp1200") ? 2 : 1)
		; length of string, minus null char
		return StrPut(str, encoding) * encodingSize - encodingSize
	}

}
