

/*
******************************************************************
* COPYRIGHT (c) <<2020>> <<tanu inc  >>         *
*
 * All rights reserved                                           *
*
 * This software embodies materials and concepts which are       *
* confidential to <<Customer Name>> and is made available solely *
* pursuant to the terms of a written license agreement with      *
* <<tanu Product>>.                                            *
*
* Designed and Developed by tanu inc Industries, Inc.
.           *
*----------------------------------------------------------------*
* MODULE OR UNIT: CloudService                                *
*
* PROGRAMMER :  Tanuja Awasthi                                   *
* DATE       :  18/07/20                                         *
* VERSION    :  1.0                                              *
*
*----------------------------------------------------------------*
*
* MODULE SUMMARY : This is thread checker class. Only access to  *
    Cloud connect                                                *
*
*
*
*
*----------------------------------------------------------------*
*
* TRACEABILITY RECORDS to SW requirements and detailed design :  *
* iOS 10 and onward
*
*
*----------------------------------------------------------------*
*
* MODIFICATION RECORDS                                           *
*
******************************************************************
*/


public enum UINavigationLabelAnimationDirection {
    /* Message navigation will be from top to bottom */
    case eTop
    /* Message navigation will be from bottom to top */
    case eBottom
}

let NavigationViewHeight: CGFloat = 54.0
let xPosition: CGFloat = 40.0

import UIKit
public struct MessageAttribute {
    public var title: String
    public var subTitle: String
    public var msgBgColor: UIColor
    public var titleFont: UIFont
    public var subTitleFont: UIFont
    public var msgTxtColor: UIColor
    public var spaceLines: CGFloat
    public var cornerRadius: CGFloat
    init(title: String = "Can't connect",
         subTitle: String = "You need an internet connection to use AIO Games",
         msgBgColor: UIColor = .white,
         titleFont: UIFont = UIFont.systemFont(ofSize: 16.0),
         subTitleFont: UIFont = UIFont.systemFont(ofSize: 14.0),
         msgTxtColor: UIColor = .black,
         spaceLines: CGFloat = 2.0,cornerRadius: CGFloat = 4.0) {
        self.title = title
        self.subTitle = subTitle
        self.msgBgColor = msgBgColor
        self.titleFont = titleFont
        self.subTitleFont = subTitleFont
        self.msgTxtColor = msgTxtColor
        self.spaceLines = spaceLines
        self.cornerRadius = cornerRadius
    }
}
class NetworkStatusView: UIView {
    static var messageAttribute: MessageAttribute = MessageAttribute()
    var lastContentOffset: CGFloat = 0
    let navigationBarLbl = UILabel()
    var defaultYPosition: CGFloat = 0
    var disableViewMoving: Bool = false
    var isSubViewOnWindow: Bool = false
     
     override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = NetworkStatusView.messageAttribute.msgBgColor
        self.clipsToBounds = true
        navigationBarLbl.textAlignment = .center
        navigationBarLbl.font =  NetworkStatusView.messageAttribute.titleFont
       // navigationBarLbl.backgroundColor = .red
        navigationBarLbl.numberOfLines = 0
        navigationBarLbl.textColor =  NetworkStatusView.messageAttribute.msgTxtColor
        navigationBarLbl.frame = CGRect(x: 0, y: 0  , width: frame.size.width, height: frame.size.height)
        self.addSubview(navigationBarLbl)
        UIApplication.shared.keyWindow?.addSubview(self)
        isSubViewOnWindow = true
        navigationBarLbl.attributedText = self.attributedString(NetworkStatusView.messageAttribute)
         self.layer.cornerRadius = NetworkStatusView.messageAttribute.cornerRadius
         self.clipsToBounds = true
    }
    
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")}
    
    func attributedString(_ attri: MessageAttribute )->NSAttributedString {
        let strig = String(format:"%@\n%@",attri.title,attri.subTitle)
        let attributedString = NSMutableAttributedString(string:strig)
        
        // *** Create instance of `NSMutableParagraphStyle`
        let paragraphStyle = NSMutableParagraphStyle()
        
        // *** set LineSpacing property in points ***
        paragraphStyle.lineSpacing = attri.spaceLines // Whatever line spacing you want in points
        paragraphStyle.alignment = .center
        paragraphStyle.lineBreakMode = .byTruncatingTail
        // *** Apply attribute to string ***
        /* First Text font and color style */
        attributedString.addAttribute(NSAttributedString.Key.font, value: attri.titleFont, range:NSMakeRange(0, attri.title.count))
        attributedString.addAttribute(NSAttributedString.Key.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attri.title.count))
        
        attributedString.addAttribute(NSAttributedString.Key.font, value: attri.subTitleFont, range: NSMakeRange(attri.title.count + 1, attri.subTitle.count))
        
        return attributedString
    }
    
     func displayInternetStatus() {
        self.moveTitleView(inDirection: .eBottom)
        DispatchQueue.main.asyncAfter(deadline: DispatchTime.now() + 3.0) {
            self.moveTitleView(inDirection: .eTop)
        }
    }

    func moveTitleView(inDirection direction: UINavigationLabelAnimationDirection) {
        if disableViewMoving == true {
            return
        }
        var frame = self.frame
        var animationTime: Float = 0.0
        if direction == .eTop {
            animationTime = 0.4
            frame.origin.y = NetworkStatusView.yPositionOfLabel(withDirection: .eTop)
            
            
        }else if direction == .eBottom {
            animationTime = 0.5
            frame.origin.y =  NetworkStatusView.yPositionOfLabel(withDirection: .eBottom)
        }
        
        UIView.animate(withDuration: TimeInterval(animationTime),
                       delay: 0.0,
                       options: .curveEaseOut,
                       animations: { () -> Void in
                        self.frame = frame
                        self.setNeedsLayout()
        }, completion: { (finished) -> Void in
            // ....
        })
    }
    
    class func yPositionOfLabel(withDirection direction: UINavigationLabelAnimationDirection)->CGFloat {
        var bottomYPosition: CGFloat = 0.0
        if direction == .eBottom {
            if UIScreen.main.bounds.size.height > 736 {
                bottomYPosition = 28.0
            }else {
                bottomYPosition = 10.0
            }
        }else if direction == .eTop {
            bottomYPosition  = -NavigationViewHeight
        }
        return bottomYPosition
    }

}
