//
//  DefaultSliderView.swift
//  EffectPreviewView
//
//  Created by dzw on 2025/8/16.
//

import UIKit

/// 默认的分割线滑块视图实现
public class DefaultSliderView: UIView {
    
    private let direction: EffectPreviewDirection
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
        layer.cornerRadius = sliderWidth / 2
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.18
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        drawModernSlider()
    }
    
    /// 更新滑块方向
    public func updateDirection(_ newDirection: EffectPreviewDirection) {
        if newDirection != direction {
            // 清除旧内容并重新绘制
            layer.sublayers?.removeAll(where: { $0.name == "sliderDesign" })
            subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview() } }
            drawModernSlider()
        }
    }
    
    private func drawModernSlider() {
        // 清除旧内容
        layer.sublayers?.removeAll(where: { $0.name == "sliderDesign" })
        subviews.forEach { if $0.tag == 999 { $0.removeFromSuperview() } }
        
        // 根据方向添加分割线背景
        let dividerLine = CALayer()
        dividerLine.name = "sliderDesign"
        switch direction {
        case .horizontal:
            dividerLine.frame = CGRect(x: (sliderWidth - 2) / 2, y: 0, width: 2, height: bounds.height)
        case .vertical:
            dividerLine.frame = CGRect(x: 0, y: (sliderWidth - 2) / 2, width: bounds.width, height: 2)
        }
        dividerLine.backgroundColor = UIColor.white.withAlphaComponent(0.8).cgColor
        layer.addSublayer(dividerLine)
        
        // 创建圆形滑块 - 缩小直径
        let sliderSize: CGFloat = 32  // 从36缩小到32
        let sliderFrame: CGRect
        switch direction {
        case .horizontal:
            let sliderY = (bounds.height - sliderSize) / 2
            sliderFrame = CGRect(x: (sliderWidth - sliderSize) / 2, y: sliderY, width: sliderSize, height: sliderSize)
        case .vertical:
            let sliderX = (bounds.width - sliderSize) / 2
            sliderFrame = CGRect(x: sliderX, y: (sliderWidth - sliderSize) / 2, width: sliderSize, height: sliderSize)
        }
        
        // 白色圆形背景
        let circleLayer = CALayer()
        circleLayer.name = "sliderDesign"
        circleLayer.frame = sliderFrame
        circleLayer.backgroundColor = UIColor.white.cgColor
        circleLayer.cornerRadius = sliderSize / 2
        // 添加轻微阴影
        circleLayer.shadowColor = UIColor.black.cgColor
        circleLayer.shadowOpacity = 0.12
        circleLayer.shadowOffset = CGSize(width: 0, height: 1)
        circleLayer.shadowRadius = 3
        layer.addSublayer(circleLayer)
        
        // 添加箭头指示器
        let arrowSize: CGFloat = 10  // 缩小箭头尺寸
        let arrowSpacing: CGFloat = 3  // 箭头间距
        
        switch direction {
        case .horizontal:
            // 左箭头
            let leftArrow = createArrowImageView(direction: .left, size: arrowSize)
            leftArrow.tag = 999
            leftArrow.frame = CGRect(
                x: sliderFrame.midX - arrowSpacing - arrowSize,
                y: sliderFrame.midY - arrowSize / 2,
                width: arrowSize,
                height: arrowSize
            )
            addSubview(leftArrow)
            
            // 右箭头
            let rightArrow = createArrowImageView(direction: .right, size: arrowSize)
            rightArrow.tag = 999
            rightArrow.frame = CGRect(
                x: sliderFrame.midX + arrowSpacing,
                y: sliderFrame.midY - arrowSize / 2,
                width: arrowSize,
                height: arrowSize
            )
            addSubview(rightArrow)
            
        case .vertical:
            // 上箭头
            let upArrow = createArrowImageView(direction: .up, size: arrowSize)
            upArrow.tag = 999
            upArrow.frame = CGRect(
                x: sliderFrame.midX - arrowSize / 2,
                y: sliderFrame.midY - arrowSpacing - arrowSize,
                width: arrowSize,
                height: arrowSize
            )
            addSubview(upArrow)
            
            // 下箭头
            let downArrow = createArrowImageView(direction: .down, size: arrowSize)
            downArrow.tag = 999
            downArrow.frame = CGRect(
                x: sliderFrame.midX - arrowSize / 2,
                y: sliderFrame.midY + arrowSpacing,
                width: arrowSize,
                height: arrowSize
            )
            addSubview(downArrow)
        }
    }
    
    private enum ArrowDirection {
        case left, right, up, down
    }
    
    private func createArrowImageView(direction: ArrowDirection, size: CGFloat) -> UIImageView {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: size, height: size))
        let image = renderer.image { context in
            let path = UIBezierPath()
            
            switch direction {
            case .left:
                // 左箭头 <
                path.move(to: CGPoint(x: size * 0.7, y: size * 0.2))
                path.addLine(to: CGPoint(x: size * 0.3, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.7, y: size * 0.8))
            case .right:
                // 右箭头 >
                path.move(to: CGPoint(x: size * 0.3, y: size * 0.2))
                path.addLine(to: CGPoint(x: size * 0.7, y: size * 0.5))
                path.addLine(to: CGPoint(x: size * 0.3, y: size * 0.8))
            case .up:
                // 上箭头 ^
                path.move(to: CGPoint(x: size * 0.2, y: size * 0.7))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.3))
                path.addLine(to: CGPoint(x: size * 0.8, y: size * 0.7))
            case .down:
                // 下箭头 v
                path.move(to: CGPoint(x: size * 0.2, y: size * 0.3))
                path.addLine(to: CGPoint(x: size * 0.5, y: size * 0.7))
                path.addLine(to: CGPoint(x: size * 0.8, y: size * 0.3))
            }
            
            UIColor.black.withAlphaComponent(0.6).setStroke()
            path.lineWidth = 1.5
            path.lineCapStyle = .round
            path.lineJoinStyle = .round
            path.stroke()
        }
        
        return UIImageView(image: image)
    }
}
