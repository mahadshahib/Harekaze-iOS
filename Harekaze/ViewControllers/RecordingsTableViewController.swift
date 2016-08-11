/**
 *
 * RecordingsTableViewController.swift
 * Harekaze
 * Created by Yuki MIZUNO on 2016/07/10.
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
import APIKit
import CarbonKit
import StatefulViewController
import DropDown
import RealmSwift

class RecordingsTableViewController: UIViewController, StatefulViewController, UITableViewDelegate, UITableViewDataSource {

	// MARK: - Private instance fileds
	private var dataSource: Results<(Program)>!
	private var refresh: CarbonSwipeRefresh!
	private var controlView: ControlView!
	private var controlViewLabel: UILabel!
	private var notificationToken: NotificationToken?

	// MARK: - Interface Builder outlets
	@IBOutlet weak var tableView: UITableView!


	// MARK: - View initialization

	override func viewDidLoad() {
		super.viewDidLoad()

		// Set stateful views
		loadingView = NSBundle.mainBundle().loadNibNamed("DataLoadingView", owner: self, options: nil).first as? UIView
		emptyView = NSBundle.mainBundle().loadNibNamed("EmptyDataView", owner: self, options: nil).first as? UIView
		if let emptyView = emptyView as? EmptyDataView {
			emptyView.messageLabel.text = "You have no recordings"
			emptyView.reloadButton.setTitleColor(MaterialColor.blue.accent1, forState: .Normal)
			emptyView.reloadButton.pulseColor = MaterialColor.blue.accent3
			emptyView.action = { (sender: FlatButton) in
				self.refreshDataSource()
			}
		}
		errorView = NSBundle.mainBundle().loadNibNamed("EmptyDataView", owner: self, options: nil).first as? UIView
		if let errorView = errorView as? EmptyDataView {
			errorView.reloadButton.setTitleColor(MaterialColor.red.accent1, forState: .Normal)
			errorView.reloadButton.pulseColor = MaterialColor.red.accent3
			errorView.y467ImageView.transform = CGAffineTransformMakeRotation(-15 * CGFloat(M_PI/180)) // list Y467
			errorView.action = { (sender: FlatButton) in
				self.refreshDataSource()
			}
		}

		// Set refresh controll
		refresh = CarbonSwipeRefresh(scrollView: self.tableView)
		refresh.setMarginTop(0)
		refresh.colors = [MaterialColor.blue.base, MaterialColor.red.base, MaterialColor.orange.base, MaterialColor.green.base]
		self.view.addSubview(refresh)
		refresh.addTarget(self, action:#selector(refreshDataSource), forControlEvents: .ValueChanged)

		// Load recording program list to realm
		let realm = try! Realm()
		dataSource = realm.objects(Program).sorted("startTime", ascending: false)

		// Setup initial view state
		setupInitialViewState()

		// Refresh data stored list
		refreshDataSource()

		// Realm notification
		notificationToken = dataSource.addNotificationBlock { [weak self] (changes: RealmCollectionChange) in
			guard let tableView = self?.tableView else { return }
			switch changes {
			case .Initial:
				tableView.reloadData()
			case .Update(_, let deletions, let insertions, _):
				if insertions.count == self?.dataSource.count {
					tableView.reloadData()
				} else {
					tableView.beginUpdates()
					tableView.insertRowsAtIndexPaths(insertions.map { NSIndexPath(forRow: $0, inSection: 0) }, withRowAnimation: .Right)
					tableView.deleteRowsAtIndexPaths(deletions.map { NSIndexPath(forRow: $0, inSection: 0) }, withRowAnimation: .Left)
					tableView.endUpdates()
				}
				self?.endLoading()
			case .Error(let error):
				fatalError("\(error)")
			}
		}

		// Table
		self.tableView.registerNib(UINib(nibName: "ProgramItemMaterialTableViewCell", bundle: nil), forCellReuseIdentifier: "ProgramItemCell")

		tableView.separatorStyle = .SingleLine
		tableView.separatorInset = UIEdgeInsetsZero

		// Control view
		let retryButton: FlatButton = FlatButton()
		retryButton.pulseColor = MaterialColor.white
		retryButton.setTitle("RETRY", forState: .Normal)
		retryButton.setTitleColor(MaterialColor.blue.accent1, forState: .Normal)
		retryButton.addTarget(self, action: #selector(retryRefreshDataSource), forControlEvents: .TouchUpInside)

		controlViewLabel = UILabel()
		controlViewLabel.text = "Error"
		controlViewLabel.textColor = MaterialColor.white

		controlView = ControlView(rightControls: [retryButton])
		controlView.backgroundColor = MaterialColor.grey.darken4
		controlView.contentInsetPreset = .WideRectangle3
		controlView.contentView.addSubview(controlViewLabel)
		controlView.contentView.grid.views = [controlViewLabel]

		view.layout(controlView).bottom(-56).horizontally().height(56)
		controlView.hidden = true
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		// Set navigation title
		let navigationItem = (self.navigationController!.viewControllers.first as! BottomNavigationController).navigationItem

		navigationItem.title = "Recordings"
		navigationItem.titleLabel.textAlignment = .Left
		navigationItem.titleLabel.font = RobotoFont.mediumWithSize(20)
		navigationItem.titleLabel.textColor = MaterialColor.white
	}

	override func viewDidAppear(animated: Bool) {
		super.viewDidAppear(animated)

		// Close navigation drawer
		navigationDrawerController?.closeLeftView()
		navigationDrawerController?.enabled = true
	}

	// MARK: - Deinitialization
	deinit {
		notificationToken?.stop()
	}

	// MARK: - Memory/resource management

	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
	}

	// MARK: - Resource updater

	internal func refreshDataSource() {
		if lastState == .Loading {
			return
		}

		startLoading()
		UIApplication.sharedApplication().networkActivityIndicatorVisible = true

		let request = ChinachuAPI.RecordingRequest()
		Session.sendRequest(request) { result in
			switch result {
			case .Success(let data):
				// Store recording program list to realm
				dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0)) {
					let realm = try! Realm()
					try! realm.write {
						realm.add(data, update: true)
						let objectsToDelete = realm.objects(Program).filter { data.indexOf($0) == nil }
						realm.delete(objectsToDelete)
					}
					dispatch_async(dispatch_get_main_queue()) {
						self.refresh.endRefreshing()
						UIApplication.sharedApplication().networkActivityIndicatorVisible = false
					}
				}

			case .Failure(let error):
				print("error: \(error)")
				if let errorView = self.errorView as? EmptyDataView {
					errorView.messageLabel.text = self.parseErrorMessage(error)
				}
				self.refresh.endRefreshing()
				self.endLoading(error: error)
				UIApplication.sharedApplication().networkActivityIndicatorVisible = false
			}
		}
	}

	func retryRefreshDataSource() {
		refresh.startRefreshing()
		refreshDataSource()
		closeControlView()
	}

	// MARK: - Control view

	func closeControlView() {
		for gestureRecognizer in controlView.contentView.gestureRecognizers! {
			controlView.contentView.removeGestureRecognizer(gestureRecognizer)
		}
		controlView.animate(MaterialAnimation.translateY(56, duration: 0.3))

		// TODO: - Dispatch after
		//		controlView.hidden = true

	}

	func showControlView() {
		let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(closeControlView))
		controlView.contentView.addGestureRecognizer(tapGestureRecognizer)
		NSTimer.scheduledTimerWithTimeInterval(10, target: self, selector: #selector(closeControlView), userInfo: nil, repeats: false)
		controlView.hidden = false
		controlView.animate(MaterialAnimation.translateY(-56, duration: 0.3))
	}

	// MARK: - Error parser

	func parseErrorMessage(error: ErrorType) -> String {
		switch error as! SessionTaskError {
		case .ConnectionError(let error as NSError):
			return error.localizedDescription
		case .RequestError(let error as NSError):
			return error.localizedDescription
		case .ResponseError(let error as NSError):
			return error.localizedDescription
		case .ConnectionError:
			return "Connection error."
		case .RequestError:
			return "Request error."
		case .ResponseError:
			return "Response error."
		}
	}

	// MARK: - Stateful view controller

	func hasContent() -> Bool {
		return dataSource.count > 0
	}

	func handleErrorWhenContentAvailable(error: ErrorType) {
		controlViewLabel.text = parseErrorMessage(error)
		showControlView()
	}

	// MARK: - Table view data source


	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}

	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource.count
	}


	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell: ProgramItemMaterialTableViewCell = tableView.dequeueReusableCellWithIdentifier("ProgramItemCell", forIndexPath: indexPath) as! ProgramItemMaterialTableViewCell

		let item = dataSource[indexPath.row]
		cell.setCellEntities(item, navigationController: self.navigationController)

		return cell
	}


	func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
		return 88
	}


	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		let programDetailViewController = self.storyboard!.instantiateViewControllerWithIdentifier("ProgramDetailTableViewController") as! ProgramDetailTableViewController

		programDetailViewController.program = dataSource[indexPath.row]
		
		self.navigationController?.pushViewController(programDetailViewController, animated: true)
	}
	
}
