//
//  DefaultSliderView.swift
//  EffectPreviewView
//
//  Created by dzw on 2025/5/21.
//

import UIKit
import AVFoundation

/// 滑动方向枚举
public enum EffectPreviewDirection {
    case horizontal  // 水平滑动（默认）
    case vertical    // 垂直滑动
}



/// 支持图片/视频前后对比滑动的视图组件
public class EffectPreviewView: UIView {
    // MARK: - 子视图
    private let originalImageView = UIImageView()
    private let editedImageView = UIImageView()
    private var originalPlayerLayer: AVPlayerLayer?
    private var editedPlayerLayer: AVPlayerLayer?
    private let maskLayer = CALayer()
    private var sliderView: UIView!
    private var customSliderView: UIView?
    private let sliderWidth: CGFloat = 28
    private let sliderInnerLineWidth: CGFloat = 3
    private let sliderInnerLineColor: UIColor = UIColor(white: 0.7, alpha: 0.7)
    private let sliderHighlightColor: UIColor = UIColor.white.withAlphaComponent(0.8)
    private let sliderGradientStart: UIColor = UIColor.white.withAlphaComponent(0.95)
    private let sliderGradientEnd: UIColor = UIColor.white.withAlphaComponent(0.6)
    private let originalVideoContainerView = UIView()
    private let editedVideoContainerView = UIView()
    
    // MARK: - 配置属性
    /// 滑动方向（默认为水平）
    public var direction: EffectPreviewDirection = .horizontal {
        didSet {
            if direction != oldValue {
                handleDirectionChange(from: oldValue, to: direction)
            }
        }
    }
    
    /// 默认滑块位置（0~1，默认0.5居中）
    /// 水平方向：0为最左，1为最右
    /// 垂直方向：0为最上，1为最下
    public var defaultPosition: CGFloat = 0.5 {
        didSet {
            let clamped = min(max(defaultPosition, 0), 1)
            if clamped != defaultPosition {
                defaultPosition = clamped
            }
            if sliderPosition == 0.5 || abs(sliderPosition - oldValue) < 0.01 {
                sliderPosition = defaultPosition
            }
        }
    }
    
    // MARK: - 状态
    private var isVideoMode = false
    private var originalPlayer: AVPlayer?
    private var editedPlayer: AVPlayer?
    private var playerObservers: [NSKeyValueObservation] = []
    
    /// 当前滑块位置（0~1）
    /// 水平方向：0为最左，1为最右
    /// 垂直方向：0为最上，1为最下
    public private(set) var sliderPosition: CGFloat = 0.5 {
        didSet {
            // 避免无限递归和无意义的更新
            guard sliderPosition != oldValue else { return }
            let clamped = min(max(sliderPosition, 0), 1)
            if clamped != sliderPosition {
                sliderPosition = clamped
                return
            }
            onSliderChanged?(sliderPosition)
        }
    }
    /// 是否允许交互
    public var isInteractiveEnabled: Bool = true {
        didSet { sliderView.isUserInteractionEnabled = isInteractiveEnabled }
    }
    /// 滑动回调
    public var onSliderChanged: ((CGFloat) -> Void)?
    
    /// 设置自定义滑块视图
    /// - Parameter customView: 自定义滑块视图，传入nil使用默认样式
    public func setCustomSliderView(_ customView: UIView?) {
        // 移除旧的自定义视图
        customSliderView?.removeFromSuperview()
        customSliderView = customView
        
        if let custom = customView {
            // 使用自定义滑块视图
            sliderView.isHidden = true
            custom.frame = sliderView.frame
            custom.isUserInteractionEnabled = isInteractiveEnabled
            
            // 为自定义滑块添加手势识别器
            let customPan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
            custom.addGestureRecognizer(customPan)
            
            addSubview(custom)
            customSliderView = custom
        } else {
            // 使用默认滑块视图
            sliderView.isHidden = false
            customSliderView = nil
        }
        
        setNeedsLayout()
    }
    
