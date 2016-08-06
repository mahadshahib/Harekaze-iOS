//
//  SettingsTableViewController.swift
//  Harekaze
//
//  Created by Yuki MIZUNO on 2016/08/06.
//  Copyright © 2016年 Yuki MIZUNO. All rights reserved.
//

import UIKit
import Material

class SettingsTableViewController: UITableViewController {

	// MARK: - Private instance fileds
	private let sectionHeaderHeight: CGFloat = 48
	private let sectionTitles = ["Chinachu"]
	private var statusBarView: MaterialView!
	private var closeButton: IconButton!

	// MARK: - Interface Builder outlets
	@IBOutlet weak var chinachuWUIAddressLabel: UILabel!
	@IBOutlet weak var chinachuAuthenticationLabel: UILabel!


	// MARK: - View initialization

	override func viewDidLoad() {
        super.viewDidLoad()
		chinachuWUIAddressLabel.text = ChinachuAPI.wuiAddress
		chinachuAuthenticationLabel.text = ChinachuAPI.username

		// Set navigation title
		navigationItem.title = "Settings"
		navigationItem.titleLabel.textAlignment = .Left
		navigationItem.titleLabel.font = RobotoFont.mediumWithSize(20)
		navigationItem.titleLabel.textColor = MaterialColor.white

		// Set status bar
		statusBarView = MaterialView()
		statusBarView.zPosition = 3000
		statusBarView.restorationIdentifier = "StatusBarView"
		statusBarView.backgroundColor = MaterialColor.black.colorWithAlphaComponent(0.12)
		self.navigationController?.view.layout(statusBarView).top(0).horizontally().height(20)

		// Set navigation bar buttons
		closeButton = IconButton()
		closeButton.setImage(UIImage(named: "ic_close_white"), forState: .Normal)
		closeButton.setImage(UIImage(named: "ic_close_white"), forState: .Highlighted)
		closeButton.addTarget(self, action: #selector(handleCloseButton), forControlEvents: .TouchUpInside)

		navigationItem.leftControls = [closeButton]
    }

	// MARK: - Memory/resource management

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
	}

	// MARK: - Event handler

	internal func handleCloseButton() {
		self.dismissViewControllerAnimated(true, completion: nil)
	}

	// MARK: - Layout methods

	override func viewWillLayoutSubviews() {
		super.viewWillLayoutSubviews()
		statusBarView.hidden = MaterialDevice.isLandscape && .iPhone == MaterialDevice.type
	}

    // MARK: - Table view data source

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 2
    }

	override func tableView(tableView: UITableView, viewForHeaderInSection section: Int) -> UIView? {
		let headerView = UIView()
		let sectionLabel = UILabel()

		sectionLabel.text = sectionTitles[section]
		sectionLabel.font = RobotoFont.mediumWithSize(14)
		sectionLabel.textColor = MaterialColor.blue.accent1
		headerView.backgroundColor = MaterialColor.white
		headerView.layout(sectionLabel).topLeft(top: 16, left: 16).right(16).height(20)

		return headerView
	}

	override func tableView(tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
		return sectionHeaderHeight
	}

	// MARK: - Scroll view
	override func scrollViewDidScroll(scrollView: UIScrollView) {
		let offset = scrollView.contentOffset

		// Disable floating section header
		if offset.y <= sectionHeaderHeight && offset.y > 0 {
			scrollView.contentInset = UIEdgeInsets(top: -offset.y, left: 0, bottom: 0, right: 0)
		} else if offset.y >= sectionHeaderHeight {
			scrollView.contentInset = UIEdgeInsets(top: -sectionHeaderHeight, left: 0, bottom: 0, right: 0)
		}
	}


}
