# AHKv2HTTP
A crude, rough and makeshift AHKv2 HTTP server.
# 注意
1. 脚本基于[thqby的Socket](https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk)
2. 只有文本消息传输的功能，不支持文件传输。
3. 没有刻意注意字符编码，在这方面可能有BUG。
4. 同时只能处理一个连接。
5. 没有考虑错误处理。  
6. 不适合复杂需求，如：分块传输等。
# TODO
- [x] 请求方法全部转大写
- [ ] 添加错误处理，类型验证。
- [ ] URL编码调用DLL部分，需要优化。
# 其他
旧版本，仅实现服务端功能，本体和示例在 old 文件夹中。

# 思索
向响应生成方法，传入`socket`实例，由HTTP的server方法操作如何返回响应数据，分两步传输响应头部和body，这样就可以传输文件了。    
但还需要`MIME`方法，v1的`AHKhttp`可以借鉴。
文件传输需要单独的方法吗？
可能要考虑重写`Server`类？
~~实例化一个socket.server，调用~~
考虑继承Socket.Server来写HTTP服务端