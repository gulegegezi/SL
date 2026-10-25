# 芯片音效库

`scripts/audio_fx.gd`：**运行时合成**音效，仓库里没有任何 `.wav`/`.ogg`。
换机器、换平台都不会丢资源；headless 跑测试时只是静音，不会报错。

音色走 8-bit 家用机 UI 的路子：方波 / 三角波 / 噪声，极短衰减，幅度做 4-bit 量化，
所以颗粒感强、偏电子，而不是柔和的正弦。全部为原创合成。

## 音效清单（17 个）

| 名字 | 时长 | 波形 | 用在哪 |
| --- | --- | --- | --- |
| `blip` | 26ms | 方波 1180Hz | 对白逐字（主角） |
| `blip_low` | 30ms | 方波 520Hz | 对白逐字（其他角色） |
| `blip_big` | 46ms | 方波 300Hz | 旁白/系统音 |
| `move` | 16ms | 方波 1480Hz | 选项悬停 |
| `select` | 104ms | 方波 784→1175 | 确认选择 |
| `cancel` | 120ms | 方波 660→440 | 取消 / 返回 |
| `locked` | 140ms | 方波 + 噪声 | 条件不满足的选项 |
| `page` | 110ms | 噪声 | 翻页 / 新页出现 |
| `reveal` | 22ms | 方波 1046Hz | 单格显影 |
| `discover` | 184ms | 三角琶音 C-E-G-C | 观察到新线索 |
| `result` | 210ms | 方波三音 | 选择结果页 |
| `save` | 232ms | 三角四音 | 书签保存 |
| `hurt` | 180ms | 方波下滑 + 噪声 | 受伤 / 数值下降 |
| `heal` | 160ms | 三角上滑 | 恢复 |
| `coin` | 80ms | 方波两音 | 获得金钱 |
| `chapter` | 240ms | 方波三音 | 新一话开始 |
| `ending` | 550ms | 三角五音 | 结局 |

## 接在哪

| 位置 | 触发 |
| --- | --- |
| `comic_panel._process` 打字机 | 每个字一声 `speak()`，标点与空白跳过，55ms 节流；非主角用低音 |
| `comic_page.reveal_panels` | 新页出现时 `page` |
| `main._ink_choice_btn` | 悬停 `move` |
| `main._render_result` | 结果页 `result` |
| `main._on_game_ended` | 结局 `ending` |

## 接口

```gdscript
AudioFX.play(host, "select")            # host 任意节点，自带 6 路发声池
AudioFX.speak(panel, low := true)        # 逐字音，音高随机抖动 ±6%
AudioFX.enabled = false                  # 全局静音
AudioFX.volume_db = -12.0                # 全局音量
```

## 试听 / 导出

```bash
godot --headless --path . --script res://tools/probe_audio.gd -- <输出目录>
```

会把 17 个音效导出成 WAV，并打印每个音的时长、峰值、RMS，方便直接听或做电平检查。

## 注意

- 不要把这些音效当成「采样素材」再分发；它们是代码生成的。
- 新增音效只要在 `stream()` 的 `match` 里加一行 `_render(...)`，然后在调用点 `play()`。
- 发声池是**每个 host 6 路**：同一帧里连打多个音会复用最早的，不会堆积延迟。
