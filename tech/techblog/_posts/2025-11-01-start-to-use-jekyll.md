---
layout: post
title: "开始使用 jekyll"
tags: [jekyll, javascript]
author:
- wold9168
math: true
render_with_liquid: false
---

今天敲定使用 jekyll 作为自己的 blog 方案。说来惭愧，很早的时候就有做个人 blog 的想法，但苦于前端对我而言实在是太复杂了，因而 blog 的工作一拖再拖。我至少从 2020 年开始有做个人 blog 的想法，而今已经 2025 年了，一拖就是五年。我期间试过很多方案——hexo、hugo、jekyll，还有其他的许多。我最后选定 jekyll，原因如下：

- jekyll 为 GitHub Pages 官方所兼容，可以在几乎所有的静态网页托管服务上使用
- jekyll 在 GitHub Pages 上的部署不需要复杂的 CI/CD 流程，我并不反感 CI/CD，但光就个人的 blog 也要来这么一遭为免杀鸡用牛刀
- jekyll 的默认主题 minima 还算雅观，并且结构上相当简单，即便是我这种前端一窍不通的笨蛋也一眼就能看懂
- 我经常使用的发行版里基本都涵盖了 jekyll 的打包

## 引入数学支持

数学支持是必要的，因为我经常有在文档里写\\(\LaTeX\\)数学公式的需要。