    /// 自定义滑块视图提供者
    public weak var sliderProvider: EffectPreviewSliderProvider? {
        didSet { reloadSliderView() }
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
        sliderPosition = defaultPosition
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupUI()
        sliderPosition = defaultPosition
    }
    
    deinit {
        // 清理所有观察者和资源
        cleanupResources()
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
        
        // 使用默认滑块视图
        sliderView = DefaultSliderView(direction: direction)
        addSubview(sliderView)
        // 手势
        let pan = UIPanGestureRecognizer(target: self, action: #selector(handlePan(_:)))
        sliderView.addGestureRecognizer(pan)
        sliderView.isUserInteractionEnabled = isInteractiveEnabled
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
        
        // 更新默认滑块视图的方向
        if let defaultSlider = sliderView as? DefaultSliderView {
            defaultSlider.updateDirection(direction)
        }
    }
    

    
    // MARK: - 公开方法
    
    /// 设置滑块位置（带动画）
    /// - Parameters:
    ///   - position: 滑块位置 (0~1)
    ///   - animated: 是否使用动画
    public func setSliderPosition(_ position: CGFloat, animated: Bool = true) {
        let clamped = min(max(position, 0), 1)
        if animated {
            animateSliderPosition(to: clamped)
        } else {
            sliderPosition = clamped
            updateMaskAndSlider()
        }
    }
    
    /// 平滑切换方向并智能映射滑块位置
    /// - Parameter newDirection: 新的滑动方向
    public func switchDirection(to newDirection: EffectPreviewDirection, animated: Bool = true) {
        guard direction != newDirection else { return }
        
        let currentPos = sliderPosition
        
        if animated {
            // 使用智能位置映射，但延迟到方向切换动画完成后
            let mappedPosition = intelligentPositionMapping(currentPos)
            
            // 先设置方向（会触发平滑的方向切换动画）
            direction = newDirection
            
            // 延迟设置位置，等待方向切换动画完成
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                self.setSliderPosition(mappedPosition, animated: true)
            }
        } else {
            direction = newDirection
            let mappedPosition = intelligentPositionMapping(currentPos)
            setSliderPosition(mappedPosition, animated: false)
        }
    }
    
    /// 智能位置映射，让方向切换更自然
    private func intelligentPositionMapping(_ currentPosition: CGFloat) -> CGFloat {
        // 如果接近中心，保持中心
        if abs(currentPosition - 0.5) < 0.1 {
            return 0.5
        }
        
        // 如果接近边缘，映射到对应的边缘区域
        if currentPosition < 0.3 {
            return 0.25  // 映射到1/4位置
        } else if currentPosition > 0.7 {
            return 0.75  // 映射到3/4位置
        }
        
        // 其他情况保持原位置
        return currentPosition
    }
    
    /// 便利初始化方法
    /// - Parameters:
    ///   - direction: 滑动方向
    ///   - defaultPosition: 默认位置 (0~1)
    public convenience init(direction: EffectPreviewDirection = .horizontal, defaultPosition: CGFloat = 0.5) {
        self.init(frame: .zero)
        self.direction = direction
        self.defaultPosition = defaultPosition
        self.sliderPosition = defaultPosition
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
        // 添加错误处理观察者
        setupVideoErrorHandling(for: originalItem, isOriginal: true)
        setupVideoErrorHandling(for: editedItem, isOriginal: false)
        
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
        
        // 边界保护：避免除零错误
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let location = gesture.location(in: self)
        let percent: CGFloat
        
        switch direction {
        case .horizontal:
            percent = min(max(location.x / bounds.width, 0), 1)
        case .vertical:
            percent = min(max(location.y / bounds.height, 0), 1)
        }
        
        sliderPosition = percent
        updateMaskAndSlider()
    }
    
    private var maskShapeLayer: CAShapeLayer? // 用于复用
    
