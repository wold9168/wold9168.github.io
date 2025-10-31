# 数学支持

cite: https://docs.mathjax.org/en/latest/input/tex/delimiters.html

---

## 对应文件

- `_includes/head.html`
- `_includes/math-support.html`

## 输入方案

首先是 Markdown 通用的使用`$$多行公式$$`进行跨行包裹公式块的做法。

其次是在 Markdown 文件中使用`\\[多行公式\\]`和`\\(单行公式\\)`。因为 jekyll 会在 Markdown 转换为 HTML 的时候，将`\`视为转义字符。

遵循 mathjax 弃用`$单行公式$`。
