# AHKv2HTTP
A crude, rough and makeshift AHKv2 HTTP server.
#### 警告：这个脚本从设计到实现，都很简单。
#### 可能存在一些意料之中和意料之外的问题，但只要还能满足基本需求，就不会进一步改进。
#### 如果需要简单的HTTPserver建议尝试Python的http.server
# 注意事项
1. 脚本基于[thqby的Socket](https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk)
2. 没有刻意注意字符编码，在这方面可能有BUG。
3. 同时最好只有一个连接，没有针对多连接的处理。
4. 不支持复杂的HTTP协议机制，如：分块传输。
# 已知缺陷
输出错误日志待完善。  
请求体过长截断的问题已经解决，使用大小`9.76M`的UTF-8编码txt文件进行测试没有问题，但没有做更多测试。  
感觉在编码方面还是有隐患。~~也可能是我多虑了~~
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
| 配置项     | 默认值 | 说明            |
| ---------- | ------ | --------------- |
| web        | false  | 是否开启Web服务 |
| IPRestrict | true   | 是否开启IP限制  |
## 使用
- 当URL路径被访问时调用`paths`中相应的处理函数。  
- 调用处理函数时，传入两个参数`Request`和`Response`，处理函数必须有两个参数接受传入。    
- 调用类实例方法`SetBodyText`发送文本，传入字符串。  
- 调用类实例方法`SetBodyFile`发送文件，传入文件路径。  
- 调用类实例方法`GetReqBodyText`来获取请求体。
- 其他请求头、响应头等，可以直接访问传入处理函数的参数`Request`和`Response`的属性。
### 回调函数
`HttpServer`包含一个`Map`类型的属性`CallbackFunc`用于存放回调函数。
- `IPAudit`  
    入参为`ip:port, "Access"`。  参数1 为访问的IP和端口，参数2 为调用的时机，用于限制IP访问，需`IPRestrict`为`true`。  
    函数返回`true`则允许访问，返回`false`则拒绝访问。
- 其他暂无，没什么需求。
## 可用属性
**Request**包含以下属性：
| 属性         | 描述             | 类型   | 默认值   |
| ------------ | ---------------- | ------ | -------- |
| Request      | 未解析的原始请求 | String |          |
| Method       | 请求方法         | String |          |
| Url          | 请求URL          | String |          |
| Protocol     | HTTP协议版本     | String | HTTP/1.1 |
| Headers      | 请求头           | Map    |          |
| Body         | 请求体           | String |          |
| GetQueryArgs | 查询参数         | Map    |          |


**Response**包含以下属性：
| 属性     | 描述               | 类型          | 默认值                                                                                                                                                                                        |
| -------- | ------------------ | ------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Response | 最终生成的HTTP响应 | String        |                                                                                                                                                                                               |
| Line     | HTTP协议版本       | String        | HTTP/1.1                                                                                                                                                                                      |
| sCode    | 响应代码           | Int           | 200                                                                                                                                                                                           |
| sMsg     | 响应消息           | String        | OK                                                                                                                                                                                            |
| Headers  | 响应头             | Map           | Content-Length: res.body.Length,<br>Content-Location: req.Url,<br>Content-Type: text/plain,<br>Date: FormatTime("L0x0409", "ddd, d MMM yyyy HH:mm:ss"),<br>Server: "AutoHotkey/" A_AhkVersion |
| Body     | 响应体             | String/Buffer | 如果请求体过长，产生分段，则`body`为`Buffer`。 使用`GetReqBodyText`提取文本                                                                                                                                                                                 |


## 日志
预期内的错误会输出日志到`A_WorkingDir\logs\{date}.log`文件。

### TODO

 - [x] 细化日志

 - [x] 优化`HTTP.log`  
    
 - [x] 优化`ParseRequest`的If结构。  

 - [x] 尝试优化请求体过长（极限大概是几KB）截断的问题，现有的处理逻辑会导致字符的字节丢失。  

 ~~- [ ] 重写。没有方向搁置~~