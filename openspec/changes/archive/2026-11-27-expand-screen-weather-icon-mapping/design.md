# 设计：尽量扩大副屏天气图标的动画映射

## 映射补充

| code | 含义 | 资源 |
| --- | --- | --- |
| 900 | 热 | `sun-hot` |
| 901 | 冷 | `thermometer-mercury-cold` |
| 503 / 504 / 505 / 507 / 508 | 扬沙 / 浮尘 / 沙尘暴 | `dust` |

## 同族兜底

```js
var n = parseInt(code, 10);
if (n >= 100 && n < 200) return n >= 150 ? 'clear-night' : 'clear-day';
if (n >= 300 && n < 400) return n >= 350 ? 'overcast-night-rain' : 'overcast-day-rain';
if (n >= 400 && n < 500) return 'snow';
if (n >= 500 && n < 600) return 'fog';
return null;
```

顺序：精确表优先 → 同族兜底 → 返回 null，由 `renderHeroFallback()` 使用旧 `weatherIcon()`。
`999` 无天气语义，保持静态回退；这样既不空白，也不假装知道天气。

## 资源

- 动画：`thermometer-mercury-cold.svg`、`sun-hot.svg`、`dust.svg`
- 静态：`static-thermometer-mercury-cold.svg`、`static-sun-hot.svg`、`static-dust.svg`
- 均来自 Meteocons Monochrome 0.1.0，MIT；无需新增许可证文件。

## 验证

- 901 / 900 / 503 在无头浏览器中均为 `wx-asset`、`viewBox 0 0 128 128`、SMIL 动画节点 > 0。
- 999 仍回退 `0 0 24 24` 静态图标。
- 原有 28 组映射与静态降级不变。