我本来想直接干脆换个主题，不使用 minima。新的主题也许会为我提供数学公式的支持，我于是浏览了[GitHub Topics #jekyll-theme](https://github.com/topics/jekyll-theme)——一无所获。好看的主题不带数学支持，带数学支持的主题要么不好看要么特性太多太复杂，再不然就是一些主题和 blog 无关的，比如简历，以及其他种种。

我于是决定自己动手丰衣足食。

[Haixing Hu 的这篇 blog](https://haixing-hu.github.io/programming/2013/09/20/how-to-use-mathjax-in-jekyll-generated-github-pages/) 我看了。总的来说，他的思路是对的，但我用了 minima 主题，我不知道怎么把引入 JS 脚本的关键代码添加到对应的 layout 里。Hu 的博文给出的关键代码是如下的：

```javascript
<script type="text/x-mathjax-config">
  MathJax.Hub.Config({
    TeX: {
      equationNumbers: {
        autoNumber: "AMS"
      }
    },
    tex2jax: {
      inlineMath: [ ['$','$'], ['\(', '\)'] ],
      displayMath: [ ['$$','$$'] ],
      processEscapes: true,
    }
  });
</script>
<script type="text/javascript"
        src="http://cdn.mathjax.org/mathjax/latest/MathJax.js?config=TeX-AMS-MML_HTMLorMML">
</script>
```

这段代码只要写到 _includes 下，然后通过 Liquid 的条件控制语句进行启用就行，不嫌页面加载慢的可以直接把这段加到 layout 里。对应的方法，Hu 的 blog 原文都有介绍。

我希望的是一种更加「官方」的方法，让我能够修改我现在正在使用的主题，要么自己维护一个分支，要么有一种方案能让我把我的修改 patch 到原有的模板里。如果要我自己维护一个分支，我至少要确认我这样自己维护一个分支的做法会不会不利好我未来合并上游的修改，一个逻辑上于此具有弱关联的点在于：我需要获知我自己维护一个分支的做法是否是社区的普遍做法——如果是，那么上游在进行大的更新的时候想来是必须要考虑社区的情绪的，进而也许会给出新的解决方案。[jekyll/minima #100](https://github.com/jekyll/minima/issues/100) 这条 Issue 给了我关键的回答。Jekyll 支持通过 overriding theme 的方法对主题进行修改[^1]，一言以蔽之就是拷贝本地存有的主题文件到自己的仓库里，自己维护这个主题分支。并且用户不要为此给自己的主题单独打一个包，主题干脆直接就在站点的仓库里维护。

[^1]: https://jekyllrb.com/docs/themes/#overriding-theme-defaults

我于是添加了数学支持，不过我取用了新版本的 Mathjax。Hu 给出的代码已经是很老版本的 Mathjax 了（Mathjax 2.7.1）。

```javascript
<script id="MathJax-script" async src="https://cdn.jsdelivr.net/npm/mathjax@4.0.0/tex-mml-chtml.js"></script>
```

我发现行内代码没有作用，我于是参阅了 [Mathjax 的文档](https://docs.mathjax.org/en/latest/input/tex/delimiters.html)，我觉得他们说的很有道理。

> ... but it does not define $...$ as in-line math delimiters. That is because dollar signs appear too often in non-mathematical settings, which could cause some text to be treated as mathematics unexpectedly.

我以前是使用 Trilium 的，Trilium 内置的编辑器是 CKEditor 5。这个编辑器有个特点——它通过富文本实现了 Markdown 的大部分特性，并且所见即所得。然而我是个数学公式使用量很大的人，我在笔记里大量穿插使用 LaTeX 公式。然而 CKEditor 5 不支持你行内去插入一个公式。如果你要插入一个公式块，那么你在行首的时候就要输入美元号，或者你把别处的一个公式块当作图片一样拷贝过来。

```Markdown
$formula$ 这样的一个公式块是会被 CKEditor 5 渲染的。
如果我这样输入公式 $formula$，那么这个公式块会被 CKEditor 5 直接无视。
```

社区当时给了一个很棒的脚本，脚本的出处链接我有点找不到了，内容是这样的：

```javascript
class ReplaceFormulasButton extends api.NoteContextAwareWidget {

    get parentWidget() {
        return 'center-pane';
    }

    doRender() {
        this.$widget = $(`<style type="text/css">
            .replace-formulas-icon.ribbon-tab-title-icon.bx:before {
                content: "\\1D4C1";
            }
        </style>`);
        return this.$widget;
    }

    async refreshWithNote() {
        $(document).ready(() => {
            if (!$("div.component.note-split:not(.hidden-ext) div.ribbon-tab-title").hasClass('replace-formulas-button')) {
                $("div.component.note-split:not(.hidden-ext) .ribbon-tab-title:not(.backToHis)").last().after(`
                    <div class="replace-formulas-button ribbon-tab-spacer"></div>
                    <div class="replace-formulas-button ribbon-tab-title">
                        <span class="replace-formulas-icon ribbon-tab-title-icon bx" title="Replace Formulas"></span>
                    </div>
                `);
            }
            $('div.component.note-split:not(.hidden-ext) div.replace-formulas-button').off("click", replaceFormulas);
            $('div.component.note-split:not(.hidden-ext) div.replace-formulas-button').on("click", replaceFormulas);
        });
    }
}

var replaceFormulas = function () {
    api.getActiveContextTextEditor().then(editor => {
        const data = editor.getData();

        const regex = /\$\$(.*?)\$\$|\$(.*?)\$/gs;
        let replacedData = data;
        let matchFound = false;

        replacedData = replacedData.replace(regex, (match, p1, p2) => {
            matchFound = true;
            if (p1) {
                return `<span class="math-tex">\\[${p1.replace(/<br\s*\/?>/gi, '')}\\]</span>`;
            } else if (p2) {
                return `<span class="math-tex">\\(${p2.replace(/<br\s*\/?>/gi, '')}\\)</span>`;
            }
        });

        if (matchFound) {
            editor.setData(replacedData);
            api.showMessage('Formulas have been successfully replaced.');
        } else {
            api.showMessage('No formulas found to replace.');
        }
    }).catch(error => {
        console.error('Failed to get CKEditor instance:', error);
        api.showMessage('An error occurred while trying to replace formulas.');
    });
};

module.exports = new ReplaceFormulasButton();
```

Trilium 支持用户自己通过 JavaScript 脚本去创建点什么，当作插件用。这就是个例子。这个脚本的作用是给你的 Trilium 添加一个按钮，这个按钮按下，然后 Trilium 会把当前文档里**所有**美元符号（`$`）包裹的内容都渲染成数学公式。

好吧，问题已经很明显了，CKEditor 5 的公式块是一种近乎于图片的东西。如果你因为某种很自然的需求（比如说需要描述一百万美元，1M$——一种很自然的写法），恰巧在一个自然段里写了两个美元符号，那么当你需要渲染数学公式的时候，这个小插件就会让你的文档大爆特爆——即便你最后能修一修。

我不再使用 Trilium 的一大原因就是我在上面根本找不到好用的方案去解决数学公式的问题。Trilium 真的很好用，我在上面屯了天文数字的笔记，但是我最后还是被迫转向别的笔记软件。我现在正在使用 Joplin，起码 Joplin 里面存的还是 Markdown，公式能轻易渲染出来，并且导出的工作会简单些。Trilium 导出笔记的实现太烂，你导出笔记以后导出的 Markdown 是非标准的，我当时是先导出成 HTML，然后用 pandoc 再转换一遍。图片的附件也是一个很大的问题，再就是我希望我日记里`root / Journal / 2025 / 09 - 九月 / 07 - 周日 / 新建笔记`这样的笔记可以被保存为`2025/09/20250907.md`，这样才方便我导入到 Joplin 里。以后可能什么时候聊一下怎么从 Trilium 迁移到 Joplin。

## Tags，还有 Categories

我离开 Trilium 的另一个原因就是，Trilium 对标签的支持实在是一坨。倒不是说它支持得不好，相反，Trilium 的「属性」是我见过对「文档标签」这一概念最好的实现，它甚至允许你去通过这个标签与插件协作，实现许多很酷很炫的效果，比如`#sorted`标签让当前笔记下的所有子笔记按标题排序。但是这个标签用起来实在是太别扭了。——我无法通过这个标签很轻松地检索我的笔记。

我对我的所有文档系统——无论是笔记还是 blog，亦或者是其他的什么，都有比较强的标签上的需求。我认为我们对万事万物只有两种描述模式，一种是「建构主义」的，一种是「分析主义」的。这就像是面向对象里，一个是组合（has-a），一个是描述（is-a）。这里的「建构主义」和「分析主义」是我随手拿来用的词。

「建构主义」对应 Tags，「分析主义」对应 Categories。这两种主义的分歧在于，Tags 可以重复持有，Categories 则有互斥性。好比我们现在有一篇关于 AI 的笔记，如果使用 Tags，我们可以同时给这篇笔记打上`AI`和`Software Design`（软件设计）的标签；如果是 Categories 的想法，我们就只能让这篇笔记归属于`AI`，然后把`AI`设置为`Software Design`的子分类。——也许所有的 AI 都是软件设计的一环。

那假如我们现在又有一个 Category，它叫`Software Implement`（软件实现）——恰与`Software Design`「水火不相容」，那么我们又有一篇笔记，是一篇有关「如何在生产实践中构建一个 AI 应用」的笔记。那我们不就遇到问题了吗？——这篇新笔记，究竟是放入到`Software Design/AI`这个 Category 下，还是放入`Software Implement`下？一千个哈姆雷特！[^2]

[^2]: 一千个人就有一千个哈姆雷特。形容不同的读者有不同的理解。这里用来描述不同的人有不同的解决方案，并且这种解决方案很多。

比如我们可以在`Software Implement`下新建一个`AI`分类——但这样我们就无法通过一个全局唯一的标识符`AI`去定位我们所有的`AI`文章了。

比如我们可以把`AI`单独提出来，和`Software Design`和`Software Implement`作为同一等级的 Category，让他们并列存在。但是这样，我们就无形中消解了既有笔记「又是 AI 相关，又与软件设计相关」的语义。

这里就是有一千种一万种方法，一种优雅的做法还是 Trilium 做的，它的笔记拷贝类似于创建这个笔记的一个快捷方式。好吧，这也是一种方案，并且是相当优雅的方案，几乎就是把 Categories 当成 Tags 用！唯一的缺点就是当你的笔记分类过于复杂以至于你不可能记住所有细节的时候，你需要为这个分类方案单独维护一篇文档，并且你很难快速反应过来一个笔记应该被分类到哪些 Category 下，尤其是「复制，然后拖动『快捷方式』到其他 Category 下」的这种方案可不允许你搞什么语法补全。——你如果要回忆一下「c」开头的 Category，那你就得自己一个个找。

Tags 的方案也不尽善尽美，因为分类和标签从含义上就是两个东西，一篇文章可能是技术报告，一篇文章的标签也可以是技术报告，但一篇文章的标签更该是「英伟达 CUDA 架构」「C 语言」这样一些更贴近文章内容的东西。我们还是要把两者区分开一些。

并且 Categories 的必要性在于，如果你维护了笔记（文档）的唯一性，即让笔记同时只能归属于一个 Category，那么你检索起这个笔记来会很快。如果你要破坏这种唯一性，那么 Categories 会变好用一点，那是因为它变成 Tags 了，然后你就会看到一大堆同属一个 Tag 的东西挤在一个 Tag 下。我们是很快定位到了可能含有这个「属性/性质/特质」（比如「C 语言」）的文件，但这未免太多了！检索起来效率该低还是低。那最好再内置一个搜索引擎，然后再再提供模糊搜索。Tags 最好也区分出多级的结构来，最好给 Tags 组织一个树状结构，甚至于给 Tags 打 Tags……

话题跑远了，总之我需要我的 jekyll 站点同时提供 tags 和 categories 两种机制。

很棒，jekyll 本来就支持这种东西。我在 minima 主题上只要做两点工作：

- 提供一个 Tags 和 Categories 的导览页，就像 [cppreference 的 std 符号索引](zh.cppreference.com/w/cpp/symbol_index)一样。
- 让每个页面前面显示它的 Tags，至于 Categories，这东西已经在URL路径里面显现了。

我的做法是这样，我从[官方的文档](https://jekyllrb.com/docs/posts/#tags-and-categories)里抄来这样一段代码，改了改就是这个：

```liquid
{% for category in site.categories %}
  <h3><a href="/{{ category[0] }}">{{ category[0] }}</a></h3>
  <ul>
    {% for post in category[1] %}
      <li>
        <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
        <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%Y-%m-%d" }}</time>
      </li>
    {% endfor %}
  </ul>
{% endfor %}
```

Tags 的代码与此类似：

```liquid
{% for tag in site.tags %}
  <h3>{{ tag[0] }}</h3>
  <ul>
    {% for post in tag[1] %}
    <li>
        <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
        <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%Y-%m-%d" }}</time>
    </li>
    {% endfor %}
  </ul>
{% endfor %}
```

minima 会自动把根目录下的 html 文件加入到导航栏里。

现在我只要在 post 的前面加上 front matters 就好了，就像这篇文章的 front matters 一样。

```Liquid
---
layout: post
title: "开始使用 jekyll"
tags: [jekyll, javascript]
author:
- wold9168
math: true
---
<!--你现在正在看的正文-->
```

That's all. 我一上午都在忙这个，或者说一凌晨。

### 为 category 添加 index.html

我希望有一个 index.html，适用于 jekyll 的每一个 category，为我陈列这个 category 下的所有文章。

我不要手动填写任何内容。我只要在一个空白的文件上应用一个 layout 就应该能生成这个 category index，这个效果无限趋近于其他的一些 jekyll 竞品提供的某种路由功能。

我忙活了一会儿，旋即想到 AI 也许正擅长于此，然后我就得到了这个：

```liquid
---
layout: default
---

{%- comment -%}
从页面路径中提取分类标签
例如：path = category/tech/index.html → categories = ["tech"]
      path = category/linux/tips/index.html → categories = ["linux", "tips"]
{%- endcomment -%}

{%- assign path_parts = page.path | split: '/' -%}
{%- assign cat_list = "" | split: "" -%}

{%- for part in path_parts -%}
  {%- unless part == "category" or part == "index.html" or part == "" -%}
    {%- assign cat_list = cat_list | push: part -%}
  {%- endunless -%}
{%- endfor -%}

{%- if cat_list.size == 0 -%}
  <p>未指定分类。</p>
{%- else -%}
  <h1>分类：{{ cat_list | join: " / " }}</h1>

  {%- comment -%}
  筛选同时包含所有 cat_list 中分类的文章
  {%- endcomment -%}
  {%- assign filtered_posts = site.posts -%}
  {%- for cat in cat_list -%}
    {%- assign temp_posts = "" | split: "" -%}
    {%- for post in filtered_posts -%}
      {%- if post.categories contains cat -%}
        {%- assign temp_posts = temp_posts | push: post -%}
      {%- endif -%}
    {%- endfor -%}
    {%- assign filtered_posts = temp_posts -%}
  {%- endfor -%}

  <ul>
  {%- for post in filtered_posts -%}
    <li>
      <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
      <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%Y-%m-%d" }}</time>
    </li>
  {%- endfor -%}
  </ul>

  {%- if filtered_posts.size == 0 -%}
    <p>暂无文章。</p>
  {%- endif -%}
{%- endif -%}
```

将这个文件保存到你的`_layout/`里，修改它应用的`layout`为你自己想要的别的什么 layout，然后在你的每个 category 下面都创建一个 index.html，只用简单填上这样三行代码：

```liquid
---
layout: category-index # 取决于你把前面的代码复制到 _layout/ 以后命名为什么
---
```

然后[奇迹发生](/tech/techblog)。

### 多级 category 的支持

```liquid
{% assign all_paths = "" %}
{% for post in site.posts %}
  {% if post.categories.size > 0 %}
    {% assign path = post.categories | join: "/" %}
    {% assign all_paths = all_paths | append: "," | append: path %}
  {% endif %}
{% endfor %}

{% assign unique_paths = all_paths | split: "," | uniq %}

{% for path in unique_paths %}
  {% unless path == empty %}
    <h3><a href="/{{ path }}">{{ path }}</a></h3>
    <ul>
      {% for post in site.posts %}
        {% assign post_path = post.categories | join: "/" %}
        {% if post_path == path %}
          <li>
            <a href="{{ post.url | relative_url }}">{{ post.title }}</a>
            <time datetime="{{ post.date | date_to_xmlschema }}">{{ post.date | date: "%Y-%m-%d" }}</time>
          </li>
        {% endif %}
      {% endfor %}
    </ul>
  {% endunless %}
{% endfor %}
```

这是前面所有`categories.html`的最新版本。加入了对各 category 的`index.html`的路由以后，我才发现 jekyll 并不原生支持多级 category。不过我们自有办法。

上面这个`categories.html`将列举你所有的站点文章，然后统计其 category 情况，最后将这些 category 一口气输出出来。

我个人认为这玩意儿的效率不会高到哪里去，毕竟是对全站的一个穷举。实际上维护一个 category 的列表会更优雅一点。不过这种穷举对于小规模的站点而言已经很够用了。考虑复杂点儿的情况，我应该专门写一个 Makefile，然后用这个 Makefile 来维护一个 category 索引表。

总之它的最终效果你们能在[这个页面](/categories)看到。
