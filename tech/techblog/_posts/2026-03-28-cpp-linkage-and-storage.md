---
layout: post
title: "C++ 链接性与存储期"
tags: [development, C++]
author:
  - wold9168
math: false
render_with_liquid: false
---

只有不在任何函数作用域内的「顶层对象」需要区分链接性。顶层对象默认具有静态存储期。

```cpp
int a = 1; // 顶层对象默认具有外部链接性，可以被其他文件用 extern 进行访问
static int local_var = 2; // 使用 static 去将其链接性限制在文件内
```

存储期一共有：
- 静态存储期：对象在程序启动时分配，在程序结束时销毁。包括全局变量、命名空间变量、`static`局部变量、`static`类成员
- 线程存储期：对象生命周期跟着线程走，使用`thread_local`声明
- 自动存储期：对象生命周期跟着作用域走
- 动态存储期：对象生命周期跟着 `new`/`malloc` 和 `delete`/`free` 走

用排除法来甄别静态存储期对象比较好。

命名空间变量其实和全局变量没什么区别，就是外面包了一层命名空间。

```cpp
namespace MathUtils {
  double pi = 3.1415926535; // 命名空间变量
  const int max_buffer = 1024;
}
```
