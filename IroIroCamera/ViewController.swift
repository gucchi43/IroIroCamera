//
//  ViewController.swift
//  IroIroCamera
//
//  Created by Hiroki Taniguchi on 2017/07/15.
//  Copyright © 2017年 Hiroki Taniguchi. All rights reserved.
//

import UIKit
import AVFoundation
import CoreImage
import StoreKit
import Spring


class ViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate, AVCaptureVideoDataOutputSampleBufferDelegate {

    @IBOutlet weak var previewView: UIView!
    @IBOutlet weak var takedPicturePreview: UIButton!
    
    let captureSession = AVCaptureSession()
    var videoLayer: AVCaptureVideoPreviewLayer?
    var videoOutput = AVCaptureVideoDataOutput()
    var markFirstView: UIView!
    var markSecondView: UIView!
    var outputImage: UIImage?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.makeMarksView()
        self.setCameraView()
        
    }
    
    func setCameraView() {
        // 入力（背景カメラ）
        let videoDevice = AVCaptureDevice.default(for: AVMediaType.video)
        let videoInput = try! AVCaptureDeviceInput.init(device: videoDevice!)
        captureSession.addInput(videoInput)
        
        // 出力 (メタデータ)
        //        let metadataOutput = AVCaptureMetadataOutput()
        //        captureSession.addOutput(metadataOutput)
        
        // QRコードを検出した際のデリゲート設定
        //        metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        //        metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeQRCode]
        
        //        videoLayer = AVCaptureVideoPreviewLayer.init(session: captureSession)
        //        videoLayer?.frame = previewView.bounds
        //        videoLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        //        previewView.layer.addSublayer(videoLayer!)
        
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as AnyHashable as! String : Int(kCVPixelFormatType_32BGRA)]
        
        //フレーム毎に呼び出すデリゲート登録
        //let queue:DispatchQueue = DispatchQueue(label:"myqueue",attribite: DISPATCH_QUEUE_SERIAL)
        let queue:DispatchQueue = DispatchQueue(label: "myqueue", attributes: .concurrent)
        videoOutput.setSampleBufferDelegate(self, queue: queue)
        videoOutput.alwaysDiscardsLateVideoFrames = true
        
        captureSession.addOutput(self.videoOutput)
        
        let videoLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        videoLayer.frame = self.view.bounds
        videoLayer.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        previewView.layer.addSublayer(videoLayer)
        
        //カメラ向き
        for connection in self.videoOutput.connections {
            if let conn = connection as? AVCaptureConnection {
                if conn.isVideoOrientationSupported {
                    conn.videoOrientation = AVCaptureVideoOrientation.portrait
                }
            }
        }
        
        self.captureSession.startRunning()
        
        //        // セッションの開始
        //        DispatchQueue.global(qos: .userInitiated).async {
        //
        //            self.captureSession.startRunning()
        //        }
    }
    
    func makeMarksView () {
        // MARKコードをマークするビュー
        markFirstView = UIView()
        markFirstView.layer.borderWidth = 4
        markFirstView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
        markFirstView.layer.cornerRadius = markFirstView.frame.width / 2
        markFirstView.layer.borderColor = UIColor.white.cgColor
        view.addSubview(markFirstView)
    }
    
    func imageFromSampleBuffer(sampleBuffer: CMSampleBuffer) -> UIImage {
        //バッファーをUIImageに変換
        let imageBuffer: CVImageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer)!
        CVPixelBufferLockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let baseAddress = CVPixelBufferGetBaseAddressOfPlane(imageBuffer, 0)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(imageBuffer)
        let width = CVPixelBufferGetWidth(imageBuffer)
        let height = CVPixelBufferGetHeight(imageBuffer)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = (CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue)
        let context = CGContext(data: baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: bytesPerRow, space: colorSpace, bitmapInfo: bitmapInfo)
        let imageRef = context!.makeImage()
        
        CVPixelBufferUnlockBaseAddress(imageBuffer, CVPixelBufferLockFlags(rawValue: 0))
        let resultImage = UIImage(cgImage: imageRef!)

        return resultImage
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection)
    {
        //同期処理（非同期処理ではキューが溜まりすぎて画面がついていかない）
        DispatchQueue.main.sync(execute: {
            
            //バッファーをUIImageに変換
            let image = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
            self.outputImage = self.imageFromSampleBuffer(sampleBuffer: sampleBuffer)
            let ciimage:CIImage! = CIImage(image: image)
            
            let qrDctector : CIDetector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyHigh] )!
            let qrCode: NSArray = qrDctector.features(in: ciimage) as NSArray
            
            if qrCode.count != 0 {
                var rects = Array<CGRect>()
                for feature in qrCode {
                    // 座標変換
                    var qrRect : CGRect = (feature as AnyObject).bounds
                    let widthPer = (self.previewView.bounds.width/image.size.width)
                    let heightPer = (self.previewView.bounds.height/image.size.height)
                    
                    // UIKitは左上に原点があるが、CoreImageは左下に原点があるので揃える
                    qrRect.origin.y = image.size.height - qrRect.origin.y - qrRect.size.height
                    //倍率変換
                    qrRect.origin.x = qrRect.origin.x * widthPer
                    qrRect.origin.y = qrRect.origin.y * heightPer
                    qrRect.size.width = qrRect.size.width * widthPer
                    qrRect.size.height = qrRect.size.height * heightPer
                    
                    rects.append(qrRect)
                }
                let firstRect = rects[0]
                    markFirstView.layer.borderColor = UIColor.green.cgColor
                    markFirstView.frame = firstRect
            }
            
            
            //CIDetectorAccuracyHighだと高精度（使った感じは遠距離による判定の精度）だが処理が遅くなる
//            let detector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyLow] )!
            let faceDetector : CIDetector = CIDetector(ofType: CIDetectorTypeFace, context: nil, options:[CIDetectorAccuracy: CIDetectorAccuracyHigh] )!
            let faces : NSArray = faceDetector.features(in: ciimage) as NSArray
            
            if faces.count != 0
            {
                var rects = Array<CGRect>()
                var smileArray = Array<Bool>()
                var _ : CIFaceFeature = CIFaceFeature()
                for feature in faces {
                    
                    // 座標変換
                    var faceRect : CGRect = (feature as AnyObject).bounds
                    let widthPer = (self.previewView.bounds.width/image.size.width)
                    let heightPer = (self.previewView.bounds.height/image.size.height)
                    
                    // UIKitは左上に原点があるが、CoreImageは左下に原点があるので揃える
                    faceRect.origin.y = image.size.height - faceRect.origin.y - faceRect.size.height
                    //倍率変換
                    faceRect.origin.x = faceRect.origin.x * widthPer
                    faceRect.origin.y = faceRect.origin.y * heightPer
                    faceRect.size.width = faceRect.size.width * widthPer
                    faceRect.size.height = faceRect.size.height * heightPer
                    
                    rects.append(faceRect)
                    
                    var smileStatus = (feature as AnyObject).hasSmile
                    smileArray.append(smileStatus!)
                }
                let firstRect = rects[0]
                if smileArray[0] == true{
                    markFirstView.layer.borderColor = UIColor.yellow.cgColor
                    markFirstView.frame = firstRect
                }else {
                    markFirstView.layer.borderColor = UIColor.purple.cgColor
                    markFirstView.layer.borderWidth = 10.0
                    markFirstView.frame = firstRect
                }
            }
        })
    }
    
    func metadataOutput(captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        for metadata in metadataObjects as! [AVMetadataMachineReadableCodeObject] {
            if metadata.type == AVMetadataObject.ObjectType.qr {
                // 検出位置を取得
                let barCode = videoLayer?.transformedMetadataObject(for: metadata) as! AVMetadataMachineReadableCodeObject
                markFirstView!.frame = barCode.bounds
                if let qrUrl = metadata.stringValue{
                    print("qrUrl", qrUrl)
//                    showQrLinkAlert(qrLink: qrUrl)
                    makeQrCode(url: qrUrl)
                }
            } else if metadata.type == AVMetadataObject.ObjectType.face {
                print("顔認識できた")
            }
        }
    }
    
    @IBAction func takePicture(_ sender: Any) {
        print("tap takePicture!!")

        
        takeStillPicture()
    }
    
    func takeStillPicture(){
        if var _:AVCaptureConnection = videoOutput.connection(with: AVMediaType.video){
            
            //顔認証のmarkFirstImageを追加する
            UIGraphicsBeginImageContextWithOptions(previewView.frame.size, false, 0.0)
            
            self.outputImage?.draw(in: previewView.frame)
            let markFirstImage = markFirstView.toImage()
            markFirstImage?.draw(in: markFirstView.frame)
            
            let newImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            
            if newImage != nil {
                UIImageWriteToSavedPhotosAlbum(newImage!, self, nil, nil)
                setTakedPicturePreview(takedImage: newImage!)
            }else {
                UIImageWriteToSavedPhotosAlbum(outputImage!, self, nil, nil)
                setTakedPicturePreview(takedImage: outputImage!)
            }
            
        }
    }
    
    func setTakedPicturePreview(takedImage: UIImage) {
//        takedPicturePreview.setImage(takedImage, for: UIControlState.normal)
        takedPicturePreview.setBackgroundImage(takedImage, for: UIControlState.normal)
    }
    
    func showQrLinkAlert(qrLink: String) {
        let alert = UIAlertController(
            title: "QRコードを読み取ったよん💝",
            message: qrLink,
            preferredStyle: .alert)
        let updateAction = UIAlertAction(title: "飛ぶ", style: .default) {
            action in
            UIApplication.shared.open(URL(string: qrLink)!)
        }
        alert.addAction(updateAction)
        alert.addAction(UIAlertAction(title: "飛ばない", style: .destructive))
        self.present(alert, animated: true, completion: nil)
    }
    
    func makeQrCode(url: String) {
        // NSString から NSDataへ変換
        let data = url.data(using: String.Encoding.utf8)!
        
        // QRコード生成のフィルター
        // NSData型でデーターを用意
        // inputCorrectionLevelは、誤り訂正レベル
        let qr = CIFilter(name: "CIQRCodeGenerator", withInputParameters: ["inputMessage": data, "inputCorrectionLevel": "H"])!
        
//        let sizeTransform = CGAffineTransformMakeScale(10, 10)
//        let qrImage = qr.outputImage!.imageByApplyingTransform(sizeTransform)
        let qrImage = qr.outputImage!
        let newQrImageView = UIImageView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        newQrImageView.image = UIImage(ciImage: qrImage)
        view.addSubview(newQrImageView)
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    private func showReviewAlert() {
        if #available(iOS 10.3, *) {
            // iOS 10.3以上の処理
            SKStoreReviewController.requestReview()
        } else if let url = URL(string: "itms-apps://itunes.apple.com/app/id1222454517?action=write-review") {
            // iOS 10.3未満の処理
            showAlertController(url: url)
        }

    }
    
    private func showAlertController(url: URL) {
        let alert = UIAlertController(title: "レビューのお願い",
                                      message: "いつもありがとうございます！\nレビューをお願いします！",
                                      preferredStyle: .alert)
        self.present(alert, animated: true, completion: nil)
        
        let cancelAction = UIAlertAction(title: "キャンセル",
                                         style: .cancel,
                                         handler: nil)
        alert.addAction(cancelAction)
        
        let reviewAction = UIAlertAction(title: "レビューする",
                                         style: .default,
                                         handler: {
                                            (action:UIAlertAction!) -> Void in
                                            
                                            
                                            if #available(iOS 10.0, *) {
                                                UIApplication.shared.open(url, options: [:])
                                            }
                                            else {
                                                UIApplication.shared.openURL(url)
                                            }
                                            
        })
        alert.addAction(reviewAction)
    }
}


extension UIView {
    func toImage() -> UIImage? {
        UIGraphicsBeginImageContext(self.frame.size)
        guard let context = UIGraphicsGetCurrentContext() else {
            return nil
        }
        self.layer.render(in: context)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        
        return image
    }
}


