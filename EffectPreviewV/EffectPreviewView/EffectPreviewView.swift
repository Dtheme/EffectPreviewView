import UIKit
import AVFoundation

/// 支持图片/视频前后对比滑动的视图组件
public class EffectPreviewView: UIView {
    // MARK: - 子视图
    private let originalImageView = UIImageView()
    private let editedImageView = UIImageView()
    private var originalPlayerLayer: AVPlayerLayer?
    private var editedPlayerLayer: AVPlayerLayer?
    private let maskLayer = CALayer()
    private let sliderView = UIView()
    private let sliderWidth: CGFloat = 28
    private let sliderInnerLineWidth: CGFloat = 3
    private let sliderInnerLineColor: UIColor = UIColor(white: 0.7, alpha: 0.7)
    private let sliderHighlightColor: UIColor = UIColor.white.withAlphaComponent(0.8)
    private let sliderGradientStart: UIColor = UIColor.white.withAlphaComponent(0.95)
    private let sliderGradientEnd: UIColor = UIColor.white.withAlphaComponent(0.6)
    private let originalVideoContainerView = UIView()
    private let editedVideoContainerView = UIView()
    
    // MARK: - 状态
    private var isVideoMode = false
    private var originalPlayer: AVPlayer?
    private var editedPlayer: AVPlayer?
    private var playerObservers: [NSKeyValueObservation] = []
    
    /// 当前滑块位置（0~1，0为左侧，1为右侧）
    public private(set) var sliderPosition: CGFloat = 0.5 {
        didSet {
            onSliderChanged?(sliderPosition)
        }
    }
    /// 是否允许交互
    public var isInteractiveEnabled: Bool = true {
        didSet { sliderView.isUserInteractionEnabled = isInteractiveEnabled }
    }
    /// 滑动回调
    public var onSliderChanged: ((CGFloat) -> Void)?
    
    /// 自定义滑块视图提供者
    public weak var sliderProvider: EffectPreviewSliderProvider? {
        didSet { reloadSliderView() }
    }
    /// 当前滑块视图（可自定义）
    private var customSliderView: UIView? {
        didSet {
            oldValue?.removeFromSuperview()
            if let custom = customSliderView {
                addSubview(custom)
                bringSubviewToFront(custom)
                sliderView.isHidden = true
            } else {
                sliderView.isHidden = false
            }
        }
    }
    
    // MARK: - 遮罩动画与样式自定义
    /// 遮罩边缘样式
    public enum MaskEdgeStyle {
        case normal
        case shadow(color: UIColor, radius: CGFloat)
        case dashed(color: UIColor, width: CGFloat, dashPattern: [NSNumber])
        // 可扩展更多样式
    }
    public var maskEdgeStyle: MaskEdgeStyle = .normal {
        didSet { updateMaskEdgeStyle() }
    }
    /// 动画切换滑块位置
    public func animateSliderPosition(to position: CGFloat, duration: TimeInterval = 0.25, completion: (() -> Void)? = nil) {
        let clamped = min(max(position, 0), 1)
        UIView.animate(withDuration: duration, animations: {
            self.sliderPosition = clamped
            self.updateMaskAndSlider()
        }, completion: { _ in
            completion?()
        })
    }
    private func updateMaskEdgeStyle() {
        switch maskEdgeStyle {
        case .normal:
            maskLayer.shadowOpacity = 0
            maskLayer.borderWidth = 0
            maskLayer.borderColor = nil
            maskLayer.shadowColor = nil
            maskLayer.shadowRadius = 0
            maskLayer.shadowOffset = .zero
            maskLayer.sublayers?.removeAll(where: { $0.name == "dashedEdge" })
        case .shadow(let color, let radius):
            maskLayer.shadowColor = color.cgColor
            maskLayer.shadowOpacity = 0.5
            maskLayer.shadowRadius = radius
            maskLayer.shadowOffset = .zero
            maskLayer.borderWidth = 0
            maskLayer.borderColor = nil
            maskLayer.sublayers?.removeAll(where: { $0.name == "dashedEdge" })
        case .dashed(let color, let width, let dashPattern):
            maskLayer.shadowOpacity = 0
            maskLayer.borderWidth = 0
            maskLayer.borderColor = nil
            maskLayer.shadowColor = nil
            maskLayer.shadowRadius = 0
            maskLayer.shadowOffset = .zero
            // 添加虚线边缘
            let dashed = CAShapeLayer()
            dashed.name = "dashedEdge"
            dashed.frame = maskLayer.bounds
            let path = UIBezierPath()
            path.move(to: CGPoint(x: maskLayer.bounds.maxX, y: 0))
            path.addLine(to: CGPoint(x: maskLayer.bounds.maxX, y: maskLayer.bounds.height))
            dashed.path = path.cgPath
            dashed.strokeColor = color.cgColor
            dashed.lineWidth = width
            dashed.lineDashPattern = dashPattern
            maskLayer.sublayers?.removeAll(where: { $0.name == "dashedEdge" })
            maskLayer.addSublayer(dashed)
        }
    }
    
