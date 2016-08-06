/**
 *
 * TimerItemMaterialTableViewCell.swift
 * Harekaze
 * Created by Yuki MIZUNO on 2016/08/02.
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

class TimerItemMaterialTableViewCell: ProgramItemMaterialTableViewCell {

	// MARK: - Interface Builder outlets
	@IBOutlet weak var warningImageView: UIImageView!
	@IBOutlet weak var warningImageConstraintWidth: NSLayoutConstraint!
	@IBOutlet weak var recordTypeImageView: UIImageView!


	// MARK: - Entity setter
	override func setCellEntities(program: Program, navigationController: UINavigationController? = nil) {
		super.setCellEntities(program)

		guard let timer = program as? Timer else { return }

		if timer.skip {
			let disabledColor = MaterialColor.darkText.others
			titleLabel.textColor = disabledColor
			broadcastInfoLabel.textColor = disabledColor
			programDetailLabel.textColor = disabledColor
			durationLabel.textColor = disabledColor
			warningImageView.tintColor = disabledColor
			recordTypeImageView.tintColor = disabledColor
		}

		if timer.conflict {
			warningImageView.image = UIImage(named: "ic_warning")?.imageWithRenderingMode(.AlwaysTemplate)
			warningImageConstraintWidth.constant = 24
		} else {
			warningImageView.hidden = true
			warningImageConstraintWidth.constant = 0
		}

		if timer.manual {
			recordTypeImageView.image = UIImage(named: "ic_fiber_manual_record")?.imageWithRenderingMode(.AlwaysTemplate)
		} else {
			recordTypeImageView.image = UIImage(named: "ic_fiber_smart_record")?.imageWithRenderingMode(.AlwaysTemplate)
		}
	}


	// MARK: - Reuse preparation
	override func prepareForReuse() {
		super.prepareForReuse()
		titleLabel.textColor = MaterialColor.darkText.primary
		broadcastInfoLabel.textColor = MaterialColor.darkText.secondary
		programDetailLabel.textColor = MaterialColor.darkText.secondary
		durationLabel.textColor = MaterialColor.darkText.secondary
		warningImageView.tintColor = MaterialColor.red.accent2
		recordTypeImageView.tintColor = MaterialColor.darkText.secondary
	}
}
