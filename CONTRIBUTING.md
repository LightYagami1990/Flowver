# 贡献指南

欢迎为 Flowver 贡献代码、建议或反馈！Flowver 是一款极简 EPUB 听书 App，核心理念是降低阅读门槛、培养阅读习惯、服务盲人等特殊群体。

## 如何贡献

1. **Fork 本仓库** 到你的 GitHub 账号。
2. **创建分支**：`git checkout -b feature/your-feature-name`
3. **提交更改**：`git commit -m "feat: 描述你的更改"`
4. **推送分支**：`git push origin feature/your-feature-name`
5. **打开 Pull Request**，描述你的更改动机和测试情况。

## 开发环境

- macOS + Xcode 14+
- iOS 15.0+
- Swift 5.7+

## 依赖库

- [Zip](https://github.com/marmelroy/Zip)：解压 EPUB
- [Fuzi](https://github.com/cezheng/Fuzi): 轻量 XML/HTML 解析

在 Xcode 中通过 **File → Add Packages** 添加上述两个库。

## 代码风格

- 使用 SwiftUI 构建 UI。
- 保持极简：不添加不必要的设置、主题、字体调整等。
- 所有面向用户的字符串请使用中文，并在必要时考虑无障碍（VoiceOver）标签。
- 提交信息采用 [Conventional Commits](https://www.conventionalcommits.org/) 格式，例如：`feat: 增加语速调节`，`fix: 修复 EPUB 解析崩溃`。

## 问题反馈

如果你在使用中遇到 Bug 或有功能建议，请在 GitHub Issues 中提交，尽可能包含：
- iOS 版本与设备型号
- 复现步骤
- EPUB 文件是否可提供（如涉及解析问题）

## 许可证

本项目采用 [MIT 许可证](LICENSE)。
