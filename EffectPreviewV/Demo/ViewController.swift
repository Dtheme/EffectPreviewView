//
//  ViewController.swift
//  EffectPreviewView
//
//  Created by dzw on 2025/5/21.
//

import UIKit
import AVFoundation
import SnapKit

/// 自定义视频滑块视图 - 带有渐变背景和动画效果
class CustomVideoSliderView: UIView {
    
    private let direction: EffectPreviewDirection
    private let sliderWidth: CGFloat = 36
    private var gradientLayer: CAGradientLayer!
    private var pulseLayer: CAShapeLayer!
    private var iconImageView: UIImageView!
    
    init(direction: EffectPreviewDirection) {
        self.direction = direction
        super.init(frame: .zero)
        setupCustomUI()
    }
    
    required init?(coder: NSCoder) {
        self.direction = .horizontal
        super.init(coder: coder)
        setupCustomUI()
    }
    
    private func setupCustomUI() {
        backgroundColor = .clear
        layer.cornerRadius = sliderWidth / 2
        
        // 创建渐变背景
        gradientLayer = CAGradientLayer()
        gradientLayer.colors = [
            UIColor(red: 1.0, green: 0.3, blue: 0.3, alpha: 0.9).cgColor,  // 红色
            UIColor(red: 1.0, green: 0.6, blue: 0.2, alpha: 0.9).cgColor   // 橙色
        ]
        gradientLayer.startPoint = CGPoint(x: 0, y: 0)
        gradientLayer.endPoint = CGPoint(x: 1, y: 1)
        gradientLayer.cornerRadius = sliderWidth / 2
        layer.addSublayer(gradientLayer)
        
        // 创建脉冲动画层
        pulseLayer = CAShapeLayer()
        pulseLayer.fillColor = UIColor.white.withAlphaComponent(0.3).cgColor
        pulseLayer.strokeColor = UIColor.white.cgColor
        pulseLayer.lineWidth = 2
        layer.addSublayer(pulseLayer)
        
        // 创建图标
        iconImageView = UIImageView()
        iconImageView.contentMode = .scaleAspectFit
        iconImageView.tintColor = .white
        iconImageView.image = createVideoIcon()
        addSubview(iconImageView)
        
        // 添加阴影
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 3)
        layer.shadowRadius = 6
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        updateLayout()
        startPulseAnimation()
    }
    
    private func updateLayout() {
        // 更新渐变层
        gradientLayer.frame = bounds
        
        // 更新脉冲层
        let pulseRadius = min(bounds.width, bounds.height) / 2 - 2
        let pulsePath = UIBezierPath(
            arcCenter: CGPoint(x: bounds.midX, y: bounds.midY),
            radius: pulseRadius,
            startAngle: 0,
            endAngle: .pi * 2,
            clockwise: true
        )
        pulseLayer.path = pulsePath.cgPath
        pulseLayer.frame = bounds
        
        // 更新图标位置
        let iconSize: CGFloat = 18
        iconImageView.frame = CGRect(
            x: (bounds.width - iconSize) / 2,
            y: (bounds.height - iconSize) / 2,
            width: iconSize,
            height: iconSize
        )
    }
    
    private func createVideoIcon() -> UIImage? {
        let size = CGSize(width: 18, height: 18)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        return renderer.image { context in
            let rect = CGRect(origin: .zero, size: size)
            
            // 绘制播放按钮三角形
            let path = UIBezierPath()
            path.move(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.2))
            path.addLine(to: CGPoint(x: rect.width * 0.8, y: rect.height * 0.5))
            path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.8))
            path.close()
            
            UIColor.white.setFill()
            path.fill()
        }
    }
    
    private func startPulseAnimation() {
        // 移除旧动画
        pulseLayer.removeAllAnimations()
        
        // 创建脉冲动画
        let scaleAnimation = CABasicAnimation(keyPath: "transform.scale")
        scaleAnimation.fromValue = 1.0
        scaleAnimation.toValue = 1.2
        scaleAnimation.duration = 1.5
        scaleAnimation.repeatCount = .infinity
        scaleAnimation.autoreverses = true
        scaleAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        let opacityAnimation = CABasicAnimation(keyPath: "opacity")
        opacityAnimation.fromValue = 0.3
        opacityAnimation.toValue = 0.1
        opacityAnimation.duration = 1.5
        opacityAnimation.repeatCount = .infinity
        opacityAnimation.autoreverses = true
        opacityAnimation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        
        pulseLayer.add(scaleAnimation, forKey: "pulse_scale")
        pulseLayer.add(opacityAnimation, forKey: "pulse_opacity")
    }
    
    /// 更新滑块方向（如果需要）
    func updateDirection(_ newDirection: EffectPreviewDirection) {
        // 自定义滑块可以根据方向调整样式
        if newDirection != direction {
            // 可以在这里添加方向特定的样式调整
            setNeedsLayout()
        }
    }
}

