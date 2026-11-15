import UIKit
import MediaPlayer

/// 音量键拦截处理器
/// 原理：向窗口添加一个不可见的 MPVolumeView，观察其内部 UISlider 的 value 变化。
/// 用户按设备侧边音量键时，系统音量会随之变化，我们捕获变化后立即把音量重置回固定值，
/// 并把“音量加”映射为“下一句”，“音量减”映射为“上一句”。
final class VolumeKeyHandler: NSObject {
    static let shared = VolumeKeyHandler()

    private let volumeView = MPVolumeView()
    private weak var slider: UISlider?
    private var lastVolume: Float = 0.0

    var onVolumeUp: (() -> Void)?
    var onVolumeDown: (() -> Void)?

    /// 固定音量（0~1），音量键按下后会被重置为这个值，从而实现“固定音量”的体验
    var fixedVolume: Float = 0.5 {
        didSet { slider?.value = fixedVolume }
    }

    private override init() {
        super.init()

        var targetWindow: UIWindow?
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            targetWindow = windowScene.keyWindow
        }
        if targetWindow == nil {
            targetWindow = UIApplication.shared.windows.first
        }
        guard let window = targetWindow else { return }

        window.addSubview(volumeView)
            volumeView.frame = CGRect(x: -1000, y: -1000, width: 10, height: 10)
            volumeView.isHidden = true
            volumeView.showsRouteButton = false
            volumeView.showsVolumeSlider = false

            // 查找内部的 UISlider（系统音量滑块）
            for view in volumeView.subviews where view is UISlider {
                let s = view as! UISlider
                self.slider = s
                s.value = fixedVolume
                lastVolume = s.value
                s.addTarget(self, action: #selector(volumeSliderChanged(_:)), for: .valueChanged)
                break
            }
        }
    }

    @objc private func volumeSliderChanged(_ slider: UISlider) {
        let current = slider.value
        let delta = current - lastVolume

        // 阈值过小则忽略（避免浮点抖动）
        guard abs(delta) > 0.001 else { return }

        if delta > 0 {
            onVolumeUp?()
        } else {
            onVolumeDown?()
        }

        // 立即重置回固定音量，实现“音量不变”的效果
        slider.value = fixedVolume
        lastVolume = fixedVolume
    }

    func startListening() {
        // 确保音频会话处于播放类别，方便音量键事件被系统分派
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [])
        slider?.value = fixedVolume
        lastVolume = fixedVolume
    }
}
