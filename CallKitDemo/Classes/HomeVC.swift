//
//  HomeVC.swift
//  CallKitDemo
//
//  Created by Nirzar Gandhi on 25/02/25.
//

import UIKit
import CallKit
import AudioToolbox

class HomeVC: BaseVC {
    
    // MARK: - IBOutlets
    @IBOutlet weak var phoneNumberTF: UITextField!
    @IBOutlet weak var stackView: UIStackView!
    @IBOutlet weak var startCallBtn: UIButton!
    @IBOutlet weak var endCallBtn: UIButton!
    
    
    // MARK: - Properties
    fileprivate lazy var soundID: SystemSoundID = 0
    
    
    // MARK: -
    // MARK: - View init Methods
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Home"
        
        self.setControlsProperty()
    }
    
    fileprivate func setControlsProperty() {
        
        self.view.backgroundColor = .clear
        self.view.isOpaque = false
        
        // Phone Number TextField
        self.phoneNumberTF.backgroundColor = .clear
        self.phoneNumberTF.textColor = .black
        self.phoneNumberTF.tintColor = .black
        self.phoneNumberTF.font = UIFont.systemFont(ofSize: 14)
        self.phoneNumberTF.keyboardType = .phonePad
        self.phoneNumberTF.autocorrectionType = .no
        self.phoneNumberTF.attributedPlaceholder = NSAttributedString(string: "Enter phone number", attributes: [NSAttributedString.Key.foregroundColor: UIColor.gray])
        self.phoneNumberTF.text = ""
        
        // Start and End Call Butttons
        self.startCallBtn.backgroundColor = .green
        self.startCallBtn.titleLabel?.backgroundColor = .green
        self.startCallBtn.setTitleColor(.white, for: .normal)
        self.startCallBtn.setTitle("Start Call", for: .normal)
        
        self.endCallBtn.backgroundColor = .red
        self.endCallBtn.titleLabel?.backgroundColor = .red
        self.endCallBtn.setTitleColor(.white, for: .normal)
        self.endCallBtn.setTitle("End Call", for: .normal)
    }
}


// MARK: - Button Touch & Action
extension HomeVC {
    
    @IBAction func startCallBtnTouch(_ sender: UIButton) {
        
        if let phoneNumber = self.phoneNumberTF.text, phoneNumber.count == 0 {
            print("Enter a phone number")
            return
        }
        
        CallKitManager.shared.startCall(receiverId: "cometchat-uid-6", uuid: UUID())
    }
    
    @IBAction func endCallBtnTouch(_ sender: UIButton) {
        
        let callController = CXCallController()
        
        let endCallAction = CXEndCallAction(call: APPDELEOBJ.uuid)
        callController.request(CXTransaction(action: endCallAction), completion: { error in
            
            if let error = error {
                print("Error: \(error)")
            } else {
                print("Success")
            }
        })
    }
}
