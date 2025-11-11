---
layout: post
title: "Wine 的小妙招：快速检索 Windows 程序使用的 dll"
tags: [wine, ]
author:
- wold9168
math: false
render_with_liquid: false
---

我很常用很常用的一个指令是`objdump -x ./foo.exe |grep -i DLL | uniq | sort`，这个指令可以帮我快速排查 Windows 程序使用的 dll 文件，从而帮我定位我应该从 Winetricks 中下载什么 dll。

```
❯ objdump -x ./th123.exe |grep -i DLL | uniq | sort
DllCharacteristics      00000000
        DLL Name: d3d9.dll
        DLL Name: d3dx9_33.dll
        DLL Name: GDI32.dll
        DLL Name: imagehlp.dll
        DLL Name: IMM32.dll
        DLL Name: KERNEL32.dll
        DLL Name: ole32.dll
        DLL Name: USER32.dll
        DLL Name: WINMM.dll
        DLL Name: WS2_32.dll
 vma:            Hint    Time      Forward  DLL       First

```

它应该是来源于我读过的某篇 issue。我就说读 issue 有用，这就给我学到东西了。
