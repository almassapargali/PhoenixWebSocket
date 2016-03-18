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
    private let bubbleFactory = JSQMessagesBubbleImageFactory()
    
    private let outgoingBubble: JSQMessagesBubbleImage
    private let incomingBubble: JSQMessagesBubbleImage
    
    let username: String
    
    private let socket: Socket
    private let channel: Channel
    
    var subscription: AnyObject?
    
    var messages: [JSQMessage] = []
    
    deinit {
        if let observer = subscription {
            NSNotificationCenter.defaultCenter().removeObserver(observer)
        }
        socket.disconnect(0)
    }
    
    init(username: String) {
        self.username = username
        
        outgoingBubble = bubbleFactory.outgoingMessagesBubbleImageWithColor(.jsq_messageBubbleGreenColor())
        incomingBubble = bubbleFactory.incomingMessagesBubbleImageWithColor(.jsq_messageBubbleLightGrayColor())
        
//        let url = NSURL(string: "ws://phoenixchat.herokuapp.com/socket/websocket")!
        let url = NSURL(string: "ws://localhost:4000/socket/websocket")!
        socket = Socket(url: url)
        channel = Channel(topic: "rooms:lobby")
        
        super.init(nibName: "JSQMessagesViewController",
            bundle: NSBundle(forClass: JSQMessagesViewController.self))
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
        
        subscription = NSNotificationCenter.defaultCenter().addObserverForName(UIApplicationWillEnterForegroundNotification, object: nil, queue: nil) { [weak self] _ in
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
    
    override func didPressSendButton(button: UIButton!, withMessageText text: String!, senderId: String!, senderDisplayName: String!, date: NSDate!) {
        socket.send(channel, event: "new:msg", payload: ["user": username, "body": text]) { res in
            print("Sent", res)
        }
    }
    
    private func messageFrom(payload: Message.JSON) -> JSQMessage? {
        if let user = payload["user"] as? String, body = payload["body"] as? String {
            return JSQMessage(senderId: user, displayName: user, text: body)
        }
        return nil
    }
}

// MARK: JSQMessagesCollectionViewDataSource

extension ChatViewController {
    override func collectionView(collectionView: JSQMessagesCollectionView!, avatarImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageAvatarImageDataSource! {
        return nil
    }
    
    override func collectionView(collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return messages.count
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageData {
        return messages[indexPath.row]
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, didDeleteMessageAtIndexPath indexPath: NSIndexPath!) {
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, messageBubbleImageDataForItemAtIndexPath indexPath: NSIndexPath!) -> JSQMessageBubbleImageDataSource {
        let message = messages[indexPath.item]
        return message.senderId == senderId ? outgoingBubble : incomingBubble
    }
    
    override func collectionView(collectionView: JSQMessagesCollectionView!, attributedTextForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> NSAttributedString! {
        let message = messages[indexPath.item]
        
        if message.senderId == senderId { return nil }
        
        if indexPath.item - 1 >= 0 {
            let previousMessage = messages[indexPath.item - 1]
            if previousMessage.senderId == message.senderId { return nil }
        }
        
        return NSAttributedString(string: message.senderDisplayName)
    }
    
    override func collectionView(collectionView: UICollectionView, cellForItemAtIndexPath indexPath: NSIndexPath) -> UICollectionViewCell {
        let cell = super.collectionView(collectionView, cellForItemAtIndexPath: indexPath) as! JSQMessagesCollectionViewCell
        
        let message = messages[indexPath.item]
        let textColor: UIColor = message.senderId == senderId ? .whiteColor() : .blackColor()
        cell.textView?.textColor = textColor
        
        return cell
    }
}

// MARK: JSQMessagesCollectionViewDelegateFlowLayout

extension ChatViewController {
    override func collectionView(collectionView: JSQMessagesCollectionView!, layout collectionViewLayout: JSQMessagesCollectionViewFlowLayout!, heightForMessageBubbleTopLabelAtIndexPath indexPath: NSIndexPath!) -> CGFloat {
        let message = messages[indexPath.item]
        
        if message.senderId == senderId { return 0 }
        
        if indexPath.item - 1 >= 0 {
            let previousMessage = messages[indexPath.item - 1]
            if previousMessage.senderId == message.senderId { return 0 }
        }
        
        return kJSQMessagesCollectionViewCellLabelHeightDefault
    }
}