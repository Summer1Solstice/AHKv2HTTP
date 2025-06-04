#Requires AutoHotkey v2.0
Persistent
/************************************************************************
 * @date 2025/04/15
 * @version 2.1.6
 ***********************************************************************/
#Include <Socket> ; https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk
#Include <print>
;@region HTTP
class HTTP {
    ; 获取字符串字节长度
    static GetStrSize(str, encoding := "UTF-8") {
        return StrPut(str, encoding) - ((encoding = "UTF-16" or encoding = "CP1200") ? 2 : 1)
    }
    static GetBodySize(Body) {
        if Type(Body) = "Buffer" {
            return Body.size
        } else {
            temp := HTTP.GetStrSize(Body)
            OutputDebug temp "`n"
            return temp
        }
    }
    ; URL编码
    static UrlEncode(url, component := false) {
        ; https://github.com/thqby/ahk2_lib/blob/master/UrlEncode.ahk
        flag := component ? 0xc2000 : 0xc0000
        DllCall('shlwapi\UrlEscape', 'str', url, 'ptr*', 0, 'uint*', &len := 1, 'uint', flag)
        DllCall('shlwapi\UrlEscape', 'str', url, 'ptr', buf := Buffer(len << 1), 'uint*', &len, 'uint', flag)
        return StrGet(buf)
    }
    ; URL解码
    static UrlUnescape(i) {
        ; https://github.com/thqby/ahk2_lib/blob/244adbe197639f03db314905f839fd7b54ce9340/HttpServer.ahk#L473-L484
        DllCall('shlwapi\UrlUnescape', 'str', i, 'ptr', 0, 'uint*', 0, 'uint', 0x140000)
        return i
    }
    ; ; 消息拼装
    ; static GenerateMessage(Elements) {
    ;     ; 传入参数的验证
    ;     if Type(Elements) != "Map"
    ;         throw TypeError()
    ;     if !Elements.Has("line") or !Elements.Has("headers") or !Elements.Has("body")
    ;         throw UnsetError()
    ;     if Type(Elements["line"]) != "Array" or Type(Elements["headers"]) != "Map"
    ;         throw TypeError()

    ;     line := Format("{1} {2} {3}", Elements["line"]*)    ; 拼装消息行
    ;     ; 拼装消息头
    ;     headers := ""
    ;     for k, v in Elements["headers"] {
    ;         headers .= Format("{1}: {2}`r`n", k, v)
    ;     }
    ;     msg := ""
    ;     ; 判断消息体类型, 是否在消息中包含消息体
    ;     if Type(Elements["body"]) = "Buffer" {
    ;         msg := Format("{1}`r`n{2}`r`n", line, headers)
    ;     } else {
    ;         msg := Format("{1}`r`n{2}`r`n{3}", line, headers, Elements["body"])
    ;     }
    ;     return msg
    ; }
    ; ; 解析mime类型文件
    ; static LoadMimes(File) {    ;考虑优化为JSON
    ;     FileConent := FileRead(File, "`n")
    ;     MimeType := Map()
    ;     MimeType.CaseSense := false
    ;     if InStr(FileConent, ": ") {
    ;         for i in StrSplit(FileConent, "`n") {
    ;             i := StrSplit(i, ": ")
    ;             MimeType.Set(i*)
    ;         }
    ;     } else {
    ;         for i in StrSplit(FileConent, "`n") {
    ;             Types := SubStr(i, 1, InStr(i, A_Space) - 1)
    ;             i := StrReplace(i, Types)
    ;             i := LTrim(i)
    ;             for i in StrSplit(i, A_Space) {
    ;                 MimeType[i] := Types
    ;             }
    ;         }
    ;     }
    ;     return MimeType
    ; }
}
; 请求类
;@region Request
; 请求类
;@region Request
class Request {
    __New() {
        this.Request := ""  ; 原始请求消息
        this.Method := ""   ; 请求方法
        this.Url := ""  ; 请求URL
        this.Protocol := "HTTP/1.1" ; 请求协议
        this.Headers := Map()   ; 请求头
        this.Body := "" ; 请求体
        this.GetQueryArgs := Map()  ; GET请求参数
        this.block := false
    }
    ; 处理请求
    Parse(ReqMsg) {
        if this.block {
            this.Body .= ReqMsg
            if this.Headers.Get("Content-Length", 0) > HTTP.GetBodySize(this.Body) {
                this.block := true
                SetTimer(abc(*) => this.block = false, -3000)
                return false
            }
            this.block := false
            return true
        }
        this.Request := ReqMsg
        LineEndPos := InStr(ReqMsg, "`r`n")    ; 获取消息行结束位置
        BodyStartPos := InStr(ReqMsg, "`r`n`r`n")  ; 获取消息体开始位置
        if not LineEndPos or not BodyStartPos {
            return false
        }
        if not InStr(SubStr(ReqMsg, LineEndPos - 8, 8), "HTTP/") {
            return false
        }
        line := SubStr(ReqMsg, 1, LineEndPos - 1)
        this.ParseLine(line)
        headers := SubStr(ReqMsg, LineEndPos + 2, BodyStartPos - LineEndPos - 2)
        body := SubStr(ReqMsg, BodyStartPos + 4)
        if this.Method = "POST" and not this.block {
            if this.ParseHeaders(headers) {
                if this.Headers.Get("Content-Length", 0) > HTTP.GetBodySize(body) {
                    this.block := true
                }
            }
        } else {
            this.ParseHeaders(headers)
            this.Body := body
        }
    }
    ; 解析请求行
    ParseLine(msg) {
        LineList := StrSplit(msg, A_Space)
        this.Method := LineList[1]
        this.Url := LineList[2]
        this.Protocol := LineList[3]
        if LineList[1] = "GET" and pos := InStr(this.Url, "?") {
            GetArgs := HTTP.UrlUnescape(SubStr(this.Url, pos + 1))
            this.Url := SubStr(this.Url, 1, pos - 1)
            this.GetQueryArgs.Set(StrSplit(GetArgs, ["&", "="])*)
        }
        return true
    }
    ; 解析请求头
    ParseHeaders(msg) {
        HeadersList := StrSplit(msg, ["`r`n", ": "])
        if Mod(HeadersList.Length, 2) {
            return false
        }
        this.Headers.Set(HeadersList*)
        return true
    }
}
;@region HttpServer
class HttpServer extends Socket.Server {
    req := Request()    ; 请求类
    onACCEPT(err) {
        this.client := this.AcceptAsClient()
        this.client.onREAD := onread
        onread(Socket, err) {
            if Socket.MsgSize() {
                this.ParseRequest(Socket)
            }
        }
    }
    ; 解析客户端请求
    ParseRequest(Socket) {
        if this.req.Parse(Socket.RecvText()) {
            FileAppend(this.req.Body, "log.txt", "utf-8")
        }
    }
}

if A_ScriptName = "beta.ahk" {
    Server := HttpServer(10000)
}