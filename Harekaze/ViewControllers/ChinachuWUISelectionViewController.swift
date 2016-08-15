/**
 *
 * ChinachuWUISelectionViewController.swift
 * Harekaze
 * Created by Yuki MIZUNO on 2016/08/06.
 * 
 * Copyright (c) 2016, Yuki MIZUNO
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 * 
 * 1. Redistributions of source code must retain the above copyright notice,
 *    this list of conditions and the following disclaimer.
 * 
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *    this list of conditions and the following disclaimer in the documentation
 *     and/or other materials provided with the distribution.
 * 
 * 3. Neither the name of the copyright holder nor the names of its contributors
 *    may be used to endorse or promote products derived from this software
 *    without specific prior written permission.
 * 
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
 * ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
 * SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
 * INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
 * CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
 * ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF
 * THE POSSIBILITY OF SUCH DAMAGE.
 */

import UIKit
import Material
import SpringIndicator

class ChinachuWUISelectionViewController: MaterialContentAlertViewController, UITableViewDelegate, UITableViewDataSource, NSNetServiceBrowserDelegate, NSNetServiceDelegate, TextFieldDelegate {

	// MARK: - Instance fields
	var tableView: UITableView!
	var manualInputView: UIView!
	var timeoutAction: [NSNetServiceBrowser: NSTimer] = [:]
	var services: [NSNetService] = []
	var dataSource: [NSNetService] = []
	var saveAction: MaterialAlertAction!


	// MARK: - View initialization
    override func viewDidLoad() {
        super.viewDidLoad()

		self.alertView.divider = true

		// Table view
		self.tableView.registerNib(UINib(nibName: "ChinachuWUIListTableViewCell", bundle: nil), forCellReuseIdentifier: "ChinachuWUIListTableViewCell")
		self.tableView.separatorInset = UIEdgeInsetsZero
		self.tableView.rowHeight = 72
		self.tableView.delegate = self
		self.tableView.dataSource = self

		// Manual input view
		let addressTextField = TextField()
		addressTextField.placeholderLabel
		addressTextField.placeholder = "Chinachu WUI Address"
		addressTextField.text = ChinachuAPI.wuiAddress
		addressTextField.clearButtonMode = .WhileEditing
		addressTextField.enableClearIconButton = true
		addressTextField.placeholderActiveColor = MaterialColor.blue.base
		addressTextField.returnKeyType = .Done
		addressTextField.autocapitalizationType = .None
		addressTextField.autocorrectionType = .No
		addressTextField.keyboardType = .URL
		addressTextField.delegate = self
		manualInputView.layout(addressTextField).centerVertically().left(16).right(16).height(20)


		// Manual input button
		let toggleManualInputButton = IconButton(frame: CGRect(origin: CGPointZero, size: CGSize(width: 24, height: 24)))
		let onePasswordButtonImage = UIImage(named: "ic_settings")?.imageWithRenderingMode(.AlwaysTemplate)
		toggleManualInputButton.setImage(onePasswordButtonImage, forState: .Normal)
		toggleManualInputButton.setImage(onePasswordButtonImage, forState: .Highlighted)
		toggleManualInputButton.tintColor = MaterialColor.darkText.secondary
		toggleManualInputButton.addTarget(self, action: #selector(toggleAutoManualWUISelector), forControlEvents: .TouchUpInside)

		self.alertView.leftButtons = [toggleManualInputButton]

		// Manual input save button
		saveAction = MaterialAlertAction(title: "SAVE", style: .Default, handler: {(action: MaterialAlertAction!) -> Void in
			ChinachuAPI.wuiAddress = addressTextField.text!

			self.dismissViewControllerAnimated(true, completion: nil)

			guard let navigationController = self.presentingViewController as? NavigationController else {
				return
			}
			guard let settingsTableViewController = navigationController.viewControllers.first as? SettingsTableViewController else {
				return
			}
			settingsTableViewController.reloadSettingsValue()
		})
		saveAction.hidden = true

		// Discovery Chinachu WUI
		findLocalChinachuWUI()
    }

	// MARK: - View deinitialization
	override func viewWillDisappear(animated: Bool) {
		for browser in timeoutAction.keys {
			browser.stop()
		}
		super.viewWillDisappear(animated)
	}

	// MARK: - Memory/resource management
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }


