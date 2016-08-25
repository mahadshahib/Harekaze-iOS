/**
*
* DownloadsTableViewController.swift
* Harekaze
* Created by Yuki MIZUNO on 2016/08/21.
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
import RealmSwift
import Crashlytics

class DownloadsTableViewController: CommonProgramTableViewController, UITableViewDelegate, UITableViewDataSource {

	// MARK: - Private instance fileds
	private var dataSource: Results<(Download)>!

	// MARK: - View initialization

	override func viewDidLoad() {
		// On-filesystem persistent realm store
		var config = Realm.Configuration()
		config.fileURL = config.fileURL!.URLByDeletingLastPathComponent?.URLByAppendingPathComponent("downloads.realm")
		config.schemaVersion = 1
		config.migrationBlock = {migration, oldSchemeVersion in
			if oldSchemeVersion < 1 {
				Answers.logCustomEventWithName("Local realm store migration", customAttributes: ["migration": migration, "old version": Int(oldSchemeVersion), "new version": 1])
			}
		}

		// Delete uncompleted download program from realm
		let realm = try! Realm(configuration: config)
		let downloadUncompleted = realm.objects(Download).filter { $0.size == 0 && DownloadManager.sharedInstance.progressRequest($0.program!.id) == nil}
		if downloadUncompleted.count > 0 {
			try! realm.write {
				realm.delete(downloadUncompleted)
			}
		}

		// Table
		self.tableView.registerNib(UINib(nibName: "DownloadItemMaterialTableViewCell", bundle: nil), forCellReuseIdentifier: "DownloadItemCell")

		super.viewDidLoad()

		// Set empty view message
		if let emptyView = emptyView as? EmptyDataView {
			emptyView.messageLabel.text = "You have no downloads"
		}

		// Load downloaded program list from realm
		dataSource = realm.objects(Download)

		// Realm notification
		notificationToken = dataSource.addNotificationBlock(updateNotificationBlock())

		// Setup initial view state
		setupInitialViewState()

		// Refresh data stored list
		refreshDataSource()
	}

	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)

		// Set navigation title
		if let bottomNavigationController = self.navigationController!.viewControllers.first as? BottomNavigationController {
			bottomNavigationController.navigationItem.title = "Downloads"
		}
	}

	// MARK: - Resource updater

	override func refreshDataSource() {
		startLoading()
		endLoading()
	}

	// MARK: - Table view data source

	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell: DownloadItemMaterialTableViewCell = tableView.dequeueReusableCellWithIdentifier("DownloadItemCell", forIndexPath: indexPath) as! DownloadItemMaterialTableViewCell

		let item = dataSource[indexPath.row]
		cell.setCellEntities(download: item, navigationController: self.navigationController!)

		return cell
	}


	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return dataSource?.count ?? 0
	}


	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		if dataSource[indexPath.row].size == 0 {
			return
		}
		let programDetailViewController = self.storyboard!.instantiateViewControllerWithIdentifier("ProgramDetailTableViewController") as! ProgramDetailTableViewController

		programDetailViewController.program = dataSource[indexPath.row].program

		self.navigationController?.pushViewController(programDetailViewController, animated: true)
	}

}
