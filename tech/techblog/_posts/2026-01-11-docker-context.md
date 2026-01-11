---
layout: post
title: "Docker构建上下文导致构建失败"
tags: [docker, dockerfile, development,]
author:
- wold9168
math: false
render_with_liquid: false
---
Docker的构建上下文由`docker buildx build .`这里的`.`指定的路径决定。Dockerfile里进行`COPY`等操作的时候，无法从构建上下文以外的路径拷贝文件，并且不会有明显的报错。

比如，在`Dockerfile`中，如果通过`docker buildx build .`构建项目，则`COPY .. /app`事实上等价于`COPY . /app`，通过相对路径构建的超出构建上下文的路径（此例中为`..`）会被重定向到构建上下文。

换言之，对于子项目比较多的仓库，如若希望构建该仓库子项目的镜像，而该子项目又依赖于同一仓库的另一个子项目，即对应的Docker构建目标，其构建上下文不可以局限于仓库的子项目中。如果`repo/bin/b`依赖于`repo/lib/a`，那么构建上下文就一定要放在`/`里。
