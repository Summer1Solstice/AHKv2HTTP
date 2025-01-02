# AHKv2HTTP
A crude, rough and makeshift AHKv2 HTTP server.
# 注意
1. 脚本基于[thqby的Socket](https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk)
2. 只有文本消息传输的功能，不支持文件传输。
3. 没有刻意注意字符编码，在这方面可能有BUG。
4. 同时只能处理一个连接。
5. 只有服务端功能，没有客户端功能。
# 已知BUG
抄大佬的代码，解决了[从这抄的](https://github.com/thqby/ahk2_lib/blob/244adbe197639f03db314905f839fd7b54ce9340/HttpServer.ahk#L473-L484)。 
> ~~GET请求的查询参数，无法解码但可以用ANSI字符。超出的需要额外处理。~~   

重写了一部分

> ~~有些属性可能会随着使用不断变大，这是因为只在类实例化的时候才初始化。~~
~~使用的时候，基本都是添加键值的写法，没有清空重新赋值。~~
## TODO
- [x] 考虑之后重写代码，封闭函数，对属性赋值而不是添加键值。
## 使用方法
脚本内演示了基于请求路径的用法。
```AutoHotkey
req.fnParse(this.RecvText())
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
```

## 类、属性、方法
### 类：HttpRequest
用于解析HTTP请求。
#### 方法
- `fnParse(Request)`，接受原始请求字符串，解析请求行、请求头、请求数据。
- `fnParseLine(Line)`，接受一个字符串，按空格解析请求行。    
    没有返回值，解析后赋值`this.Line`的`Method`、`Url`、`HttpVersion`。    
    如果有GET查询参数，一同解析，赋值`this.GETQueryArgs`，类型Map。   
- `fnParseHeader(Header)`，接受一个数组，将数组解析为请求头。  
    返回值为Map。
#### 属性
**请求行**
- 请求方法：`this.Line.Method`，类型为字符串。
- 请求路径：`this.Line.Url`，类型为字符串。
- HTTP版本：`this.Line.Version`，类型为字符串。

**请求头**
- `this.Headers`，类型为Map。

**请求体**
- `this.Body`，类型为字符串。

**查询参数**
- `this.GETQueryArgs`，GET请求的查询参数，类型为Map。

**原始请求**
- `this.Request`，使用`socker`的`this.RecvText()`获取到的原始请求。
### 类：HttpResponse
用于生成服务器响应消息。
#### 方法
- `fnGenerate`用于生成响应字符串。  
    接受5个参数，`line`、`sc`、`msg`、`headers`、`body`。默认值是对应的同名属性。   
    保存并返回`this.Response`，使用`socker`的`this.SendText()`发送。
- `GetStrSize`用于获取body的字节长度。    
    从AutoHotkeyv1的[AHKHTTP](https://github.com/zhamlin/AHKhttp/blob/c6267f67d4a3145c352c281bb58e610bcf9e9d77/AHKhttp.ahk#L323-L327)脚本复制而来。

#### 属性
**状态行**
- HTTP版本：`this.Line`，类型为字符串。
- 状态码：`this.sc`，类型为数字。
- 状态描述：`this.msg`，类型为字符串。

**响应头**
- `this.Headers`，类型为Map。

**响应体**
- `this.Body`，类型为字符串。

**响应消息**
- `this.Response`，类型为字符串。
