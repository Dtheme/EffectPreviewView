//
//  SimpleSliderView.swift
//  EffectPreviewView
//
//  Created by dzw on 2025/8/16.
//

import UIKit

/// 简洁优雅的滑块视图 - 5px高斯圆角矩形设计
public class SimpleSliderView: UIView {
    
    private var direction: EffectPreviewDirection
    private let sliderWidth: CGFloat = 28
    
    public init(direction: EffectPreviewDirection) {
        self.direction = direction
        super.init(frame: .zero)
        setupUI()
    }
    
    required init?(coder: NSCoder) {
        self.direction = .horizontal
        super.init(coder: coder)
        setupUI()
    }
    
    private func setupUI() {
        backgroundColor = .clear
        isUserInteractionEnabled = true // 确保可以接收触摸事件
        drawSimpleSlider()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        // 清除旧内容并重新绘制
        layer.sublayers?.removeAll()
        drawSimpleSlider()
    }
    
    /// 更新滑块方向
    public func updateDirection(_ newDirection: EffectPreviewDirection) {
        guard direction != newDirection else { return }
        direction = newDirection
        // 重新绘制以适应新方向
        setNeedsLayout()
    }
    
    private func drawSimpleSlider() {
        // 创建简洁的圆角矩形滑块
        let sliderLayer = CALayer()
        
        switch direction {
        case .horizontal:
            // 水平方向：垂直的圆角矩形
            let sliderHeight: CGFloat = min(bounds.height * 0.6, 80) // 最大80pt
            let sliderRect = CGRect(
                x: (bounds.width - 5) / 2,
                y: (bounds.height - sliderHeight) / 2,
                width: 5,
                height: sliderHeight
            )
            sliderLayer.frame = sliderRect
            
        case .vertical:
            // 垂直方向：水平的圆角矩形
            let sliderWidth: CGFloat = min(bounds.width * 0.6, 80) // 最大80pt
            let sliderRect = CGRect(
                x: (bounds.width - sliderWidth) / 2,
                y: (bounds.height - 5) / 2,
                width: sliderWidth,
                height: 5
            )
            sliderLayer.frame = sliderRect
        }
        
        // 设置圆角矩形样式
        sliderLayer.backgroundColor = UIColor.white.cgColor
        sliderLayer.cornerRadius = 2.5 // 5px高度的一半，形成完美圆角
        
        // 添加高斯模糊阴影效果
        sliderLayer.shadowColor = UIColor.black.cgColor
        sliderLayer.shadowOpacity = 0.25
        sliderLayer.shadowOffset = CGSize(width: 0, height: 2)
        sliderLayer.shadowRadius = 4
        sliderLayer.shadowPath = UIBezierPath(roundedRect: sliderLayer.bounds, cornerRadius: sliderLayer.cornerRadius).cgPath
        
        // 添加到视图
        layer.addSublayer(sliderLayer)
    }
}
