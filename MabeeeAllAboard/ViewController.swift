//
//  ViewController.swift
//  MabeeeAllAboard
//
//  Created by amotz on 2017/01/10.
//  Copyright © 2017年 amotz. All rights reserved.
//

import UIKit
import Speech
import MaBeeeSDK

class ViewController: UIViewController, SFSpeechRecognizerDelegate {

    // MARK: Properties
    private let startWords = ["ドクターイエロー", "出発進行"]
    private let stopWords = ["停車します"]
    
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "ja-JP"))!
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()
    
    @IBOutlet weak var speechLabel: UILabel!
    @IBOutlet weak var recButton: UIButton!
    @IBOutlet weak var settingsButton: UIButton!
    @IBOutlet weak var emergencyButton: UIButton!
    @IBOutlet weak var balloonImage: UIImageView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        speechRecognizer.delegate = self
        
        recButton.isEnabled = false
        balloonImage.isHidden = true
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        requestRecognizerAuthorization()
    }
    
    // MARK: Actions
    @IBAction func tappedRecButton(_ sender: UIButton) {
        if audioEngine.isRunning {
            stopRecording()
            recButton.isEnabled = false
            recButton.setImage(UIImage(named: "Mic")!, for: UIControlState())
            speechLabel.text = ""
            balloonImage.isHidden = true
        } else {
            try! startRecording()
            recButton.setImage(UIImage(named: "Pause")!, for: UIControlState())
        }
    }
    
    @IBAction func tappedSettingsButton(_ sender: UIButton) {
        let vc = MaBeeeScanViewController()
        vc.show(self)
    }
    
    @IBAction func tappedEmergencyButton(_ sender: UIButton) {
        stopMaBeee()
    }
    
    // MARK: MaBeee functions
    fileprivate func startMaBeee() {
        setMaBeeePWMDuty(100)
    }
    
    fileprivate func stopMaBeee() {
        setMaBeeePWMDuty(0)
    }
    
    fileprivate func setMaBeeePWMDuty (_ pwmDuty :Int32) {
        for device in MaBeeeApp.instance().devices() {
            device.pwmDuty = pwmDuty
        }
    }
    
    // MARK: Speech functions
    fileprivate func requestRecognizerAuthorization() {
        SFSpeechRecognizer.requestAuthorization { authStatus in
            OperationQueue.main.addOperation { [weak self] in
                guard let `self` = self else { return }
                
                switch authStatus {
                case .authorized:
                    self.recButton.isEnabled = true
                case .denied:
                    self.recButton.isEnabled = false
                case .restricted:
                    self.recButton.isEnabled = false
                case .notDetermined:
                    self.recButton.isEnabled = false
                }
            }
        }
    }
    
    fileprivate func startRecording() throws {
        refreshTask()
        
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(AVAudioSessionCategoryRecord)
        try audioSession.setMode(AVAudioSessionModeMeasurement)
        try audioSession.setActive(true, with: .notifyOthersOnDeactivation)
        
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        
        guard let inputNode = audioEngine.inputNode else { fatalError("Audio engine has no input node") }
        guard let recognitionRequest = recognitionRequest else { fatalError("Unable to created a SFSpeechAudioBufferRecognitionRequest object") }
        
        recognitionRequest.shouldReportPartialResults = true
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let `self` = self else { return }
            
            var isFinal = false
            
            if let result = result {
                let resultString = result.bestTranscription.formattedString
                self.speechLabel.text = resultString
                
                // Control MaBeee by result bestTranscription
                if self.startWords.contains(resultString){
                    self.startMaBeee()
                } else if self.stopWords.contains(resultString){
                    self.stopMaBeee()
                }
                isFinal = result.isFinal
            }
            
            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                
                self.recognitionRequest = nil
                self.recognitionTask = nil
                
                self.speechLabel.text = ""
                self.recButton.isEnabled = true
            }
        }
        
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { (buffer: AVAudioPCMBuffer, when: AVAudioTime) in
            self.recognitionRequest?.append(buffer)
        }
        
        try startAudioEngine()
    }
    
    fileprivate func stopRecording() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
    }
    
    fileprivate func refreshTask() {
        if let recognitionTask = recognitionTask {
            recognitionTask.cancel()
            self.recognitionTask = nil
        }
    }
    
    fileprivate func startAudioEngine() throws {
        audioEngine.prepare()
        try audioEngine.start()
        
        balloonImage.isHidden = false
        speechLabel.text = "アナウンスしてください"
    }
    
    // MARK: SFSpeechRecognizerDelegate
    func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        if available {
            recButton.isEnabled = true
        } else {
            recButton.isEnabled = false
        }
    }
}