    private func updateMaskAndSlider() {
        // 边界保护：避免无效的bounds
        guard bounds.width > 0 && bounds.height > 0 else { return }
        
        let maskPath: UIBezierPath
        let sliderFrame: CGRect
        
        switch direction {
        case .horizontal:
            let sliderX = bounds.width * sliderPosition
            let maskWidth = max(0, bounds.width - sliderX)  // 确保宽度不为负
            maskPath = UIBezierPath(rect: CGRect(x: sliderX, y: 0, width: maskWidth, height: bounds.height))
            
            // 允许滑块完全贴边，不限制中心点位置
            sliderFrame = CGRect(x: sliderX - sliderWidth/2, y: 0, width: sliderWidth, height: bounds.height)
            
        case .vertical:
            let sliderY = bounds.height * sliderPosition
            let maskHeight = max(0, bounds.height - sliderY)  // 确保高度不为负
            maskPath = UIBezierPath(rect: CGRect(x: 0, y: sliderY, width: bounds.width, height: maskHeight))
            
            // 允许滑块完全贴边，不限制中心点位置
            sliderFrame = CGRect(x: 0, y: sliderY - sliderWidth/2, width: bounds.width, height: sliderWidth)
        }
        
        if isVideoMode {
            // 视频模式：editedVideoContainerView 设置 mask
            let maskShape: CAShapeLayer
            if let existing = maskShapeLayer {
                maskShape = existing
            } else {
                maskShape = CAShapeLayer()
                maskShapeLayer = maskShape
            }
            maskShape.path = maskPath.cgPath
            maskShape.frame = bounds
            editedVideoContainerView.layer.mask = maskShape
            
            // 在原图侧添加阴影效果
            addDividerShadow(to: originalVideoContainerView, sliderPosition: sliderPosition)
        } else {
            // 图片模式：editedImageView 设置 mask
            let maskShape: CAShapeLayer
            if let existing = maskShapeLayer {
                maskShape = existing
            } else {
                maskShape = CAShapeLayer()
                maskShapeLayer = maskShape
            }
            maskShape.path = maskPath.cgPath
            maskShape.frame = bounds
            editedImageView.layer.mask = maskShape
            
            // 在原图侧添加阴影效果
            addDividerShadow(to: originalImageView, sliderPosition: sliderPosition)
        }
        sliderView.frame = sliderFrame
        if let custom = customSliderView {
            custom.frame = sliderView.frame
        }
        updateMaskEdgeStyle()
    }
    
    /// 在分割线的原图侧添加阴影效果，营造编辑图片浮在上方的视觉层次
    private func addDividerShadow(to targetView: UIView, sliderPosition: CGFloat) {
        // 移除旧的阴影层
        targetView.layer.sublayers?.removeAll(where: { $0.name == "dividerShadow" })
        
        // 只在滑块不在边缘时显示阴影
        guard sliderPosition > 0.02 && sliderPosition < 0.98 else { return }
        
        let shadowLayer = CALayer()
        shadowLayer.name = "dividerShadow"
        
        // 根据方向创建阴影
        switch direction {
        case .horizontal:
            let shadowX = bounds.width * sliderPosition
            let shadowWidth: CGFloat = 8  // 阴影宽度
            shadowLayer.frame = CGRect(x: shadowX - shadowWidth, y: 0, width: shadowWidth, height: bounds.height)
            
            // 创建渐变阴影
            let gradient = CAGradientLayer()
            gradient.frame = shadowLayer.bounds
            gradient.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.08).cgColor,
                UIColor.black.withAlphaComponent(0.15).cgColor
            ]
            gradient.locations = [0.0, 0.7, 1.0]
            gradient.startPoint = CGPoint(x: 0, y: 0.5)
            gradient.endPoint = CGPoint(x: 1, y: 0.5)
            shadowLayer.addSublayer(gradient)
            
        case .vertical:
            let shadowY = bounds.height * sliderPosition
            let shadowHeight: CGFloat = 8  // 阴影高度
            shadowLayer.frame = CGRect(x: 0, y: shadowY - shadowHeight, width: bounds.width, height: shadowHeight)
            
