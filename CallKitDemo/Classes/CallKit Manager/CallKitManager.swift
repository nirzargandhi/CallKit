//
//  CallKitManager.swift
//  CallKitDemo
//
//  Created by Nirzar Gandhi on 25/02/25.
//

import Foundation
import CallKit
import UIKit
import AVFoundation
import AudioToolbox

class CallKitManager: NSObject {
    
    // MARK: - Properties
    static let shared: CallKitManager = {
        let instance = CallKitManager()
        return instance
    }()
    
    lazy var callController = CXCallController()
    lazy var callObserver = CXCallObserver()
    var provider: CXProvider?
    
    fileprivate lazy var soundID: SystemSoundID = 0
    
    
    // MARK: - Init Method
    override init() {
        super.init()
        
        let configuration = CXProviderConfiguration(localizedName: "CallKit Demo")
        configuration.maximumCallGroups = 1
        configuration.maximumCallsPerCallGroup = 1
        configuration.supportsVideo = false
        configuration.supportedHandleTypes = [.generic]
        configuration.iconTemplateImageData = UIImage(named: "callkit-icon")?.pngData()
        
        self.provider = CXProvider(configuration: configuration)
        self.provider?.setDelegate(self, queue: nil)
    }
}


// MARK: - Call Back
extension CallKitManager {
    
    fileprivate func configureAudioSession(forSpeaker isSpeakerEnabled: Bool) {
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
            
            if isSpeakerEnabled {
                try audioSession.overrideOutputAudioPort(.speaker) // Use speaker
            } else {
                try audioSession.overrideOutputAudioPort(.none) // Use earpiece
            }
            
            print(isSpeakerEnabled ? "🔊 Speaker enabled" : "🎧 Earpiece enabled")
        } catch {
            print("⚠️ Audio session configuration failed: \(error.localizedDescription)")
        }
    }
    
    fileprivate func playOutgoingRing() {
        
        self.stopOutgoingRing()
        
        guard let path = Bundle.main.path(forResource: "ringtone", ofType:"aiff") else {
            return
        }
        
        let url = URL(fileURLWithPath: path)
        
        AudioServicesCreateSystemSoundID(url as CFURL, &self.soundID)
        AudioServicesPlaySystemSound(self.soundID)
    }
    
    fileprivate func stopOutgoingRing() {
        AudioServicesDisposeSystemSoundID(self.soundID)
    }
    
    func startCall(receiverId: String, uuid: UUID) {
        
        let cxHandle = CXHandle(type: .generic, value: receiverId)
        let startCallAction = CXStartCallAction(call: uuid, handle: cxHandle)
        
        let transaction = CXTransaction(action: startCallAction)
        
        self.callController.request(transaction) { [weak self] error in
            
            if let error = error {
                
                print("\nFailed to start call: \(error.localizedDescription)")
                
            } else {
                print("\nOutgoing call started")
                
                if let cxCallUpdate = self?.updateCXCall(name: receiverId) {
                    self?.provider?.reportCall(with: uuid, updated: cxCallUpdate)
                }
            }
        }
    }
    
    func answerCall(uuid: UUID) {
        
        let answerCallAction = CXAnswerCallAction(call: uuid)
        let transaction = CXTransaction(action: answerCallAction)
        
        self.callController.request(transaction) { [weak self] error in
            
            if let error = error {
                
                print("\nError answering call: \(error.localizedDescription)")
                
            } else {
                
                print("\nCall answered: \(uuid)")
                self?.reportCallConnected(uuid: uuid)
            }
        }
    }
    
    func endCall(uuid: UUID) {
        
        let endCallAction = CXEndCallAction(call: uuid)
        let transaction = CXTransaction(action: endCallAction)
        
        self.callController.request(transaction) { error in
            
            if let error = error {
                print("\nError ending call: \(error.localizedDescription)")
            } else {
                print("\nCall ended: \(uuid)")
            }
        }
    }
    
    func reportIncomingCall(uuid: UUID, callerName: String, hasVideo: Bool = false) {
        
        let cxCallUpdate = self.updateCXCall(name: callerName)
        
        self.provider?.reportNewIncomingCall(with: uuid, update: cxCallUpdate) { error in
            
            if let error = error {
                print("\nError reporting incoming call: \(error)")
            } else {
                print("\nIncoming call successfully reported.")
            }
        }
    }
    
    func reportCallConnected(uuid: UUID) {
        
        print("\nCall connected: \(uuid)")
        
        self.stopOutgoingRing()
        
        if UIApplication.shared.applicationState == .inactive {
            self.navigateToVoiceCallScreen()
        }
        
        self.provider?.reportOutgoingCall(with: uuid, connectedAt: Date())
    }
    
    func reportCallEnded(uuid: UUID, reason: CXCallEndedReason) {
        
        print("\nCall ended: \(uuid), reason: \(reason.rawValue)")
        
        self.provider?.reportCall(with: uuid, endedAt: Date(), reason: reason)
    }
    
    fileprivate func updateCXCall(name: String) -> CXCallUpdate {
        
        let cxHandle = CXHandle(type: .generic, value: name)
        
        let update = CXCallUpdate()
        update.remoteHandle = cxHandle
        update.localizedCallerName = name.capitalized
        update.hasVideo = false
        update.supportsDTMF = true
        update.supportsHolding = true
        update.supportsGrouping = false
        update.supportsUngrouping = false
        
        return update
    }
    
    fileprivate func navigateToVoiceCallScreen() {
        // Navigate to particular screen
    }
    
    func isOnPhoneCall() -> Bool {
        
        for call in CXCallObserver().calls {
            
            if call.hasEnded == false {
                return true
            }
        }
        
        return false
    }
}


// MARK: - CXProvider Delegate
extension CallKitManager: CXProviderDelegate {
    
    func providerDidReset(_ provider: CXProvider) {
        print("\nProvider reset")
    }
    
    func provider(_ provider: CXProvider, perform action: CXStartCallAction) {
        
        print("\nCXStartCallAction - Start call - \(action.uuid)")
        
        self.configureAudioSession(forSpeaker: false)
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            self.playOutgoingRing()
        }
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
        
        print("\nCXAnswerCallAction - Answering call - \(action.uuid)")
        
        self.configureAudioSession(forSpeaker: false)
        
        self.reportCallConnected(uuid: action.callUUID)
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, perform action: CXEndCallAction) {
        
        print("\nCXEndCallAction - Ending call - \(action.uuid)")
        
        self.stopOutgoingRing()
        
        action.fulfill()
    }
    
    func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
        
        print("CallKit activated audio session")
        
        self.configureAudioSession(forSpeaker: false)
    }
    
    func provider(_ provider: CXProvider, perform action: CXSetMutedCallAction) {
        
        let audioSession = AVAudioSession.sharedInstance()
        do {
            
            if action.isMuted {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.duckOthers])
                print("\nMuted the call")
            } else {
                try audioSession.setCategory(.playAndRecord, mode: .voiceChat, options: [.allowBluetooth, .allowBluetoothA2DP])
                print("\nUnmuted the call")
            }
            
            try audioSession.setActive(true)
            
            action.fulfill()
            
        } catch {
            
            print("\nError handling mute/unmute: \(error.localizedDescription)")
            action.fail()
        }
    }
}

