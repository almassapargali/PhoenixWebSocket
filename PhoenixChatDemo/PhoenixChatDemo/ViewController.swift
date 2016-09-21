//
//  ViewController.swift
//  PhoenixChatDemo
//
//  Created by Almas Sapargali on 3/18/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import UIKit

class ViewController: UIViewController {
    @IBOutlet weak var usernameField: UITextField!

    @IBAction func goToChat(_ sender: AnyObject) {
        guard let username = usernameField.text , !username.isEmpty else {
            let alert = UIAlertController(title: nil, message: "Please enter username",
                preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
            present(alert, animated: true, completion: nil)
            return
        }
        
        let chat = ChatViewController(username: username)
        let navigation = UINavigationController(rootViewController: chat)
        present(navigation, animated: true, completion: nil)
    }
}

