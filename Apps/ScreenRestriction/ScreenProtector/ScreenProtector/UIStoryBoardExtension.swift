//
//  UIStoryBoardExtension.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 08/08/25.
//

import UIKit

extension UIStoryboard {
    // Main storyboard
    static var main: UIStoryboard {
        return UIStoryboard(name: "Main", bundle: nil)
    }

    func instantiateViewController<T>(withIdentifier identifier: T.Type) -> T? where T: UIViewController {
        let className = String(describing: identifier)
        return self.instantiateViewController(withIdentifier: className) as? T
    }
}
