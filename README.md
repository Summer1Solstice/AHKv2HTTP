# AHKv2HTTP
适用于AutoHotkey v2的HTTP服务器。  
**警告**  
脚本尽可能实现 HTTP 协议的规范要求，因“没有发现那里有问题”或“技术力不足”等原因，在部分细节上可能存在问题。  
# 注意事项
1. 脚本基于[thqby的Socket](https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk)
2. 不支持复杂的HTTP协议机制，如：分块传输。
3. 实现多连接时，手动增加了对象引用计数，可能存在没有减少计数，导致AHK无法自动回收内存的问题。
# 使用方法
## 开始
1. 实例化类`HttpServer`，同时传入端口号。  
2. 调用类实例方法`SetPaths`传入URL路径对应的处理函数，变量类型`Map`。  
3. 调用类实例方法`SetMimeType`传入如下格式的文件的路径，用于设置文件的MIME类型。
    ```
    html: text/html
    jpg: image/jpeg
    ```
### 可选配置项
| 配置项 | 默认值 | 说明            |
| ------ | ------ | --------------- |
| Web    | false  | 是否开启Web服务 |
## 使用
- 当URL路径被访问时调用`paths`中相应的处理函数。  
- 调用处理函数时，传入两个参数，请求`Request`和响应`Response`，处理函数必须有两个参数接受传入。    
- `Request`类实例属性`BodyBuf`包含请求体，类型为`Buffer`。
    - 通过`Body`动态属性获取，或直接调用`Body()`并传入编码来提取文本。  
- 调用`Response`类实例方法`SetBodyText`发送文本，传入字符串，可选传入编码。  
- 调用`Response`类实例方法`SetBodyFile`发送文件，传入文件路径，可选传入编码。  
- 其他请求头、响应头等，可以直接访问传入处理函数的参数`Request`和`Response`的属性。
### 示例
[示例脚本](example.ahk)  
[mimetype](mimetypes)
# 请求 Request 类
## 可用 Req 属性
| 属性     | 描述                 | 类型   | 默认值   |
| -------- | -------------------- | ------ | -------- |
| Request  | 未解析的原始请求     | String |          |
| Method   | 请求方法             | String |          |
| Url      | 请求URL              | String |          |
| Protocol | HTTP协议版本         | String | HTTP/1.1 |
| Headers  | 请求头               | Map    |          |
| BodyBuf  | 请求体               | Buffer |          |
| GetArgs  | 查询参数             | Map    |          |
| IP       | 不一定是客户端的IP   | String |          |
| Encoding | 请求类的默认文本编码 | String | UTF-8    |
## 可用 Req 方法
### `GetBodyText(Encoding := "UTF-8")`
从`Req.BodyBuf`中以指定编码提取文本。
- **参数**
    - `encoding` (**String**, 可选): 请求体的文本编码，默认值：使用默认文本编码。  
        可从`Content-Type`中提取客户端设置的编码。
- **返回**
    - `String`: 文本

# 响应 Response
## 可用 Res 属性
| 属性     | 描述                 | 类型          | 默认值                                                           |
| -------- | -------------------- | ------------- | ---------------------------------------------------------------- |
| Response | 最终生成的HTTP响应   | String        |                                                                  |
| Line     | HTTP协议版本         | String        | HTTP/1.1                                                         |
| sCode    | 响应代码             | Int           | 200                                                              |
| sMsg     | 响应消息             | String        | OK                                                               |
| Headers  | 响应头               | Map           | 必要的`Content-Length`、`Content-Type`和`HttpServer`预设的响应头 |
| Body     | 响应体               | String/Buffer | 类型取决于响应体内容，默认为字符串。                             |
| Encoding | 响应类的默认文本编码 | String        | UTF-8                                                            |

## 可用 Res 方法
### `SetBodyText(Str, Encoding := "")`
将文本设置为响应体，包含响应头`Content-Length`、`Content-Type`的设置。无返回值。
- **参数**
    - `Str` (**String**, 必填): 文本。
    - `Encoding` (**String**, 可选): 传入编码，则响应头`Content-Type`将添加`"; charset=" Encoding `。
