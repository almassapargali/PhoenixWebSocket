//
//  ChatViewController.swift
//  PhoenixChatDemo
//
//  Created by Almas Sapargali on 3/18/16.
//  Copyright © 2016 Almas Sapargali. All rights reserved.
//

import Foundation
import PhoenixWebSocket

class ChatViewController: JSQMessagesViewController {
    fileprivate let bubbleFactory = JSQMessagesBubbleImageFactory()!
    
    fileprivate let outgoingBubble: JSQMessagesBubbleImage
    fileprivate let incomingBubble: JSQMessagesBubbleImage
    
    let username: String
    
    fileprivate let socket: Socket
    fileprivate let channel: Channel
    
    var subscription: AnyObject?
    
    var messages: [JSQMessage] = []
    
    deinit {
        if let observer = subscription {
            NotificationCenter.default.removeObserver(observer)
        }
        socket.disconnect(0)
    }
    
    init(username: String) {
        self.username = username
        
        outgoingBubble = bubbleFactory.outgoingMessagesBubbleImage(with: .jsq_messageBubbleGreen())
        incomingBubble = bubbleFactory.incomingMessagesBubbleImage(with: .jsq_messageBubbleLightGray())
        
//        let url = URL(string: "ws://phoenixchat.herokuapp.com/socket/websocket")!
        let url = URL(string: "ws://localhost:4000/socket/websocket")!
        socket = Socket(url: url)
        channel = Channel(topic: "rooms:lobby")
        
        super.init(nibName: "JSQMessagesViewController",
            bundle: Bundle(for: JSQMessagesViewController.self))
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        senderId = username
        senderDisplayName = username
        
        // remove attachments button
        inputToolbar?.contentView?.leftBarButtonItem = nil
        
        subscription = NotificationCenter.default.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: nil) { [weak self] _ in
            self?.socket.connect()
        }
        
        channel
            .on("new:msg") { [weak self] message in
                guard let jsqMessage = self?.messageFrom(message.payload) else { return }
                self?.messages.append(jsqMessage)
                if jsqMessage.senderId == self?.senderId {
                    JSQSystemSoundPlayer.jsq_playMessageSentSound()
                    self?.finishSendingMessage()
                } else {
                    JSQSystemSoundPlayer.jsq_playMessageReceivedSound()
                    self?.finishReceivingMessage()
                }
            }
        
        socket.join(channel)
        socket.enableLogging = true
        socket.connect()
    }
    
    override func didPressSend(_ button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: Date!) {
        socket.send(channel, event: "new:msg", payload: ["user": username as AnyObject, "body": text as AnyObject]) { res in
            print("Sent", res)
        }
    }
    
    fileprivate func messageFrom(_ payload: Message.JSON) -> JSQMessage? {
        if let user = payload["user"] as? String, let body = payload["body"] as? String {
            return JSQMessage(senderId: user, displayName: user, text: body)
        }
        return nil
    }
}

// MARK: JSQMessagesCollectionViewDataSource

extension ChatViewController {
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAt indexPath: IndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    override func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageDataForItemAt indexPath: IndexPath!) -> JSQMessageData {
        return messages[indexPath.row]
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, didDeleteMessageAt indexPath: IndexPath!) {
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAt indexPath: IndexPath!) -> JSQMessageBubbleImageDataSource {
        let message = messages[indexPath.item]
        return message.senderId == senderId ? outgoingBubble : incomingBubble
    }
    
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAt indexPath: IndexPath!) -> NSAttributedString! {
        let message = messages[indexPath.item]
        
        if message.senderId == senderId { return nil }
        
        if indexPath.item - 1 >= 0 {
            let previousMessage = messages[indexPath.item - 1]
            if previousMessage.senderId == message.senderId { return nil }
        }
        
        return NSAttributedString(string: message.senderDisplayName)
    }
    
    override func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAt: indexPath) as! JSQMessagesCollectionViewCell
        
        let message = messages[indexPath.item]
        let textColor: UIColor = message.senderId == senderId ? .white : .black
        cell.textView?.textColor = textColor
        
        return cell
    }
}

// MARK: JSQMessagesCollectionViewDelegateFlowLayout

extension ChatViewController {
    override func collectionView(_ collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAt indexPath: IndexPath!) -> CGFloat {
        let message = messages[indexPath.item]
        
        if message.senderId == senderId { return 0 }
        
        if indexPath.item - 1 >= 0 {
            let previousMessage = messages[indexPath.item - 1]
            if previousMessage.senderId == message.senderId { return 0 }
        }
        
        return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
}