            // 创建渐变阴影
            let gradient = CAGradientLayer()
            gradient.frame = shadowLayer.bounds
            gradient.colors = [
                UIColor.clear.cgColor,
                UIColor.black.withAlphaComponent(0.08).cgColor,
                UIColor.black.withAlphaComponent(0.15).cgColor
            ]
            gradient.locations = [0.0, 0.7, 1.0]
            gradient.startPoint = CGPoint(x: 0.5, y: 0)
            gradient.endPoint = CGPoint(x: 0.5, y: 1)
            shadowLayer.addSublayer(gradient)
        }
        
        targetView.layer.addSublayer(shadowLayer)
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
    
    // MARK: - 方向切换处理
    private func handleDirectionChange(from oldDirection: EffectPreviewDirection, to newDirection: EffectPreviewDirection) {
        // 先隐藏滑块，避免从角落伸出的突兀效果
        let originalAlpha = sliderView.alpha
        let originalCustomAlpha = customSliderView?.alpha ?? 1.0
        
        UIView.animate(withDuration: 0.15, animations: {
            // 淡出滑块（包括自定义滑块）
            self.sliderView.alpha = 0.0
            self.customSliderView?.alpha = 0.0
        }) { _ in
            // 更新自定义滑块的方向
            if let customSlider = self.customSliderView as? SimpleSliderView {
                customSlider.updateDirection(newDirection)
            }
            
            // 在滑块隐藏后进行布局更新
            UIView.animate(withDuration: 0.2, delay: 0, options: [.curveEaseInOut], animations: {
                self.setNeedsLayout()
                self.layoutIfNeeded()
            }) { _ in
                // 布局完成后淡入滑块
                UIView.animate(withDuration: 0.15, animations: {
                    self.sliderView.alpha = originalAlpha
                    self.customSliderView?.alpha = originalCustomAlpha
                })
            }
        }
    }
    
    // MARK: - 资源清理
    private func cleanupResources() {
        // 清理播放器观察者
        playerObservers.removeAll()
        
        // 清理播放结束观察者
        removePlaybackEndObservers()
        
        // 停止并清理播放器
        originalPlayer?.pause()
        editedPlayer?.pause()
        originalPlayer = nil
        editedPlayer = nil
        
        // 清理播放器层
        originalPlayerLayer?.removeFromSuperlayer()
        editedPlayerLayer?.removeFromSuperlayer()
        originalPlayerLayer = nil
        editedPlayerLayer = nil
        
        // 清理遮罩层
        maskShapeLayer = nil
        
        // 清理自定义滑块视图
        customSliderView?.removeFromSuperview()
        customSliderView = nil
    }
    
    // MARK: - 公共接口
    /// 重置滑块到中间
    public func resetSliderPosition() {
        animateSliderPosition(to: 0.5)
    }
    
    // MARK: - 视频错误处理
    private func setupVideoErrorHandling(for playerItem: AVPlayerItem, isOriginal: Bool) {
        // 监听播放器状态
        let observer = playerItem.observe(\.status, options: [.new]) { [weak self] item, _ in
            DispatchQueue.main.async {
                switch item.status {
                case .failed:
                    self?.handleVideoError(item.error, isOriginal: isOriginal)
                case .readyToPlay:
                    // 视频准备就绪
                    break
                case .unknown:
                    // 状态未知
                    break
                @unknown default:
                    break
                }
            }
        }
        playerObservers.append(observer)
    }
    
    private func handleVideoError(_ error: Error?, isOriginal: Bool) {
        let videoType = isOriginal ? "原始视频" : "编辑后视频"
        print("⚠️ \(videoType)加载失败: \(error?.localizedDescription ?? "未知错误")")
        
        // 可以在这里添加错误回调给外部处理
        // onVideoLoadError?(error, isOriginal)
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
