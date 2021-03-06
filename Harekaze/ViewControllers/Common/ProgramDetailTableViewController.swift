/**
 *
 * ProgramDetailTableViewController.swift
 * Harekaze
 * Created by Yuki MIZUNO on 2016/07/12.
 * 
 * Copyright (c) 2016-2018, Yuki MIZUNO
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
import Kingfisher
import APIKit
import RealmSwift
import Crashlytics
import Alamofire
import Hero
import FileKit
import iTunesSearchAPI
import ObjectMapper
import StoreKit
import StatusAlert
import CoreSpotlight

class ProgramDetailTableViewController: UITableViewController, UIGestureRecognizerDelegate {

	// MARK: - Instance fileds
	var program: Program! = nil

	var timer: Timer? {
		let realm = try! Realm()
		let predicate = NSPredicate(format: "id == %@", program.id)
		return realm.objects(Timer.self).filter(predicate).first
	}
	var recording: Recording? {
		if let download = self.download {
			return download.recording
		}
		let realm = try! Realm()
		let predicate = NSPredicate(format: "id == %@", program.id)
		return realm.objects(Recording.self).filter(predicate).first
	}
	// MARK: - Private instance fileds
	private var download: Download? {
		let config = Realm.configuration(class: Download.self)
		let realm = try! Realm(configuration: config)
		let predicate = NSPredicate(format: "id == %@", program.id)
		return realm.objects(Download.self).filter(predicate).first
	}
	private var dataSource: [[String: String]] = []
	private var rowHeight: [Int: CGFloat] = [:]
	private var programDescription: String = ""
	private var artworkDataSource: ArtworkCollectionDataSource = ArtworkCollectionDataSource()

	// MARK: - IBOutlets
	@IBOutlet weak var headerView: UIView!
	@IBOutlet weak var titleLabel: UILabel! {
		didSet {
			titleLabel.preferredMaxLayoutWidth = 50
			titleLabel.numberOfLines = 0
		}
	}
	@IBOutlet weak var dateLabel: UILabel!
	@IBOutlet weak var channelLogoImage: UIImageView!
	@IBOutlet weak var thumbnailCollectionView: UICollectionView!
	@IBOutlet weak var playButton: UIButton! {
		didSet {
			playButton.imageView?.contentMode = .scaleAspectFit
			playButton.imageEdgeInsets = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
			playButton.titleLabel?.adjustsFontSizeToFitWidth = true
		}
	}
	@IBOutlet weak var channelLabel: UILabel!
	@IBOutlet weak var footerView: UIView!
	@IBOutlet weak var artworkCollectionView: UICollectionView! {
		didSet {
			artworkCollectionView.delegate = artworkDataSource
			artworkCollectionView.dataSource = artworkDataSource
		}
	}
	@IBOutlet weak var nothingFoundLabel: UILabel!

	// MARK: - View initialization

	override func viewDidLoad() {
		super.viewDidLoad()
		self.extendedLayoutIncludesOpaqueBars = false
		self.navigationItem.largeTitleDisplayMode = .never
		self.navigationController?.interactivePopGestureRecognizer?.delegate = self

		self.tableView.tableHeaderView = headerView
		self.tableView.tableFooterView = footerView
		self.tableView.estimatedRowHeight = 51

		channelLabel.text = program.channel!.name
		setChannelLogo()

		// Header Label
		self.titleLabel.text = program.title
		self.dateLabel.text = "\(program.startTime.string(dateStyle: .short, timeStyle: .short)) (\(program.duration.in(.minute)!)min)"

		self.tableView.reloadData()
		self.searchItunesItem(title: program.title)

		// Setup table view data source
		programDescription = program.detail
		dataSource.append(["Genre": program.genre.capitalized])
		dataSource.append(["Date": program.startTime.string()])
		if program.episode > 0 {
			dataSource.append(["Episode": "Ep \(program.episode)"])
		}
		if !program.attributes.isEmpty {
			dataSource.append(["Attributes": program.attributedAttributes.joined(separator: " ")])
		}
		dataSource.append(["Channel": "\(program.channel!.name) [\(program.channel!.channel)]"])
		dataSource.append(["Duration": "\(program.duration.in(.minute)!) min."])
		dataSource.append(["ID": program.id.uppercased()])
		dataSource.append(["Title": program.attributedFullTitle])
		if let download = self.download {
			dataSource.append(["Size": download.humanReadableSize()])
		}
		guard let recording = self.recording else {
			self.headerView.frame.size.height -= self.thumbnailCollectionView.frame.height
			self.thumbnailCollectionView.isHidden = true
			if download == nil {
				setButtonTitleAndImage()
			}
			return
		}
		dataSource.append(["Tuner": recording.tuner])
		dataSource.append(["File": recording.filePath])
		dataSource.append(["Command": recording.command])
	}

	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		UIApplication.shared.statusBarStyle = .default
		if let navigationController = self.navigationController as? TransitionableTintColorNavigationController {
			navigationController.toWhiteNavbar()
		}

		// Set navigation bar transparent background
		self.navigationController?.navigationBar.shadowImage = UIImage()
	}

	override func viewDidAppear(_ animated: Bool) {
		super.viewDidAppear(animated)
		self.view.backgroundColor = .white
		if let navigationController = self.navigationController as? TransitionableTintColorNavigationController {
			navigationController.toWhiteNavbar()
		}
	}

	// MARK: - button label setter

	func setButtonTitleAndImage() {
		guard let timer = self.timer else {
			self.playButton.setTitle("Reserve", for: .normal)
			self.playButton.setImage(#imageLiteral(resourceName: "plus"), for: .normal)
			return
		}

		if timer.skip {
			self.playButton.setTitle("Skipped", for: .normal)
			self.playButton.setImage(#imageLiteral(resourceName: "info"), for: .normal)
		} else if timer.conflict {
			self.playButton.setTitle("Conflicted", for: .normal)
			self.playButton.setImage(#imageLiteral(resourceName: "error"), for: .normal)
		} else {
			self.playButton.setTitle("Reserved", for: .normal)
			self.playButton.setImage(#imageLiteral(resourceName: "ok"), for: .normal)
		}
	}

	// MARK: - Channel logo setter
	func setChannelLogo() {
		do {
			let request = ChinachuAPI.ChannelLogoImageRequest(id: program.channel!.id)
			let urlRequest = try request.buildURLRequest()

			self.channelLogoImage.kf.setImage(with: urlRequest.url!,
											  options: [.transition(ImageTransition.fade(0.3)),
														.requestModifier(AnyModifier(modify: { request in
															var request = request
															request.setValue(urlRequest.allHTTPHeaderFields?["Authorization"], forHTTPHeaderField: "Authorization")
															return request
														}
														))])
		} catch let error {
			Answers.logCustomEvent(withName: "Channel logo load error", customAttributes: ["error": error])
		}
	}

	// MARK: - iTunes Search
	func searchItunesItem(title: String) {
		let itunes = iTunes()
		itunes.search(for: title, ofType: .music(.musicTrack), options: Options(country: .japan, limit: 20, language: .japanese, includeExplicitContent: false)) { result in
			if result.error == nil {
				guard let json = result.value as? [String: Any],
					let dict = json["results"] as? [[String: Any]] else {
					return
				}
				let tracks = dict.map { Mapper<iTunesTrack>().map(JSONObject: $0) }.flatMap { $0! }
				if !tracks.isEmpty {
					self.artworkDataSource.set(items: tracks, navigationController: self.navigationController)
					self.artworkCollectionView.reloadData()
				} else {
					self.nothingFoundLabel.isHidden = false
				}
			} else {
				self.nothingFoundLabel.isHidden = false
			}
		}
	}

	// MARK: - IBAction

	@IBAction func touchPlayButton() {
		if recording != nil || download != nil {
			showVideoPlayerView()
			return
		}
		guard let timer = self.timer else {
			ChinachuAPI.TimerAddRequest(id: program.id).send { result in
				switch result {
				case .success:
					let timer = Timer()
					let realm = try! Realm()
					try! realm.write {
						timer.id = self.program.id
						timer.program = self.program
						timer.manual = true
						realm.add(timer, update: true)
					}
					self.setButtonTitleAndImage()
				case .failure(let error):
					StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "error"),
											title: "Error",
											message: ChinachuAPI.parseErrorMessage(error),
											canBePickedOrDismissed: false).showInKeyWindow()
				}
			}
			return
		}
		if timer.manual {
			let confirmDialog = AlertController("Delete timer?",
												  "Are you sure you want to delete the timer \(timer.program!.fullTitle)?")
			confirmDialog.addAction(AlertButton(.default, title: "DELETE")) {
				ChinachuAPI.TimerDeleteRequest(id: timer.id).send { result in
					switch result {
					case .success:
						let realm = try! Realm()
						try! realm.write {
							realm.delete(timer)
						}
						self.navigationController?.popViewController(animated: true)
					case .failure(let error):
						StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "error"),
												title: "Delete timer failed",
												message: ChinachuAPI.parseErrorMessage(error),
												canBePickedOrDismissed: false).showInKeyWindow()
					}
				}
			}
			confirmDialog.addAction(AlertButton(.cancel, title: "CANCEL")) {}
			confirmDialog.show()
			return
		}
		if timer.skip {
			ChinachuAPI.TimerUnskipRequest(id: timer.id).send { result in
				switch result {
				case .success:
					let realm = try! Realm()
					try! realm.write {
						timer.skip = false
					}
					self.setButtonTitleAndImage()
				case .failure(let error):
					StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "error"),
											title: "Error",
											message: ChinachuAPI.parseErrorMessage(error),
											canBePickedOrDismissed: false).showInKeyWindow()
				}
			}
		} else {
			ChinachuAPI.TimerSkipRequest(id: timer.id).send { result in
				switch result {
				case .success:
					let realm = try! Realm()
					try! realm.write {
						timer.skip = true
					}
					self.setButtonTitleAndImage()
				case .failure(let error):
					StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "error"),
											title: "Error",
											message: ChinachuAPI.parseErrorMessage(error),
											canBePickedOrDismissed: false).showInKeyWindow()
				}
			}
		}
	}

	@IBAction func touchMoreButton(_ sender: UIButton) {
		let confirmDialog = AlertController("More...")
		confirmDialog.addAction(AlertButton(.default, title: "Share")) {
			let text: String
			let title: String = "\(self.program.title)\(self.program.episode > 0 ? " Ep.\(self.program.episode)" : "") \(self.program.subTitle)"
			if self.recording != nil {
				text = "Watching 『\(title)』 via @HarekazeApp"
			} else if self.timer != nil {
				text = "Checking reserved 『\(title)』 via @HarekazeApp"
			} else {
				text = "Checking upcoming 『\(title)』 via @HarekazeApp"
			}
			let activityViewController = UIActivityViewController(activityItems: [text], applicationActivities: nil)
			activityViewController.excludedActivityTypes = [
				UIActivityType(rawValue: "com.apple.reminders.RemindersEditorExtension"),
				UIActivityType(rawValue: "com.apple.mobilenotes.SharingExtension"),
				.airDrop, .saveToCameraRoll, .print, .markupAsPDF]
			activityViewController.popoverPresentationController?.sourceView = sender
			self.present(activityViewController, animated: true, completion: nil)
		}
		if recording != nil {
			confirmDialog.addAction(AlertButton(.default, title: "Delete")) {
				self.confirmDeleteProgram()
			}
			if download == nil {
				confirmDialog.addAction(AlertButton(.default, title: "Download")) {
					self.startDownloadVideo()
				}
			} else {
				let progress = DownloadManager.shared.progressRequest(recording!.id)
				if progress == nil || progress?.fractionCompleted == 1.0 {
					confirmDialog.addAction(AlertButton(.default, title: "Delete Downloaded")) {
						self.confirmDeleteDownloaded()
					}
				}
			}
		}
		confirmDialog.addAction(AlertButton(.cancel, title: "Cancel")) {}
		confirmDialog.show()
	}

	// MARK: - Event handler

	func confirmDeleteProgram() {
		let confirmDialog = AlertController("Delete program?", "Are you sure you want to permanently delete the program \(self.program.fullTitle) immediately?")
		confirmDialog.addAction(AlertButton(.default, title: "DELETE")) {
			ChinachuAPI.RecordingDeleteRequest(id: self.program.id).send { result in
				switch result {
				case .success:
					if self.download == nil {
						for row in 0..<5 {
							ImageCache.default.removeImage(forKey: "\(self.program.id)-\(row)")
						}
					}
					let realm = try! Realm()
					try! realm.write {
						realm.delete(self.recording!)
					}
					self.navigationController?.popViewController(animated: true)
				case .failure(let error):
					StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "error"),
											title: "Delete program failed",
											message: ChinachuAPI.parseErrorMessage(error),
											canBePickedOrDismissed: false).showInKeyWindow()
				}
			}
		}
		confirmDialog.addAction(AlertButton(.cancel, title: "Cancel")) {}
		confirmDialog.show()
	}

	func showVideoPlayerView() {
		guard let videoPlayViewController = self.storyboard!.instantiateViewController(withIdentifier: "VideoPlayerViewController") as?
			VideoPlayerViewController else {
			return
		}
		videoPlayViewController.recording = recording
		videoPlayViewController.download = download
		videoPlayViewController.transitioningDelegate = self as? UIViewControllerTransitioningDelegate
		self.present(videoPlayViewController, animated: true, completion: nil)
	}

	// MARK: - Program download

	func startDownloadVideo() {
		do {
			// Define local store file path
			let filepath = Path.userDocuments + "\(program.id).m2ts"

			// Add downloaded program to realm
			let config = Realm.configuration(class: Download.self)
			let realm = try Realm(configuration: config)
			let download = Download()
			try realm.write {
				download.id = program!.id
				download.recording = realm.create(Recording.self, value: self.recording!, update: true)
				realm.add(download, update: true)
			}

			// Download request
			let request = ChinachuAPI.StreamingMediaRequest(id: program.id)
			let urlRequest = try request.buildURLRequest()
			let manager = DownloadManager.shared.createManager(program.id)

			let downloadRequest = manager.download(urlRequest) { (_, _) in
				(filepath.url, [])
				}
				.response { response in
					if let error = response.error {
						Answers.logCustomEvent(withName: "Download file failed",
							customAttributes: ["error": error, "path": filepath, "request": response.request as Any, "response": response.response as Any])
					} else {
						try! realm.write {
							download.size = Int64(filepath.fileSize ?? 0)
						}
						Answers.logCustomEvent(withName: "File download info", customAttributes: [
							"file size": download.size,
							"transcode": ChinachuAPI.Config[.transcode]
							])
						let searchItem: CSSearchableItem = {
							let attributeSet = download.recording!.program!.attributeSet
							attributeSet.downloadedDate = Date()
							attributeSet.local = 1
							attributeSet.thumbnailURL = URL(fileURLWithPath: ImageCache.default.cachePath(forKey: "\(download.id)-0",
								processorIdentifier: DefaultImageProcessor.default.identifier))
							return CSSearchableItem(uniqueIdentifier: "\(download.id)-local", domainIdentifier: "download", attributeSet: attributeSet)
						}()
						CSSearchableIndex.default().indexSearchableItems([searchItem]) { error in
							if let error = error {
								Answers.logCustomEvent(withName: "CSSearchableIndex indexing failed", customAttributes: ["error": error])
							}
						}
					}
			}
			// Show dialog
			StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "download"),
									title: "The download has started",
									message: "Download progress is available at Download page.",
									canBePickedOrDismissed: true).showInKeyWindow()

			// Save request
			DownloadManager.shared.addRequest(program.id, request: downloadRequest, cancelAction: {})
		} catch let error as NSError {
			// Show dialog
			StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "error"),
									title: "Download failed",
									message: error.localizedDescription,
									canBePickedOrDismissed: false).showInKeyWindow()
			Answers.logCustomEvent(withName: "File download error", customAttributes: ["error": error])
		}
	}

	func confirmDeleteDownloaded() {
		let confirmDialog = AlertController("Delete downloaded program?", "Are you sure you want to delete downloaded program \(program!.fullTitle)?")
		confirmDialog.addAction(AlertButton(.default, title: "DELETE")) {
			let filepath = Path.userDocuments + "\(self.download!.id).m2ts"

			do {
				try filepath.deleteFile()

				// Remove thumbnail from disk when it's not available on recording
				let predicate = NSPredicate(format: "id == %@", self.download!.id)
				if try! Realm().objects(Recording.self).filter(predicate).first == nil {
					for row in 0..<5 {
						ImageCache.default.removeImage(forKey: "\(self.download!.id)-\(row)")
					}
				}
				// Remove search index
				CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ["\(self.download!.id)-local"]) { error in
					if let error = error {
						Answers.logCustomEvent(withName: "CSSearchableIndex indexing failed", customAttributes: ["error": error])
					}
				}
				// Delete downloaded program from realm
				let config = Realm.configuration(class: Download.self)
				let realm = try! Realm(configuration: config)
				try! realm.write {
					realm.delete(self.download!)
				}
				if let previous = self.navigationController?.viewControllers.first {
					if String(describing: type(of: previous)) == "DownloadsTableViewController" {
						self.navigationController?.popViewController(animated: true)
					}
				}
			} catch let error as NSError {
				Answers.logCustomEvent(withName: "Delete downloaded program error", customAttributes: ["error": error])
				StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "error"),
										title: "Delete downloaded program failed",
										message: error.localizedDescription,
										canBePickedOrDismissed: false).showInKeyWindow()
			}
		}
		confirmDialog.addAction(AlertButton(.cancel, title: "CANCEL")) {}
		self.navigationController?.parent?.present(confirmDialog, animated: false) {}
	}

	// MARK: - View deinitialization

	override func viewWillDisappear(_ animated: Bool) {
		super.viewWillDisappear(animated)
		UIApplication.shared.statusBarStyle = .lightContent
	}

	deinit {
		NotificationCenter.default.removeObserver(self)
	}

	// MARK: - Rotation

	override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
		return .portrait
	}

	// MARK: - Table view data source

	override func numberOfSections(in tableView: UITableView) -> Int {
		return 3
	}

	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		switch section {
		case 0, 1:
			return 1
		case 2:
			return dataSource.count
		default:
			fatalError("Must not reachable")
		}
	}

	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		switch indexPath.section {
		case 0:
			let cell = tableView.dequeueReusableCell(withIdentifier: "DescriptionCell", for: indexPath)
			cell.textLabel?.text = programDescription
			return cell
		case 1:
			let cell = tableView.dequeueReusableCell(withIdentifier: "TitleCell", for: indexPath)
			cell.textLabel?.text = "Information"
			cell.separatorInset.right = .greatestFiniteMagnitude
			return cell
		case 2:
			let data = dataSource[indexPath.row].first!
			let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell", for: indexPath)
			let labelHeight = cell.detailTextLabel?.frame.height ?? 0
			cell.textLabel?.text = data.0
			cell.detailTextLabel?.text = data.1
			cell.layoutSubviews()
			let height = (cell.detailTextLabel?.frame.height ?? 0) - labelHeight
			if height > 0 {
				rowHeight[indexPath.row] = height + tableView.estimatedRowHeight
			}
			return cell
		default:
			fatalError("Must not reachable")
		}
	}

	override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
		switch indexPath.section {
		case 0:
			return UITableViewAutomaticDimension
		case 1:
			return 52
		case 2:
			return rowHeight[indexPath.row, default: UITableViewAutomaticDimension]
		default:
			fatalError("Must not reachable")
		}
	}
}

extension ProgramDetailTableViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return 5
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
		let width = self.view.frame.width * 0.88
		let height = width / 16 * 9
		return CGSize(width: width, height: height)
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
		return self.view.frame.width * 0.12
	}

	func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
		return UIEdgeInsets(top: 0, left: self.view.frame.width * 0.06, bottom: 0, right: self.view.frame.width * 0.06)
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let thumbnailCell = collectionView.dequeueReusableCell(withReuseIdentifier: "thumbnailCell", for: indexPath)
		let imageView = thumbnailCell.viewWithTag(2) as? UIImageView
		do {
			let segment = program.duration.in(.second)! / self.collectionView(self.thumbnailCollectionView, numberOfItemsInSection: indexPath.section)
			let request = ChinachuAPI.PreviewImageRequest(id: program.id, position: segment * indexPath.row + segment)
			let urlRequest = try request.buildURLRequest()

			// Loading
			let resource = ImageResource(downloadURL: urlRequest.url!, cacheKey: "\(program.id)-\(indexPath.row)")
			imageView?.kf.setImage(with: resource,
								  options: [.transition(ImageTransition.fade(0.3)),
											.forceTransition,
											.requestModifier(AnyModifier(modify: { request in
												var request = request
												request.setValue(urlRequest.allHTTPHeaderFields?["Authorization"], forHTTPHeaderField: "Authorization")
												return request
											}
											))],
								  completionHandler: {(image, error, _, _) in
									if error != nil {
										return
									}
									if let image = image {
										ImageCache.default.store(image, forKey: "\(self.program.id)-\(indexPath.row)", toDisk: true)
									}
			})

		} catch let error as NSError {
			Answers.logCustomEvent(withName: "Thumbnail load error", customAttributes: ["error": error])
		}
		return thumbnailCell
	}
}

class ArtworkCollectionDataSource: NSObject, UICollectionViewDelegate, UICollectionViewDataSource, SKStoreProductViewControllerDelegate, UIGestureRecognizerDelegate {
	var items: [iTunesTrack] = []
	var navigationController: UINavigationController?

	func set(items: [iTunesTrack], navigationController: UINavigationController?) {
		self.items = items
		self.navigationController = navigationController
	}

	func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
		return items.count
	}

	func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
		let thumbnailCell = collectionView.dequeueReusableCell(withReuseIdentifier: "artworkCell", for: indexPath)
		let imageView = thumbnailCell.viewWithTag(2) as? UIImageView
		let titleLabel = thumbnailCell.viewWithTag(3) as? UILabel
		let artistLabel = thumbnailCell.viewWithTag(4) as? UILabel

		let track = items[indexPath.row]
		titleLabel?.text = track.name
		artistLabel?.text = track.artist

		// Loading
		imageView?.kf.setImage(with: URL(string: track.artworkUrl),
							   options: [.transition(ImageTransition.fade(0.3)), .forceTransition])
		let tapArtwork = UITapGestureRecognizer(target: self, action: #selector(ArtworkCollectionDataSource.openStoreView(_:)))
		tapArtwork.delegate = self
		thumbnailCell.addGestureRecognizer(tapArtwork)
		thumbnailCell.tag = indexPath.row
		return thumbnailCell
	}

	@objc func openStoreView(_ sender: UITapGestureRecognizer) {
		guard let row = sender.view?.tag else {
			return
		}
		let track = items[row]
		let store = SKStoreProductViewController()
		store.delegate = self

		let itemId = track.id
		let param = [SKStoreProductParameterITunesItemIdentifier: "\(itemId)", SKStoreProductParameterAffiliateToken: "1l3v4mQ"]
		store.loadProduct(withParameters: param) { success, error in
			if !success {
				store.presentingViewController?.dismiss(animated: true, completion: nil)
				StatusAlert.instantiate(withImage: #imageLiteral(resourceName: "error"),
										title: "Not Found",
										message: "The item is not available on the Store.\n\(String(describing: error!.localizedDescription))",
										canBePickedOrDismissed: false).showInKeyWindow()
				Answers.logCustomEvent(withName: "Open store failed", customAttributes: ["error": error])
			}
		}
		self.navigationController?.present(store, animated: true, completion: nil)
	}

	func productViewControllerDidFinish(_ viewController: SKStoreProductViewController) {
		viewController.presentingViewController?.dismiss(animated: true, completion: nil)
	}
}

// MARK: - UIViewControllerPreviewingDelegate

extension ProgramDetailTableViewController: UIViewControllerPreviewingDelegate {
	func previewingContext(_ previewingContext: UIViewControllerPreviewing, viewControllerForLocation location: CGPoint) -> UIViewController? {
		return nil
	}

	func previewingContext(_ previewingContext: UIViewControllerPreviewing, commit viewControllerToCommit: UIViewController) {
	}

	override var previewActionItems: [UIPreviewActionItem] {
		var actions: [UIPreviewActionItem] = []
		let actionTitle: String
		if recording != nil {
			actionTitle = "Play"
		} else if let timer = self.timer {
			if timer.skip {
				actionTitle = "Un-skip timer"
			} else if timer.conflict {
				actionTitle = "Delete timer"
			} else if timer.manual {
				actionTitle = "Delete timer"
			} else {
				actionTitle = "Skip timer"
			}
		} else {
			actionTitle = "Reserve program"
		}

		let mainAction = UIPreviewAction(title: actionTitle, style: actionTitle == "Delete timer" ? .destructive : .default) { (previewAction, viewController) in
			switch previewAction.title {
			case "Play":
				guard let videoPlayViewController = self.storyboard!.instantiateViewController(withIdentifier: "VideoPlayerViewController") as? VideoPlayerViewController else {
					return
				}
				videoPlayViewController.recording = self.recording
				videoPlayViewController.modalPresentationStyle = .custom
				if let delegate = UIApplication.shared.delegate as? AppDelegate {
					delegate.window?.rootViewController?.present(videoPlayViewController, animated: true, completion: nil)
				}
			default:
				self.touchPlayButton()
			}
		}
		actions.append(mainAction)
		if recording != nil {
			let deleteAction = UIPreviewAction(title: "Delete", style: .destructive) { (previewAction, viewController) in
				self.confirmDeleteProgram()
			}
			actions.append(deleteAction)
			if download == nil {
				let downloadAction = UIPreviewAction(title: "Download", style: .default) { (previewAction, viewController) in
					self.startDownloadVideo()
				}
				actions.append(downloadAction)
			}
		}

		return actions
	}
}
