# Flowver

让阅读重新变得简单，让声音陪你走进文字的世界。

Flowver 是一款为 iOS 设计的极简 EPUB 听书 App。核心愿景是：在这个高速信息化的社会里，越来越多人被碎片信息裹挟，静不下心读完一本书。Flowver 以降低阅读门槛为出发点，帮助用户培养阅读习惯，同时让盲人、低视力人群及阅读障碍者也能平等地享受书本带来的乐趣与知识。

---

## 为什么做 Flowver

- **让阅读更简单**：不需要拿着纸书，不需要盯着屏幕逐字阅读。把 EPUB 小说导入，一键播放，让声音陪你读完每一段。
- **培养阅读习惯**：极简操作、无复杂设置，把“打开就听”作为默认体验，帮助用户把听书变成日常习惯，再慢慢回归文字阅读。
- **服务特殊群体**：盲人、弱视人群、阅读障碍者等，往往难以获得便捷的数字阅读渠道。Flowver 以“听”为主，配合系统语音，让他们也能独立享受书本。

---

## 核心特性

### 1. 音量键翻页（固定音量）
在固定系统音量的前提下，设备侧边的音量键不再调节音量，而是直接映射为：
- **音量 + → 下一句**
- **音量 - → 上一句**

你无需看屏幕，无需解锁手机，单手即可流畅地控制小说的前后句，非常适合盲人用户、弱视用户，以及任何希望在走路、做家事、闭目养神时听书的场景。

### 2. EPUB 支持
导入本地 EPUB 文件，自动解析章节并按句子切分，适配系统语音逐句播放。

### 3. 系统语音合成（多语言支持）
调用苹果 `AVSpeechSynthesizer`，根据文本自动识别语言并切换合成语音，支持：
- **中文（zh-CN）**
- **英文（en-US）**
- **日语（ja-JP）**
- **韩语（ko-KR）**

### 4. 护眼极简 UI
背景采用护眼米黄，文字纯黑，大行间距，UI 参考苹果自带图书。没有字体颜色、字号、主题等无关调整，只保留播放/暂停、章节进度、句子文本，让注意力集中在内容本身。

### 5. 锁屏后台播放
支持 `UIBackgroundModes = audio`，锁屏后语音继续播放，配合系统锁屏媒体控制（上一句 / 下一句 / 暂停 / 继续），让听书不受打断。

---

## 项目结构

```
Flowver/
├── Package.swift          # Swift Package 依赖说明（可选，Xcode 也可直接拖入源码）
├── .gitignore
├── README.md
└── ListenBooks/           # 源码目录（保留历史目录名，不影响编译）
    ├── App.swift          # @main 入口（FlowverApp）
    ├── ContentView.swift  # 底部分栏（书库 / 听书）
    ├── LibraryView.swift  # 书库：列出 Documents/Books 下的 EPUB，支持导入
    ├── ReaderView.swift   # 听书器：护眼背景、句子文本、播放控制
    ├── ChapterPickerView.swift  # 章节跳转
    ├── Book.swift         # 数据模型
    ├── EPUBParser.swift   # EPUB 解压 + OPF/NCX/XHTML 解析 + 句子切分
    ├── SpeechManager.swift# AVSpeechSynthesizer 封装（多语言自动检测 + 锁屏媒体控制）
    └── VolumeKeyHandler.swift # 音量键拦截（固定音量 + 翻页映射）
```

---

## 依赖库（Swift Package Manager）

- [Zip](https://github.com/marmelroy/Zip)：解压 EPUB
- [Fuzi](https://github.com/cezheng/Fuzi)：轻量 XML/HTML 解析（读取 OPF、XHTML 并提取纯文本）

---

## 如何编译运行（需要 Mac + Xcode）

Flowver 是原生 iOS Swift 源码，**不能在 iPhone 或 iPad 上直接编译**，请在 Mac 上按以下步骤操作：

1. 在 Mac 上打开 Xcode，新建项目 → **App** → Interface: **SwiftUI** → Life Cycle: **SwiftUI** → Language: **Swift**。
2. 把 `ListenBooks/` 目录下所有 `.swift` 文件拖入 Xcode 项目（勾选 "Copy items if needed"）。
3. 在 Xcode 中添加 Swift Package 依赖：
   - File → Add Packages…
   - 输入 `https://github.com/marmelroy/Zip.git`
   - 输入 `https://github.com/cezheng/Fuzi.git`
4. 在项目 `Info.plist` 中添加 `UIBackgroundModes` → `App plays audio`（以便锁屏后继续播放）。
5. 按 `Cmd + R` 运行到连接的 iPhone 或模拟器。

---

## 如何添加书籍

1. 将 EPUB 文件拷贝到 App 的 `Documents/Books` 目录；
2. 或在 App 内点击书库右上角 **＋** 使用系统文件选择器导入 EPUB。

---

## 音量键原理说明（简要）

`VolumeKeyHandler` 向窗口添加一个不可见的 `MPVolumeView`，观察系统音量 `UISlider` 的值变化。用户按侧边音量键时，App 捕获后立即将音量重置回固定值（默认 0.5），并映射为：
- 音量变大 → 下一句
- 音量变小 → 上一句

这属于基于公开 API 的交互技巧，不涉及越狱或私有 API。

---

## 开源与协议

本项目采用 **MIT 协议** 开源，欢迎 fork、修改和贡献。

如果你有 Mac 环境，可以直接编译运行；如果你希望在 GitHub 上查看或参与，代码已开源在：  
🔗 https://github.com/LightYagami1990/Flowver

---

## 未来方向（保持极简）

- 暂不增加文字颜色、字号、主题切换等设置，坚持“听为主”的初衷。
- 如需上架 App Store，需自行处理隐私政策、文件导入 entitlements 及审核指南。

---

> Flowver，愿每一个想静下心来阅读的人，都能找到属于自己的节奏。
