/**
 *
 * TransitionableTintColorNavigationController.swift
 * Harekaze
 * Created by Yuki MIZUNO on 2018/01/30.
 *
 * Copyright (c) 2016-2018, Yuki MIZUNO
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions are met:
 *
 * 1. Redistributions of source code must retain the above copyright notice,
 *	this list of conditions and the following disclaimer.
 *
 * 2. Redistributions in binary form must reproduce the above copyright notice,
 *	this list of conditions and the following disclaimer in the documentation
 *	 and/or other materials provided with the distribution.
 *
 * 3. Neither the name of the copyright holder nor the names of its contributors
 *	may be used to endorse or promote products derived from this software
 *	without specific prior written permission.
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

class TransitionableTintColorNavigationController: UINavigationController {
	func toWhiteNavbar() {
		self.navigationBar.barTintColor = .white
		self.navigationBar.tintColor = UIColor(named: "main")
	}

	func toMainColorNavbar() {
		self.navigationBar.barTintColor = UIColor(named: "main")
		self.navigationBar.tintColor = .white
	}

	override open func pushViewController(_ viewController: UIViewController, animated: Bool) {
		toWhiteNavbar()
		super.pushViewController(viewController, animated: animated)
	}

	override open func popViewController(animated: Bool) -> UIViewController? {
		let popViewController = super.popViewController(animated: animated)
		if viewControllers.count == 1 {
			toMainColorNavbar()
		}
		transitionCoordinator?.animate(alongsideTransition: nil, completion: nil)
		return popViewController
	}
}