class ViewController: UIViewController {
    
    // MARK: - 属性
    private var imagePreview: EffectPreviewView!
    private var videoPreview: EffectPreviewView!
    private var imageDirectionButton: UIButton!
    private var videoDirectionButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor(red: 47/255.0, green: 163/255.0, blue: 77/255.0, alpha: 1.000)
        setupImagePreview()
        setupVideoPreview()
    }
    
    // MARK: - 图片预览设置
    private func setupImagePreview() {
        // 图片对比视图
        imagePreview = EffectPreviewView(direction: .horizontal, defaultPosition: 0.5)
        imagePreview.backgroundColor = UIColor(red: 255/255.0, green: 217/255.0, blue: 73/255.0, alpha: 1.000)
        imagePreview.layer.cornerRadius = 12
        imagePreview.layer.masksToBounds = true
        // 添加轻微阴影效果
        imagePreview.layer.shadowColor = UIColor.black.cgColor
        imagePreview.layer.shadowOpacity = 0.08
        imagePreview.layer.shadowOffset = CGSize(width: 0, height: 2)
        imagePreview.layer.shadowRadius = 8
        imagePreview.layer.masksToBounds = false
        view.addSubview(imagePreview)
        
        // 图片对比标题和按钮容器
        let imageHeaderView = UIView()
        view.addSubview(imageHeaderView)
        
        // 图片对比标题
        let imageLabel = UILabel()
        imageLabel.text = "图片对比"
        imageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        imageLabel.textColor = UIColor.black
        imageLabel.textAlignment = .center
        imageHeaderView.addSubview(imageLabel)
        
        // 图片方向切换按钮
        imageDirectionButton = UIButton(type: .system)
        imageDirectionButton.setTitle("水平", for: .normal)
        imageDirectionButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        imageDirectionButton.setTitleColor(UIColor.black, for: .normal)
        imageDirectionButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        imageDirectionButton.layer.cornerRadius = 8
        imageDirectionButton.layer.borderWidth = 1
        imageDirectionButton.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
        // 添加按钮阴影
        imageDirectionButton.layer.shadowColor = UIColor.black.cgColor
        imageDirectionButton.layer.shadowOpacity = 0.05
        imageDirectionButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        imageDirectionButton.layer.shadowRadius = 2
        imageDirectionButton.addTarget(self, action: #selector(toggleImageDirection), for: .touchUpInside)
        imageHeaderView.addSubview(imageDirectionButton)
        
        // SnapKit 约束设置
        imagePreview.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(44)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-44)
            make.top.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(view).multipliedBy(0.4)
        }
        
        imageHeaderView.snp.makeConstraints { make in
            make.top.equalTo(imagePreview.snp.bottom).offset(4)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(32)
        }
        
        imageLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        imageDirectionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(80)
            make.height.equalTo(28)
        }
        
        // 设置图片内容
        if let before = UIImage(named: "before"), let after = UIImage(named: "after") {
            imagePreview.setImages(original: before, edited: after)
        }
        
        // 滑动回调
        imagePreview.onSliderChanged = { position in
            print("图片滑块位置: \(position)")
        }
    }
    
    // MARK: - 视频预览设置
    private func setupVideoPreview() {
        // 视频对比视图
        videoPreview = EffectPreviewView(direction: .horizontal, defaultPosition: 0.5)
        videoPreview.backgroundColor = UIColor(red: 232/255.0, green: 69/255.0, blue: 54/255.0, alpha: 1.000)
        videoPreview.layer.cornerRadius = 12
        videoPreview.layer.masksToBounds = true
        // 添加轻微阴影效果
        videoPreview.layer.shadowColor = UIColor.black.cgColor
        videoPreview.layer.shadowOpacity = 0.08
        videoPreview.layer.shadowOffset = CGSize(width: 0, height: 2)
        videoPreview.layer.shadowRadius = 8
        videoPreview.layer.masksToBounds = false
        view.addSubview(videoPreview)
        
        // 视频对比标题和按钮容器
        let videoHeaderView = UIView()
        view.addSubview(videoHeaderView)
        
        // 视频对比标题
        let videoLabel = UILabel()
        videoLabel.text = "视频对比"
        videoLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        videoLabel.textColor = UIColor.black
        videoLabel.textAlignment = .center
        videoHeaderView.addSubview(videoLabel)
        
        // 视频方向切换按钮
        videoDirectionButton = UIButton(type: .system)
        videoDirectionButton.setTitle("水平", for: .normal)
        videoDirectionButton.titleLabel?.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        videoDirectionButton.setTitleColor(UIColor.black, for: .normal)
        videoDirectionButton.backgroundColor = UIColor.white.withAlphaComponent(0.9)
        videoDirectionButton.layer.cornerRadius = 8
        videoDirectionButton.layer.borderWidth = 1
        videoDirectionButton.layer.borderColor = UIColor.black.withAlphaComponent(0.1).cgColor
        // 添加按钮阴影
        videoDirectionButton.layer.shadowColor = UIColor.black.cgColor
        videoDirectionButton.layer.shadowOpacity = 0.05
        videoDirectionButton.layer.shadowOffset = CGSize(width: 0, height: 1)
        videoDirectionButton.layer.shadowRadius = 2
        videoDirectionButton.addTarget(self, action: #selector(toggleVideoDirection), for: .touchUpInside)
        videoHeaderView.addSubview(videoDirectionButton)
        
        // SnapKit 约束设置
        videoPreview.snp.makeConstraints { make in
            make.leading.equalTo(view.safeAreaLayoutGuide).offset(44)
            make.trailing.equalTo(view.safeAreaLayoutGuide).offset(-44)
            make.top.equalTo(imagePreview.snp.bottom).offset(48)
            make.height.equalTo(view).multipliedBy(0.4)
        }
        
        videoHeaderView.snp.makeConstraints { make in
            make.top.equalTo(videoPreview.snp.bottom).offset(4)
            make.leading.trailing.equalTo(view.safeAreaLayoutGuide)
            make.height.equalTo(32)
        }
        
        videoLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
        
        videoDirectionButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-16)
            make.centerY.equalToSuperview()
            make.width.equalTo(80)
            make.height.equalTo(28)
        }
        
        // 设置视频内容
        if let beforeUrl = Bundle.main.url(forResource: "before_mov", withExtension: "mp4"),
           let afterUrl = Bundle.main.url(forResource: "after_mov", withExtension: "mp4") {
            let beforeItem = AVPlayerItem(url: beforeUrl)
            let afterItem = AVPlayerItem(url: afterUrl)
            videoPreview.setVideos(originalItem: beforeItem, editedItem: afterItem)
            videoPreview.play()
        }
        
        // 🎨 设置简洁优雅的自定义滑块视图（仅用于视频演示）
        let customSlider = SimpleSliderView(direction: videoPreview.direction)
        videoPreview.setCustomSliderView(customSlider)
        
        // 滑动回调
        videoPreview.onSliderChanged = { position in
            print("视频滑块位置: \(position)")
        }
    }
    
    // MARK: - 按钮事件
    @objc private func toggleImageDirection() {
        let newDirection: EffectPreviewDirection = imagePreview.direction == .horizontal ? .vertical : .horizontal
        
        // 添加按钮点击反馈
        addButtonFeedback(to: imageDirectionButton)
        
        // 使用组件的智能切换方法，带有平滑过渡
        addSmoothTransition(to: imagePreview) {
            self.imagePreview.switchDirection(to: newDirection, animated: true)
        }
        
        // 更新按钮标题
        let buttonTitle = newDirection == .horizontal ? "水平" : "垂直"
        imageDirectionButton.setTitle(buttonTitle, for: .normal)
        
        print("图片预览方向切换为: \(newDirection == .horizontal ? "水平" : "垂直")")
    }
    
    @objc private func toggleVideoDirection() {
        let newDirection: EffectPreviewDirection = videoPreview.direction == .horizontal ? .vertical : .horizontal
        
        // 添加按钮点击反馈
        addButtonFeedback(to: videoDirectionButton)
        
        // 使用组件的智能切换方法，带有平滑过渡
        addSmoothTransition(to: videoPreview) {
            self.videoPreview.switchDirection(to: newDirection, animated: true)
            // 注意：自定义滑块的方向更新已由 EffectPreviewView 内部自动处理
        }
        
        // 更新按钮标题
        let buttonTitle = newDirection == .horizontal ? "水平" : "垂直"
        videoDirectionButton.setTitle(buttonTitle, for: .normal)
        
        print("视频预览方向切换为: \(newDirection == .horizontal ? "水平" : "垂直")")
    }
    
    // MARK: - 辅助方法
    /// 添加平滑的视觉过渡效果
    private func addSmoothTransition(to view: UIView, completion: @escaping () -> Void) {
        // 更轻微的视觉反馈，配合组件内部的优化
        UIView.animate(withDuration: 0.1, animations: {
            view.transform = CGAffineTransform(scaleX: 0.99, y: 0.99)
        }) { _ in
            // 执行切换
            completion()
            
            // 快速恢复到正常状态
            UIView.animate(withDuration: 0.15, delay: 0.05, options: [.curveEaseOut], animations: {
                view.transform = CGAffineTransform.identity
            }, completion: nil)
        }
    }
    
    /// 添加按钮点击反馈效果
    private func addButtonFeedback(to button: UIButton) {
        UIView.animate(withDuration: 0.1, animations: {
            button.transform = CGAffineTransform(scaleX: 0.95, y: 0.95)
            button.alpha = 0.8
        }) { _ in
            UIView.animate(withDuration: 0.1, animations: {
                button.transform = CGAffineTransform.identity
                button.alpha = 1.0
            })
        }
    }
}

