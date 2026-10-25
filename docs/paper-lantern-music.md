# 留白里的灯 / Paper Lantern

为 SL 漫画人生创作的原创循环背景音乐。主页与漫画阅读共用同一轨，进入人物对话时继续播放；旁白、逐字音效保留独立播放器。

- [试听 / 下载 WAV](../assets/music/paper_lantern.wav)
- [可编辑 MIDI](../assets/music/paper_lantern.mid)
- [完整事件谱 JSON](../assets/music/paper_lantern.score.json)
- [合成与编曲源代码](../tools/compose_paper_lantern.py)
- [音频检测数据](../assets/music/paper_lantern.analysis.json)

## 参考与创作边界

用户提供的网易云曲目经歌曲元数据接口核对为 Toby Fox 的《Undertale》（39227624）、《His Theme》（39227633）、《Snowy》（39224616），均属于 UNDERTALE Soundtrack。官方参考入口：[Undertale](https://tobyfox.bandcamp.com/track/undertale)、[His Theme](https://tobyfox.bandcamp.com/track/his-theme)、[Snowy](https://tobyfox.bandcamp.com/track/snowy)。官方页面将原声归入 soundtrack / chiptune / MIDI / orchestral 等标签。

本次工具能够核对元数据与官方页面，无法直接听取这三个链接中的音频，因此不声称完成了听音扒谱、准确的节拍测量或音色复刻。创作采用温柔、怀旧、轻微惆怅的游戏配乐方向：清亮短音、拨弦伴奏、留白旋律和逐层展开的和声。

旋律、配器与合成代码为本项目新写；没有下载、截取或混入参考录音，没有转写参考旋律。文件中也没有第三方音源、声库或游戏采样。这里是一首完整编配的合成器配乐，不是真实乐器录音。

## 音乐设计

80 BPM，4/4，32 小节，96 秒，D 大调 / B 小调色彩；使用 add9、maj7 与挂留和弦，避免持续高能量打点干扰阅读。

| 时间 | 内容 | 编配变化 |
| --- | --- | --- |
| 0–24 秒 | 灯亮起 | 钟琴式主旋律、稀疏拨弦、轻低音 |
| 24–48 秒 | 翻到旧页 | 换一段新旋律，加入柔和键盘与和声铺底 |
| 48–72 秒 | 有人同行 | 主题回归，局部高八度光点与轻刷声呼应 |
| 72–96 秒 | 还有留白 | 减少音符与伴奏密度，回接第一小节 |

旋律不是全程重复琶音：伴奏维持节拍，主旋律具有独立的长短句与停顿。合成音色由正弦谐波、分频衰减与短攻击包络构成；没有使用硬方波压低位深来制造刺耳感。

## Godot 接入

`AudioFX.music("paper_lantern")`、`music("title")` 与 `music("story")` 返回同一缓存音频。播放器挂在 SceneTree 根节点下，从主页切换到 LifeComic 后不会随主页销毁；同轨重复请求不从头开始。直接启动 LifeComic 也会播放。

进入时用 0.7 秒音量淡入，默认播放器音量为 -14 dB。漫画顶部的“音乐：开 / 关”只暂停背景音乐，保留对白音效；再次开启从暂停位置继续。开关在本次应用会话中保留，未做跨启动偏好存储。

运行时设置 `AudioStreamWAV.LOOP_FORWARD`，循环帧范围 `[0, 3072000)`，计数单位为立体声帧而非交错声道样本。WAV 导入配置关闭压缩，保持 32 kHz / 双声道 / 16-bit PCM。结局仍使用原项目的独立结局短曲。

## 循环与验证

合成时把尾音和多次延迟反射环绕回曲首，避免在最后一拍截断混响；循环文件没有额外的静音尾巴或整曲淡出。音符自身带平滑起落包络。独立播放 WAV 一次会正常结束，循环由 Godot 的播放资源控制。

检测结果：峰值 -2.00 dBFS，RMS 约 -15.96 dBFS，削波样本为 0；首尾相邻帧差值峰值约 0.00635（满幅为 1）。这些是样本级指标，不等于 LUFS，也不能替代主观试听。

`test/paper_lantern_smoke.gd` 检查导入格式、实际长度、循环帧边界，并让 Godot 解码器从第 95.98 秒跨越曲尾，确认继续输出并回到曲首；同时检查跨场景存活、同轨不重播、暂停与恢复。测试无需播放到第 96 秒。

```sh
python -m pip install numpy
python tools/compose_paper_lantern.py
godot --headless --editor --import --path .
godot --headless --path . --script res://test/paper_lantern_smoke.gd
```

MIDI 提供五个旋律乐器轨道，方便在 DAW 中换音源；完整合成音色、刷声和循环反射以 Python 与 JSON 谱为准，通用 MIDI 播放器不会与 WAV 音色完全相同。
