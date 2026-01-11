---
layout: post
title: ".PHONY构建目标提示Nothing to be done for ..."
tags: [makefile, development,]
author:
- wold9168
math: false
render_with_liquid: false
---

在使用Makefile进行项目构建时，偶见报错`Nothing to be done for ...`，这个问题的一个常见原因是构建目标的缩进使用了空格而非制表符（Tab）。

Makefile有一个非常严格的要求：所有的命令行（即构建规则中的实际执行命令）必须以制表符（Tab）开头，而不能使用空格。如果你不小心使用了空格来缩进命令，make将无法正确识别这些命令，从而导致"Nothing to be done"的错误信息。

例如，正确的写法应该是：
```makefile
.PHONY: build
build:
	@echo "Building..."  # 这里必须是Tab缩进
	npm run build        # 这里也必须是Tab缩进
```

而错误的写法是：
```makefile
.PHONY: build
build:
    @echo "Building..."  # 错误：这里使用了空格缩进
    npm run build        # 错误：这里使用了空格缩进
```
