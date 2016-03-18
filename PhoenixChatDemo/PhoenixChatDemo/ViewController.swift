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

    @IBAction func goToChat(sender: AnyObject) {
        guard let username = usernameField.text where !username.isEmpty else {
            let alert = UIAlertController(title: nil, message: "Please enter username",
                preferredStyle: .Alert)
            alert.addAction(UIAlertAction(title: "OK", style: .Cancel, handler: nil))
            presentViewController(alert, animated: true, completion: nil)
            return
        }
        
        let chat = ChatViewController(username: username)
        let navigation = UINavigationController(rootViewController: chat)
        presentViewController(navigation, animated: true, completion: nil)
    }
}