	// MARK: - Table view data source

	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count + 1
	}

	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return 72
	}

	func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
		cell.separatorInset = UIEdgeInsetsZero
		cell.layoutMargins = UIEdgeInsetsZero
		cell.preservesSuperviewLayoutMargins = false
	}

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		if indexPath.row == dataSource.count {
			// Show loading cell
			let cell = UITableViewCell()
			cell.selectionStyle = .None
			let loadingView = SpringIndicator()
			loadingView.animating = true
			cell.layout(loadingView).center().size(width: 24, height: 24)
			return cell
		}
		
		let cell = tableView.dequeueReusableCellWithIdentifier("ChinachuWUIListTableViewCell", forIndexPath: indexPath) as! ChinachuWUIListTableViewCell

		let service = dataSource[indexPath.row]
		let url = "\(service.type.containsString("https") ? "https" : "http")://\(service.hostName!):\(service.port)"

		if let txtRecord = String(data: service.TXTRecordData()!, encoding: NSUTF8StringEncoding) {
			let locked = txtRecord.containsString("Password=true")
			cell.lockIcon.image = UIImage(named: locked ? "ic_lock" : "ic_lock_open")
		} else {
			cell.lockIcon.image = UIImage(named: "ic_lock_open")
		}

		cell.titleLabel?.text = service.name
		cell.detailLabel?.text = url

		return cell
	}

	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if indexPath.row == dataSource.count {
			return
		}
		let service = dataSource[indexPath.row]
		let url = "\(service.type.containsString("https") ? "https" : "http")://\(service.hostName!):\(service.port)"

		// Save values
		ChinachuAPI.wuiAddress = url

		dismissViewControllerAnimated(true, completion: nil)

		guard let navigationController = presentingViewController as? NavigationController else {
			return
		}
		guard let settingsTableViewController = navigationController.viewControllers.first as? SettingsTableViewController else {
			return
		}
		settingsTableViewController.reloadSettingsValue()
	}
	
	// MARK: - Initialization

	override init() {
		super.init()
	}

	convenience init(title: String) {
		self.init()
		_title = title
		self.contentView = UIView()
		self.tableView = UITableView()
		self.manualInputView = UIView()
		self.contentView.layout(self.tableView).edges()
		self.contentView.layout(self.manualInputView).edges()
		self.manualInputView.hidden = true
		self.modalPresentationStyle = .OverCurrentContext
		self.modalTransitionStyle = .CrossDissolve
	}
	
	internal required init?(coder aDecoder: NSCoder) {
		fatalError("init(coder:) has not been implemented")
	}

	// MARK: - Event handler
	func toggleAutoManualWUISelector() {
		self.alertView.divider = !self.alertView.divider
		tableView.hidden = !tableView.hidden
		manualInputView.hidden = !manualInputView.hidden
		if saveAction.hidden {
			saveAction.hidden = false
			self.alertView.rightButtons?.append(saveAction)
		} else {
			saveAction.hidden = true
			self.alertView.rightButtons?.popLast()
		}
	}

	// MARK: - Local mDNS Service browser

	func findLocalChinachuWUI() {
		let serviceBrowser = NSNetServiceBrowser()
		serviceBrowser.delegate = self
		timeoutAction[serviceBrowser] = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(stopBrowsering), userInfo: serviceBrowser, repeats: false)
		serviceBrowser.searchForBrowsableDomains()
	}

	func stopBrowsering(timer: NSTimer?) {
		timer?.userInfo?.stop()
	}

	func netServiceBrowser(browser: NSNetServiceBrowser, didFindService service: NSNetService, moreComing: Bool) {
		timeoutAction[browser]?.invalidate()

		service.delegate = self
		service.resolveWithTimeout(5)
		services.append(service)
	}

	func netServiceBrowser(browser: NSNetServiceBrowser, didFindDomain domainString: String, moreComing: Bool) {
		timeoutAction[browser]?.invalidate()

		let httpServiceBrowser = NSNetServiceBrowser()
		timeoutAction[httpServiceBrowser] = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(stopBrowsering), userInfo: httpServiceBrowser, repeats: false)
		httpServiceBrowser.delegate = self
		httpServiceBrowser.searchForServicesOfType("_http._tcp.", inDomain: domainString)

		let httpsServiceBrowser = NSNetServiceBrowser()
		timeoutAction[httpsServiceBrowser] = NSTimer.scheduledTimerWithTimeInterval(1, target: self, selector: #selector(stopBrowsering), userInfo: httpsServiceBrowser, repeats: false)
		httpsServiceBrowser.delegate = self
		httpsServiceBrowser.searchForServicesOfType("_https._tcp.", inDomain: domainString)
	}

	func netServiceDidResolveAddress(sender: NSNetService) {
		if let _ = sender.hostName {
			if sender.name.containsString("Chinachu on ") || sender.name.containsString("Chinachu Open Server on ") {
				// Don't store duplicated item
				for service in dataSource {
					if service.name == sender.name && service.hostName == sender.hostName && service.port == sender.port {
						return
					}
				}
				dataSource.append(sender)
				tableView.reloadData()
			}
		}
	}

	// MARK: - Text field delegate

	func textFieldShouldReturn(textField: UITextField) -> Bool {
		UIView.animateWithDuration(0.3, delay: 0, options: .CurveEaseInOut, animations: {
			self.alertView.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, 0)
			}, completion: nil)
		self.view.endEditing(false)
		return true
	}

	func textFieldShouldBeginEditing(textField: UITextField) -> Bool {
		UIView.animateWithDuration(0.3, delay: 0, options: .CurveEaseInOut, animations: {
			self.alertView.transform = CGAffineTransformTranslate(CGAffineTransformIdentity, 0, -100)
			}, completion: nil)
		return true
	}
}
