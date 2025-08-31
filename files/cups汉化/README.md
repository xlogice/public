
# 汉化CUPS

1) 将文件夹doc-root及文件夹下文件，复制到 /usr/share/cups 文件夹下。

2) 将文件夹templates及文件夹下文件，复制到 /usr/share/cups 文件夹下。

3) 在/etc/cups/cupsd.conf文件中添加以下内容

```
DefaultLanguage zh_CN
```