    // MARK: - 初始化
    public override init(frame: CGRect) {
        super.init(frame: frame)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
    }
    
    // MARK: - UI 构建
    private func setupUI() {
        clipsToBounds = true
        // 原图层
        originalImageView.contentMode = .scaleAspectFit
        addSubview(originalImageView)
        // 编辑层
        editedImageView.contentMode = .scaleAspectFit
        addSubview(editedImageView)
        // 新增：视频容器视图
        originalVideoContainerView.isHidden = true
        editedVideoContainerView.isHidden = true
        addSubview(originalVideoContainerView)
        addSubview(editedVideoContainerView)
        // mask
        editedImageView.layer.mask = maskLayer
        // 优雅现代滑块
        sliderView.backgroundColor = .clear
        sliderView.layer.cornerRadius = sliderWidth / 2
        sliderView.layer.shadowColor = UIColor.black.cgColor
        sliderView.layer.shadowOpacity = 0.18
        sliderView.layer.shadowRadius = 8
        sliderView.layer.shadowOffset = CGSize(width: 0, height: 2)
        addSubview(sliderView)
        // 手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sliderView.addGestureRecognizer(pan)
        sliderView.isUserInteractionEnabled = isInteractiveEnabled
        // 自定义滑块也需要响应拖动
        let customPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        customSliderView?.addGestureRecognizer(customPan)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        originalImageView.frame = bounds
        editedImageView.frame = bounds
        originalVideoContainerView.frame = bounds
        editedVideoContainerView.frame = bounds
        originalPlayerLayer?.frame = originalVideoContainerView.bounds
        editedPlayerLayer?.frame = editedVideoContainerView.bounds
        updateMaskAndSlider()
        drawModernSlider()
        // 滑块为与 view 等高的圆角矩形
        sliderView.layer.cornerRadius = sliderWidth / 2
        sliderView.frame.size.width = sliderWidth
        sliderView.frame.size.height = bounds.height
    }
    
