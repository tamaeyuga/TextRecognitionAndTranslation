//
//  ViewController.swift
//  TextRecognitionAndTranslation
//
//  Created by 玉栄友雅 on 2020/08/04.
//  Copyright © 2020 Yuga Tamae. All rights reserved.
//

import UIKit
import Vision
import VisionKit
import AVFoundation

class ViewController: UIViewController, VNDocumentCameraViewControllerDelegate {
    
    @IBOutlet var imageView: UIImageView!
    @IBOutlet var recognizedTextView: UITextView!
    @IBOutlet var translatedTextView: UITextView!
    
    //文字認識のリクエスト初期化
    var textRecognitionRequest = VNRecognizeTextRequest(completionHandler: nil);
    // 文字認識処理のキュー
    let textRecognitionWorkQueue = DispatchQueue(label: "TextRecognitionQueue", qos: .userInitiated, attributes: [], autoreleaseFrequency: .workItem)
    // 日本語に翻訳する
    var targetCode = "ja"
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        recognizedTextView.isEditable = false
        translatedTextView.isEditable = false
        setupVision()
    }
    
    // カメラ起動のボタンをタップした後の処理
    @IBAction func cameraButton(_ sender: Any) {
        let scannerViewController = VNDocumentCameraViewController()
        scannerViewController.delegate = self
        present(scannerViewController, animated: true)
    }
    
    // 翻訳ボタンをタップした後の処理
    @IBAction func translateButton(_ sender: Any) {
        guard !recognizedTextView.text.isEmpty else {
            return
        }
        translateText(detectedText: recognizedTextView.text)
    }
    
    // 文字認識の設定
    private func setupVision() {
            textRecognitionRequest = VNRecognizeTextRequest { (request, error) in
                guard let observations = request.results as? [VNRecognizedTextObservation] else { return }
                
                var detectedText = ""
                for observation in observations {
                    guard let topCandidate = observation.topCandidates(1).first else { return }
                    print("文章 \(topCandidate.string) の精度は \(topCandidate.confidence)")
        
                    detectedText += topCandidate.string
                    detectedText += "\n"
                }
                
                DispatchQueue.main.async {
                    self.recognizedTextView.text = detectedText
                    self.recognizedTextView.flashScrollIndicators()
                    
                    // 英語をスピーチさせる
                    let utterWords = AVSpeechUtterance(string: self.recognizedTextView.text)
                    utterWords.voice = AVSpeechSynthesisVoice(language: "en-US")
                    let synthesizer = AVSpeechSynthesizer()
                    synthesizer.speak(utterWords)
                }
            }
            
            textRecognitionRequest.recognitionLevel = .accurate
            textRecognitionRequest.recognitionLanguages = ["en_US"]
            textRecognitionRequest.usesLanguageCorrection = true
            
    }
    
    // 画像をimageViewに表示して、文字認識
    private func processImage(_ image: UIImage) {
        imageView.image = image
        recognizeTextInImage(image)
    }
    
    // OCR
    private func recognizeTextInImage(_ image: UIImage) {
        guard let cgImage = image.cgImage else { return }
        
        recognizedTextView.text = ""
        textRecognitionWorkQueue.async {
            let requestHandler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try requestHandler.perform([self.textRecognitionRequest])
            } catch {
                print(error)
            }
        }
    }
    
    // スキャンに成功した時
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        guard scan.pageCount >= 1 else {
            controller.dismiss(animated: true)
            return
        }
        
        let originalImage = scan.imageOfPage(at: 0)
        let newImage = compressedImage(originalImage)
        controller.dismiss(animated: true)
        
        processImage(newImage)
    }
    
    // スキャンに失敗した時
    func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        print(error)
        controller.dismiss(animated: true)
    }
    
    // キャンセルした時
    func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        controller.dismiss(animated: true)
    }
    
    // jpeg画像に圧縮
    func compressedImage(_ originalImage: UIImage) -> UIImage {
        guard let imageData = originalImage.jpegData(compressionQuality: 1),
            let reloadedImage = UIImage(data: imageData) else {
                return originalImage
        }
        return reloadedImage
    }
    
    // 翻訳
    func translateText(detectedText: String) {
        
        guard !detectedText.isEmpty else {
            return
        }
        
        let task = try? GoogleTranslate.sharedInstance.translateTextTask(text: detectedText, targetLanguage: self.targetCode, completionHandler: { (translatedText: String?, error: Error?) in
            debugPrint(error?.localizedDescription as Any)
            
            DispatchQueue.main.async {
                self.translatedTextView.text = translatedText
            }
            
        })
        task?.resume()
    }
    
}