### `SetBodyFile(FilePath, Encoding := "")`
将文件作为响应体，包含响应头`Content-Length`、`Content-Type`的设置。无返回值。
- **参数**
    - `FilePath` (**String**, 必填): 文件路径，不存在则抛出错误。
    - `Encoding` (**String**, 可选): 传入编码，则响应头`Content-Type`将添加`"; charset=" Encoding `。
### `SetErrorRes(Code)`
设置错误响应，仅支持部分响应码。  
不支持的响应码，返回`500`错误。  
无返回值。
- **参数**
    - `Code` (**Int**, 必填): 错误码。
### `SetRedirect(Url, Code := 302)`
设置重定向。无返回值。
- **参数**
    - `Url` (**String**, 必填): 重定向的URL。
    - `Code` (**Int**, 可选): 状态码，默认为302。
# HttpServer 类
## 可用属性
- `Web`: `bool`类型，是否在访问路径无对应路由函数时，尝试解析为`Web`请求。  
    为真，尝试返回本地文件。 为假，则返回`404`错误。
- `root`: `String`类型，静态文件目录。  
    默认值为当前脚本所在目录。
- `onFunc`：`Map`类型，存储回调函数，不区分大小写。  
    可用的值有`isIPAllow`、`PreHandleReq`、`PreSendRes`详见回调函数章节。
## 可用方法
### `LoadMimeType(FilePath)`
加载MIME类型。
- **参数**
    - `FilePath` (**String**, 必填): mimetype文件路径。
### `SetPaths(Paths)`
设置访问路径对应路由函数。
包含对路由函数的参数数目检查。
- **参数**
    - `Paths` (**Map**, 必填): 保存路径和路由函数的映射关系的`Map`对象。
## 回调函数
### `isIPAllow(IP)`
检测IP是否允许访问。
- **传入**
    - `IP` (**String**): 向服务端发起连接的IP。不一定是客户端的IP。
- **返回**
    - 返回`true`表示允许访问，返回`false`表示拒绝访问。
### `PreHandleReq(req, res)`、 `PreSendRes(req, res)`
- `PreHandleReq(req, res)`：在请求解析完成后，处理请求前。
- `PreSendRes(req, res)`：在返送响应前执行。
- **传入**
    - `req` (**class**): 请求类的实例对象。
    - `res` (**class**): 响应类的实例对象。
- **返回**
    - 返回`0`继续向下执行；
    - 返回`-1`拒绝访问，断开连接；
    - 返回任意正整数，则视为响应码，返回对应响应，如果没有对应的预设响应，返回`500`错误响应。
    - **不允许空返回**
## 对响应的预设方法
`DefResLine`、`DefResHeader`、`DefResBody`，单个方法包含了对响应的预设。  
需要通过派生类进行方法重写来覆盖`HttpServer`类对响应的预设行为。
### `DefResHeader` 预设响应头
 - Content-Location: 请求的URL
 - Date: RFC1123 格式的UTC时间
 - Server: AutoHotkey版本

如果请求头包含`Connection: close`，响应头也包含并在响应结束后主动关闭连接。  
### `DefResBody` 预设响应体
请求方法为`HEAD`时，清空响应体。  
请求方法为`TRACE`时，返回原始请求（可能不包含完整请求体）。
# 错误日志
预期内的错误会输出日志到`A_WorkingDir\logs\{date}.log`文件。
# 更新日志
- 2026/02/16  
    现在服务端的大部分行为都可以通过派生类，重写方法来修改。  
- 2026/04/14
    请求类的属性`Body`改为动态属性，包含`call`属性，默认使用`UTF-8`调用`GetBodyText()`方法。
# 关于HTTPS
使用caddy反向代理来实现HTTPS，至少我是这么做的。  
觉得`http://ip:port`太长可以尝试使用`.localhost`域名，局域网尝试使用设备名称+`.lan`或`.local`域名。  
```Caddyfile
ahk.localhost {
	reverse_proxy :port
}
```
> 302重定向应用占用`80/443`端口，可将其设置为监听`127.0.0.2`。caddy设置为监听具体IP而非`0.0.0.0`。
# 其他
### TODO
 - [ ] 细化日志，详细错误原因，记录引发错误的数据。

### 代码规范
需要用户自行编写的逻辑，应该尽量做到仅需要用户，定义函数、赋值到特定位置、传递返回值。
### 流程图
[流程图](流程.md)