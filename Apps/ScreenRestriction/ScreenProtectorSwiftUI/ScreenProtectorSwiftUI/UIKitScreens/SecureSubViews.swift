//
//  SecureSubViews.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 09/08/25.
//
import UIKit
import SecureScreen

public class SecureSubViews: CustomSecureView {

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    public override func awakeFromNib() {
        super.awakeFromNib()
        print("SecuredView awakeFromNib called")
    }
}