    private func drawModernSlider() {
        // 清除旧内容
        sliderView.layer.sublayers?.removeAll(where: { $0.name == "sliderDesign" })
        // 毛玻璃效果
        if #available(iOS 13.0, *) {
            if sliderView.subviews.first(where: { $0 is UIVisualEffectView }) == nil {
                let blur = UIVisualEffectView(effect: UIBlurEffect(style: .systemThinMaterialLight))
                blur.frame = sliderView.bounds
                blur.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                blur.isUserInteractionEnabled = false
                blur.alpha = 0.5
                sliderView.insertSubview(blur, at: 0)
            }
        } else {
            sliderView.backgroundColor = UIColor.white.withAlphaComponent(0.25)
        }
        // 半透明蒙层
        let overlay = CALayer()
        overlay.name = "sliderDesign"
        overlay.frame = sliderView.bounds
        overlay.backgroundColor = UIColor.white.withAlphaComponent(0.12).cgColor
        overlay.cornerRadius = sliderView.bounds.width / 2
        sliderView.layer.insertSublayer(overlay, at: 1)
        // 外圈微弱描边
        let border = CAShapeLayer()
        border.name = "sliderDesign"
        border.path = UIBezierPath(roundedRect: sliderView.bounds, cornerRadius: sliderView.bounds.width / 2).cgPath
        border.strokeColor = UIColor(white: 0.85, alpha: 0.22).cgColor
        border.fillColor = UIColor.clear.cgColor
        border.lineWidth = 1.0
        sliderView.layer.addSublayer(border)
    }
    
    // MARK: - 图片模式
    public func setImages(original: UIImage, edited: UIImage) {
        isVideoMode = false
        originalImageView.image = original
        editedImageView.image = edited
        originalImageView.isHidden = false
        editedImageView.isHidden = false
        // 隐藏视频容器
        originalVideoContainerView.isHidden = true
        editedVideoContainerView.isHidden = true
        removeVideoLayers()
    }
    
    // MARK: - 视频模式
    public func setVideos(originalItem: AVPlayerItem, editedItem: AVPlayerItem) {
        isVideoMode = true
        // 新增：视频容器显示
        originalVideoContainerView.isHidden = false
        editedVideoContainerView.isHidden = false
        originalImageView.isHidden = true
        editedImageView.isHidden = true
        // 原视频
        let originalPlayer = AVPlayer(playerItem: originalItem)
        let originalLayer = AVPlayerLayer(player: originalPlayer)
        originalLayer.videoGravity = .resizeAspect
        originalVideoContainerView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        originalVideoContainerView.layer.addSublayer(originalLayer)
        // 编辑后视频
        let editedPlayer = AVPlayer(playerItem: editedItem)
        let editedLayer = AVPlayerLayer(player: editedPlayer)
        editedLayer.videoGravity = .resizeAspect
        editedVideoContainerView.layer.sublayers?.forEach { $0.removeFromSuperlayer() }
        editedVideoContainerView.layer.addSublayer(editedLayer)
        // 赋值
        self.originalPlayer = originalPlayer
        self.editedPlayer = editedPlayer
        self.originalPlayerLayer = originalLayer
        self.editedPlayerLayer = editedLayer
        // mask 由 editedVideoContainerView 设置
        observePlaybackEnd()
        syncPlayers()
        observePlayers()
        setNeedsLayout()
    }
    
    private func removeVideoLayers() {
        originalPlayerLayer?.removeFromSuperlayer()
        editedPlayerLayer?.removeFromSuperlayer()
        originalPlayerLayer = nil
        editedPlayerLayer = nil
        originalPlayer = nil
        editedPlayer = nil
        playerObservers.removeAll()
        removePlaybackEndObservers()
        // 隐藏视频容器
        originalVideoContainerView.isHidden = true
        editedVideoContainerView.isHidden = true
    }
    
    // MARK: - 拖动逻辑
    @objc private func handlePan(_ gesture: UIPanGestureRecognizer) {
        guard isInteractiveEnabled else { return }
        let location = gesture.location(in: self)
        let percent = min(max(location.x / bounds.width, 0), 1)
        sliderPosition = percent
        updateMaskAndSlider()
    }
    
    private var maskShapeLayer: CAShapeLayer? // 用于复用
    
    private func updateMaskAndSlider() {
        let sliderX = bounds.width * sliderPosition
        if isVideoMode {
            // 视频模式：editedVideoContainerView 设置 mask
            let path = UIBezierPath(rect: CGRect(x: sliderX, y: 0, width: bounds.width - sliderX, height: bounds.height))
            let maskShape: CAShapeLayer
            if let existing = maskShapeLayer {
                maskShape = existing
            } else {
                maskShape = CAShapeLayer()
                maskShapeLayer = maskShape
            }
            maskShape.path = path.cgPath
            maskShape.frame = bounds
            editedVideoContainerView.layer.mask = maskShape
        } else {
            // 图片模式：editedImageView 设置 mask
            let path = UIBezierPath(rect: CGRect(x: sliderX, y: 0, width: bounds.width - sliderX, height: bounds.height))
            let maskShape: CAShapeLayer
            if let existing = maskShapeLayer {
                maskShape = existing
            } else {
                maskShape = CAShapeLayer()
                maskShapeLayer = maskShape
            }
            maskShape.path = path.cgPath
            maskShape.frame = bounds
            editedImageView.layer.mask = maskShape
        }
        sliderView.frame = CGRect(x: sliderX - sliderWidth/2, y: 0, width: sliderWidth, height: bounds.height)
        if let custom = customSliderView {
            custom.frame = sliderView.frame
        }
        updateMaskEdgeStyle()
    }
    
    // MARK: - 播放同步
    private func syncPlayers() {
        guard let o = originalPlayer, let e = editedPlayer else { return }
        o.actionAtItemEnd = .pause
        e.actionAtItemEnd = .pause
        // 保持同步
        o.addPeriodicTimeObserver(forInterval: CMTimeMake(value: 1, timescale: 30), queue: .main) { [weak self] time in
            guard let self = self, let e = self.editedPlayer else { return }
            if abs(CMTimeGetSeconds(time) - CMTimeGetSeconds(e.currentTime())) > 0.05 {
                e.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero)
            }
        }
    }
    private func observePlayers() {
        playerObservers.removeAll()
        if let o = originalPlayer, let e = editedPlayer {
            let obs1 = o.observe(\AVPlayer.rate, options: [.new]) { [weak self] player, _ in
                guard let self = self else { return }
                if self.editedPlayer?.rate != player.rate {
                    self.editedPlayer?.rate = player.rate
                }
            }
            let obs2 = e.observe(\AVPlayer.rate, options: [.new]) { [weak self] player, _ in
                self?.originalPlayer?.rate = player.rate
            }
            playerObservers.append(obs1)
            playerObservers.append(obs2)
        }
    }
    
    // MARK: - 视频控制接口
    /// 播放两侧视频
    public func play() {
        originalPlayer?.play()
        editedPlayer?.play()
    }
    /// 暂停两侧视频
    public func pause() {
        originalPlayer?.pause()
        editedPlayer?.pause()
    }
    /// 跳转到指定时间（秒）
    public func seek(to seconds: Double, completion: ((Bool) -> Void)? = nil) {
        guard let o = originalPlayer, let e = editedPlayer else { completion?(false); return }
        let time = CMTimeMakeWithSeconds(seconds, preferredTimescale: 600)
        let group = DispatchGroup()
        var ok1 = false, ok2 = false
        group.enter()
        o.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            ok1 = finished; group.leave()
        }
        group.enter()
        e.seek(to: time, toleranceBefore: .zero, toleranceAfter: .zero) { finished in
            ok2 = finished; group.leave()
        }
        group.notify(queue: .main) {
            completion?(ok1 && ok2)
        }
    }
    /// 播放结束回调
    public var onPlaybackEnded: (() -> Void)?
    private var playbackEndObservers: [NSObjectProtocol] = []
    private func observePlaybackEnd() {
        playbackEndObservers.forEach { NotificationCenter.default.removeObserver($0) }
        playbackEndObservers.removeAll()
        if let o = originalPlayer?.currentItem, let e = editedPlayer?.currentItem {
            let obs1 = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: o, queue: .main) { [weak self] _ in
                self?.onPlaybackEnded?()
                self?.autoReplay()
            }
            let obs2 = NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: e, queue: .main) { [weak self] _ in
                self?.onPlaybackEnded?()
                self?.autoReplay()
            }
            playbackEndObservers.append(obs1)
            playbackEndObservers.append(obs2)
        }
    }
    private func autoReplay() {
        guard let o = originalPlayer, let e = editedPlayer else { return }
        o.seek(to: .zero) { _ in o.play() }
        e.seek(to: .zero) { _ in e.play() }
    }
    private func removePlaybackEndObservers() {
        playbackEndObservers.forEach { NotificationCenter.default.removeObserver($0) }
        playbackEndObservers.removeAll()
    }
    
    // MARK: - 公共接口
    /// 重置滑块到中间
    public func resetSliderPosition() {
        animateSliderPosition(to: 0.5)
    }
    
    private func reloadSliderView() {
        if let provider = sliderProvider {
            let custom = provider.sliderView(for: self)
            customSliderView = custom
        } else {
            customSliderView = nil
        }
    }
    
    /// 设置对比内容（自动识别图片或视频）
    public func setContent(original: Any, edited: Any) {
        if let o = original as? UIImage, let e = edited as? UIImage {
            setImages(original: o, edited: e)
        } else if let o = original as? AVPlayerItem, let e = edited as? AVPlayerItem {
            setVideos(originalItem: o, editedItem: e)
        } else {
            assertionFailure("不支持的类型，需 UIImage 或 AVPlayerItem")
        }
    }
}

public protocol EffectPreviewSliderProvider: AnyObject {
    func sliderView(for previewView: EffectPreviewView) -> UIView
} 
