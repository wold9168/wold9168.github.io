---
layout: post
title: "为了 jekyll 开始使用 CI/CD"
tags: [jekyll, yaml, cicd]
author:
- wold9168
math: false
render_with_liquid: false
---

到自己个人 blog 站看了一眼，发现前两天写的[《开始使用 jekyll》](/tech/techblog/2025/11/01/start-to-use-jekyll.html)一文的渲染有问题。我早就知道 GitHub Pages 里 jekyll 的行为和本地有所不同，然而没想到它连`render_with_liquid`参数都不支持。（该参数负责将页面内的 liquid 渲染功能关闭，方便展示 liquid 代码。）

想来这个参数应该是一个新特性，GitHub Pages 的 jekyll 版本实在太老了些，于是让 AI 生成了一个 jekyll 的 CI 流程出来——又不甚好用，怎么都 build 不上去。最后一想，我自己的工作机上这个 jekyll 跑得很好，干脆直接让它和我工作机用一样的环境做 CI 流程就好了。

遂与 AI 语：

> 打住。这样吧，我希望CI里面使用和我本机相同版本的ruby和bundle。
>
> 我本机使用的是fedora42自带的ruby和bundle，版本如下：
>
> ❯ ruby -v
>
> ruby 3.4.5 (2025-07-16 revision 20cda200d3) +PRISM [x86_64-linux]
>
> ❯ bundle -v
>
> Bundler version 2.6.9
>
> 你想办法用fedora完成这个CI流程，或者直接用我提供在这里的这个版本

最后根据 jekyll 官方文档又剪裁了一番，现在使用的 CI 流程是这样的：

```yaml
name: Deploy Jekyll site to Pages (Fedora 42)

on:
  push:
    branches: ["main"]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: "pages"
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-latest  # runner OS, but we override with container
    container: fedora:rawhide  # Fedora 42 (development branch)

    steps:
      - name: Install system dependencies
        run: |
          sudo dnf install -y ruby ruby-devel openssl-devel redhat-rpm-config gcc-c++ @development-tools

      - name: Checkout
        uses: actions/checkout@v4

      - name: Verify Ruby and Bundler versions
        run: |
          ruby -v   # should be ~3.4.5
          bundle -v # should be 2.6.9

      - name: Install gems
        run: |
          bundle install --jobs 4

      - name: Build Jekyll site
        run: bundle exec jekyll build
        env:
          JEKYLL_ENV: production

      - name: Upload artifact
        uses: actions/upload-pages-artifact@v3
        with:
          path: ./_site

  deploy:
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    runs-on: ubuntu-latest
    needs: build
    steps:
      - name: Deploy to GitHub Pages
        uses: actions/deploy-pages@v4
```
