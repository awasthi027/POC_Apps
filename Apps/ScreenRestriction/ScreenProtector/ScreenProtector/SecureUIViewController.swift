//
//  SecureUIViewController.swift
//  ScreenProtector
//
//  Created by Ashish Awasthi on 07/08/25.
//



import UIKit
import SecureScreen

struct RenderViewModel {
    var color: UIColor
    var message: String
    var shouldShowMessage: Bool
    init(color: UIColor,
         message: String,
         shouldShowMessage: Bool) {
        self.color = color
        self.message = message
        self.shouldShowMessage = shouldShowMessage
    }
}

class SecureUIViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = .white
        // Create three colored views with labels
        var renderViewList: [RenderViewModel] = []
        renderViewList.append(RenderViewModel(color: .systemRed,
                                              message: "ShouldShow message is true. Will show the message in the image or video that is captured",
                                              shouldShowMessage: true))
        renderViewList.append(RenderViewModel(color: .systemGreen,
                                              message: "ShouldShow message is false. Will not show the message",
                                              shouldShowMessage: false))


        var previousBottomAnchor = view.safeAreaLayoutGuide.topAnchor

        for (index,item) in renderViewList.enumerated() {
            // Create the label
            let label = UILabel()
            label.text = item.message
            label.textColor = .black
            label.textAlignment = .center
            label.numberOfLines = 0
            label.font = UIFont.boldSystemFont(ofSize: 16)
            label.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(label)

            // Create the colored view
            let coloredView = UIView()
            coloredView.backgroundColor = item.color

            let securedColoredView = SecureViewService.shared.getSecuredView(coloredView,
                                                                             shouldShowRestrictionMessage: item.shouldShowMessage)
            securedColoredView.translatesAutoresizingMaskIntoConstraints = false
            self.view.addSubview(securedColoredView)

            let constraints = [
                // Label constraints
                label.topAnchor.constraint(equalTo: previousBottomAnchor, constant: index == 0 ? 20 : 40),
                label.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                label.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),

                securedColoredView.topAnchor.constraint(equalTo: label.bottomAnchor, constant: 8),
                securedColoredView.heightAnchor.constraint(equalToConstant: 20),
                securedColoredView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
                securedColoredView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20)
            ]

            NSLayoutConstraint.activate(constraints)

            // Update the previous bottom anchor for next iteration
            previousBottomAnchor = coloredView.bottomAnchor
        }
    }
}
