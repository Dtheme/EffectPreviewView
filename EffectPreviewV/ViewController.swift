//
//  ViewController.swift
//  EffectPreviewView
//
//  Created by dzw on 2025/5/21.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        // 上半部分：图片对比
        let imagePreview = EffectPreviewView()
        imagePreview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(imagePreview)
        NSLayoutConstraint.activate([
            imagePreview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imagePreview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imagePreview.topAnchor.constraint(equalTo: view.topAnchor),
            imagePreview.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45)
        ])
        if let before = UIImage(named: "before"), let after = UIImage(named: "after") {
            imagePreview.setContent(original: before, edited: after)
        }
        // 图片对比标题
        let imageLabel = UILabel()
        imageLabel.translatesAutoresizingMaskIntoConstraints = false
        imageLabel.text = "图片对比"
        imageLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        imageLabel.textAlignment = .center
        view.addSubview(imageLabel)
        NSLayoutConstraint.activate([
            imageLabel.topAnchor.constraint(equalTo: imagePreview.bottomAnchor, constant: 4),
            imageLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            imageLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            imageLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        // 下半部分：视频对比
        let videoPreview = EffectPreviewView()
        videoPreview.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(videoPreview)
        NSLayoutConstraint.activate([
            videoPreview.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoPreview.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoPreview.topAnchor.constraint(equalTo: imageLabel.bottomAnchor, constant: 8),
            videoPreview.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: 0.45)
        ])
        if let beforeUrl = Bundle.main.url(forResource: "before_mov", withExtension: "mp4"),
           let afterUrl = Bundle.main.url(forResource: "after_mov", withExtension: "mp4") {
            let beforeItem = AVPlayerItem(url: beforeUrl)
            let afterItem = AVPlayerItem(url: afterUrl)
            videoPreview.setContent(original: beforeItem, edited: afterItem)
            videoPreview.play()
        }
        // 视频对比标题
        let videoLabel = UILabel()
        videoLabel.translatesAutoresizingMaskIntoConstraints = false
        videoLabel.text = "视频对比"
        videoLabel.font = UIFont.systemFont(ofSize: 16, weight: .medium)
        videoLabel.textAlignment = .center
        view.addSubview(videoLabel)
        NSLayoutConstraint.activate([
            videoLabel.topAnchor.constraint(equalTo: videoPreview.bottomAnchor, constant: 4),
            videoLabel.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            videoLabel.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            videoLabel.heightAnchor.constraint(equalToConstant: 24)
        ])
        // 滑动回调示例
        imagePreview.onSliderChanged = { position in
            print("图片滑块位置: \(position)")
        }
        videoPreview.onSliderChanged = { position in
            print("视频滑块位置: \(position)")
        }
    }


}

