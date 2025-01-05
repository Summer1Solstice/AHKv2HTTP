# AHKv2HTTP
A crude, rough and makeshift AHKv2 HTTP server.
# 注意
1. 脚本基于[thqby的Socket](https://github.com/thqby/ahk2_lib/blob/master/Socket.ahk)
2. 只有文本消息传输的功能，不支持文件传输。
3. 没有刻意注意字符编码，在这方面可能有BUG。
4. 同时只能处理一个连接。
5. 没有考虑错误处理。
可以实现客户端功能，但没写，因为不清楚具体都有那些需求。
# TODO
- [ ] 请求方法全部转大写
- [ ] 添加错误处理，类型验证。
- [ ] URL编码调用DLL部分，需要优化。
# 其他
旧版本，仅实现服务端功能，本体和示例在 old 文件夹中。