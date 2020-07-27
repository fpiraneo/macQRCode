//
//  ViewController.swift
//  macQRCode
//
//  Created by Francesco Piraneo G. on 20.07.20.
//  Copyright © 2020 Francesco Piraneo G. All rights reserved.
//

import Cocoa
import AVFoundation

class ViewController: NSViewController {
    @IBOutlet weak var cameraOutput: NSView!
    @IBOutlet weak var readText: NSTextField!
    
    var captureSession: AVCaptureSession?
    var videoPreviewLayer: AVCaptureVideoPreviewLayer?
    var detector: CIDetector?
    var dispatchQueue: DispatchQueue?

    override func viewDidAppear() {
        super.viewDidAppear()
        
        // Initialize detector
        detector = CIDetector(ofType: CIDetectorTypeQRCode, context: nil, options: nil)
    }
    
    @IBAction func startReading(_ sender: Any) {
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            NSLog("Unable to get default video capture device.")
            return
        }
        
        switch captureDevice.position {
            case .unspecified:  NSLog("Unspecified capture device - Don't worry: Maybe your device has only one camera!")
            case .back:         NSLog("Reading from back camera")
            case .front:        NSLog("Reading from front Camera")
            @unknown default:   NSLog("??? Added camera position ... please check")
        }
        
        let input : AVCaptureDeviceInput
        do {
            input = try AVCaptureDeviceInput(device: captureDevice)
        } catch {
            NSLog("\(error.localizedDescription)")
            return
        }
        
        captureSession = AVCaptureSession()
        captureSession!.addInput(input)

        if dispatchQueue == nil {
            dispatchQueue = DispatchQueue(label: "myQueue")
        }
        
        // add per-frame callback (see captureOutput:didOutputSampleBuffer:fromConnection method below)
        let vdo = AVCaptureVideoDataOutput()
        vdo.setSampleBufferDelegate(self, queue: dispatchQueue)
        captureSession!.addOutput(vdo)

        // Initialize the video preview layer and add it as a sublayer to the viewPreview view's layer.
        videoPreviewLayer = AVCaptureVideoPreviewLayer(session: captureSession!)
        videoPreviewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        
        // Initialize layer if not already
        if cameraOutput.layer == nil {
            cameraOutput.layer = CALayer()
        }
        videoPreviewLayer?.frame = cameraOutput.layer!.bounds
        cameraOutput.layer!.addSublayer(videoPreviewLayer!)
        cameraOutput.layer!.borderColor = NSColor.systemGray.cgColor
        captureSession!.startRunning()
    }
    
    @IBAction func stopReading(_ sender: Any) {
        captureSession!.stopRunning()
        dispatchQueue = nil
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        //NSLog(@"sample buffer did output");
        var img: CIImage? = nil
        if let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            img = CIImage(cvImageBuffer: buffer)
        }
        
        var features: [CIFeature] = []
        if let img = img {
            features = detector!.features(in: img)
        }
        
        for f in features {
            if f.type == CIFeatureTypeQRCode {
                //NSLog(@"Feature %@ at %f,%f,%f,%f",f.type, f.bounds.origin.x, f.bounds.origin.y, f.bounds.size.width, f.bounds.size.height);
                let qr = f as? CIQRCodeFeature
                //NSLog(@"Message: %@", qr.messageString);
                guard let readQR = qr else {
                    DispatchQueue.main.async {
                        self.readText.stringValue = "Unable to read QR code"
                        self.captureSession!.stopRunning()
                    }
                    return
                }
                
                DispatchQueue.main.async {
                    self.readText.stringValue = readQR.messageString ?? "No message"
                    self.captureSession!.stopRunning()
                }
            }
        }
    }
}
