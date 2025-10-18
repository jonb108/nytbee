use strict;
use warnings;
package BeeExt;
use base 'Exporter';
our @EXPORT_OK = qw/
    $ext_mobile_css
    $ext_desktop_css
    $ext_fastclick
    $ext_logo_base64
    $ext_script
/;
our $ext_mobile_css = <<'MCSS';
body {
    font-family: Arial;
    margin: .5in;
    font-size: 18pt;
}
.description {
    margin-top: .2in;
    width: 550px;
}
.description2 {
    margin-top: .2in;
    width: 700px;
}
.copied {
    font-size: 13pt;
    color: green;
}
.rand {
    margin-left: 6mm;
    color: skyblue;
}
td, th {
    font-family: Arial;
    font-size: 18pt;
    text-align: right;
}
.left {
    text-align: left;
}
.let {
    text-align: center;
    font-weight: bold;
    font-size: 24pt;
}
.center {
    color: green;
    font-size: 24pt;
}
.word {
    font-size: 24pt;
    color: green;
}
a {
    text-decoration: none;
    color: blue;
}
input, textarea, button {
    font-size: 18pt;
}
button, .word_td {
    background: lightgreen;
}
.cmd {
    color: darkred;
}
.cursor {
    cursor: pointer;
    color: blue;
}
.step_name {
    color: green;
}
.let:focus {
    outline: none;
}
a.help {
    margin-left: 1in;
    font-size: 18pt;
    font-weight: normal;
}
.red {
    color: red;
}
.gray {
    color: lightgray;
}
.cursor_black {
    cursor: pointer;
    color: black;
}
.h3lets {
    text-align: center;
    font-size: 40pt;
    color: green;
}
.h3cmd {
    text-align: center;
    font-size: 25pt;
}
.two_lets {
    margin-top: 0mm;
    margin-left: 5mm;
    line-height: 6mm;
}
.create_add, .help {
    font-size: 13pt;
}
.mess {
    font-size: 14pt;
    width: 500px;
    word-spacing: 10px;
}
.pointer {
    cursor: pointer;
    color: blue;
}
.float-child1 {
    float: left;
    text-align: left;
}
.float-child2 {
    float: left;
    margin-left: .3in;
}
.float-child3 {
    float: left;
    margin-left: .3in;
    text-align: right;
}
.float-child5 {
    margin-top: 5mm;
}
.new_word {
    color: coral;
}
ul {
    margin-top: 0px;
    margin-bottom: 0px;
}
li {
    font-size: 14pt;
    width: 500px;
}
td, th {
    text-align: right;
    font-size: 18pt;
    font-family: Arial;
}
.not_okay {
    color: red;
}
pre {
    font-size: 26pt;
}
body {
    margin: .3in;
    font-size: 18pt;
    font-family: Arial;
}
input, .submit {
    font-size: 18pt;
    font-family: Arial;
}
.new_words {
    text-transform: uppercase;
}
.over {
    margin-left: 1in;
}
.white {
    color: white;
}
.red1, .red2 {
    color: red;
}
.red2 {
    font-weight: bold;
}
.found_bonus {
    color: skyblue;
}
.green {
    color: green;
}
.purple {
    color: purple;
}
.found_words {
    width: 500px;
    word-spacing: 10px;
}
.submit {
    background: green;
    color: white;
}
.rank_name {
    margin-left: .5in;
}
.rank9 {
    font-weight: bold;
}
.link {
    cursor: pointer;
    color: blue;
}
.lt {
    text-align: left;
}
.rt {
    text-align: right;
}
.cn {
    text-align: center;
}
.rank0 {
    font-size: 15pt;
    color: rgb(255, 205, 255);
}
.rank1 {
    font-size: 18pt;
    color: rgb(255, 195, 255);
}
.rank2 {
    font-size: 21pt;
    color: rgb(255, 185, 255);
}
.rank3 {
    font-size: 24pt;
    color: rgb(255, 175, 255);
}
.rank4 {
    font-size: 27pt;
    color: rgb(255, 165, 255);
}
.rank5 {
    font-size: 30pt;
    color: rgb(255, 155, 255);
}
.rank6 {
    font-size: 33pt;
    color: rgb(255, 145, 255);
}
.rank7 {
    font-size: 36pt;
    color: rgb(255, 135, 255);
}
.rank8 {
    font-size: 39pt;
    color: rgb(255, 125, 255);
}
.rank9 {
    font-size: 42pt;
    color: rgb(255, 115, 255);
}
.dr {
    margin-left: .3in;
}
.biglet {
    font-size: 80pt;
    text-align: center;
}
.dlb_name {
    vertical-align: top;
    font-size: 14pt;
}
.dlb {
    text-align: left;
    font-size: 14pt;
    width: 500px;
}
MCSS
our $ext_desktop_css = <<'DCSS';
body {
    font-family: Arial;
    margin: .5in;
    font-size: 18pt;
}
.description {
    margin-top: .2in;
    width: 550px;
}
.description2 {
    margin-top: .2in;
    width: 700px;
}
.copied {
    font-size: 13pt;
    color: green;
}
.rand {
    margin-left: 6mm;
    color: skyblue;
}
td, th {
    font-family: Arial;
    font-size: 18pt;
    text-align: right;
}
.left {
    text-align: left;
}
.let {
    text-align: center;
    font-weight: bold;
    font-size: 24pt;
}
.center {
    color: green;
    font-size: 24pt;
}
.word {
    font-size: 24pt;
    color: green;
}
a {
    text-decoration: none;
    color: blue;
}
input, textarea, button {
    font-size: 18pt;
}
.red {
    color: red;
}
button, .word_td {
    background: lightgreen;
}
.cmd {
    color: darkred;
}
.cursor {
    cursor: pointer;
    color: blue;
}
.step_name {
    color: green;
}
a.help {
    margin-left: 1in;
    font-size: 18pt;
    font-weight: normal;
}
.gray {
    color: lightgray;
}
.cursor_black {
    cursor: pointer;
    color: black;
}
.two_lets {
    margin-top: 0mm;
    margin-left: 5mm;
    line-height: 6mm;
}
.create_add, .help {
    font-size: 13pt;
}
.mess {
    width: 600px;
    word-spacing: 10px;
}
.pointer {
    cursor: pointer;
    color: blue;
}
.float-child1 {
    float: left;
    text-align: left;
}
.float-child2 {
    float: left;
    margin-left: .3in;
}
.float-child3 {
    float: left;
    margin-left: .3in;
    text-align: right;
}
.float-child4 {
    float: left;
    margin-left: .3in;
}
.float-child5 {
    float: left;
    margin-left: .1in;
}
.new_word {
    color: coral;
}
ul {
    margin-top: 0px;
    margin-bottom: 0px;
}
li {
    width: 600px;
}
td, th {
    text-align: right;
    font-size: 18pt;
    font-family: Arial;
}
.not_okay {
    color: red;
}
pre {
    font-size: 26pt;
}
body {
    margin: .3in;
    font-size: 18pt;
    font-family: Arial;
}
input, .submit {
    font-size: 18pt;
    font-family: Arial;
}
.new_words {
    text-transform: uppercase;
}
.over {
    margin-left: 1in;
}
.white {
    color: white;
}
.red1, .red2 {
    color: red;
}
.red2 {
    font-weight: bold;
}
.found_bonus {
    color: skyblue;
}
.green {
    color: green;
}
.purple {
    color: purple;
}
.found_words {
    width: 600px;
    word-spacing: 10px;
}
.submit {
    background: green;
    color: white;
}
.rank_name {
    margin-left: .5in;
}
.rank9 {
    font-weight: bold;
}
.link {
    cursor: pointer;
    color: blue;
}
.lt {
    text-align: left;
}
.rt {
    text-align: right;
}
.cn {
    text-align: center;
}
.rank0 {
    font-size: 15pt;
    color: rgb(255, 205, 255);
}
.rank1 {
    font-size: 18pt;
    color: rgb(255, 195, 255);
}
.rank2 {
    font-size: 21pt;
    color: rgb(255, 185, 255);
}
.rank3 {
    font-size: 24pt;
    color: rgb(255, 175, 255);
}
.rank4 {
    font-size: 27pt;
    color: rgb(255, 165, 255);
}
.rank5 {
    font-size: 30pt;
    color: rgb(255, 155, 255);
}
.rank6 {
    font-size: 33pt;
    color: rgb(255, 145, 255);
}
.rank7 {
    font-size: 36pt;
    color: rgb(255, 135, 255);
}
.rank8 {
    font-size: 39pt;
    color: rgb(255, 125, 255);
}
.rank9 {
    font-size: 42pt;
    color: rgb(255, 115, 255);
}
.dlb_name {
    vertical-align: top;
    font-size: 14pt;
}
.dlb {
    text-align: left;
    font-size: 14pt;
    width: 500px;
}
DCSS
our $ext_fastclick = <<'FAST';
<script>
;(function () {
	'use strict';

	/**
	 * @preserve FastClick: polyfill to remove click delays on browsers with touch UIs.
	 *
	 * @codingstandard ftlabs-jsv2
	 * @copyright The Financial Times Limited [All Rights Reserved]
	 * @license MIT License (see LICENSE.txt)
	 */

	/*jslint browser:true, node:true*/
	/*global define, Event, Node*/


	/**
	 * Instantiate fast-clicking listeners on the specified layer.
	 *
	 * @constructor
	 * @param {Element} layer The layer to listen on
	 * @param {Object} [options={}] The options to override the defaults
	 */
	function FastClick(layer, options) {
		var oldOnClick;

		options = options || {};

		/**
		 * Whether a click is currently being tracked.
		 *
		 * @type boolean
		 */
		this.trackingClick = false;


		/**
		 * Timestamp for when click tracking started.
		 *
		 * @type number
		 */
		this.trackingClickStart = 0;


		/**
		 * The element being tracked for a click.
		 *
		 * @type EventTarget
		 */
		this.targetElement = null;


		/**
		 * X-coordinate of touch start event.
		 *
		 * @type number
		 */
		this.touchStartX = 0;


		/**
		 * Y-coordinate of touch start event.
		 *
		 * @type number
		 */
		this.touchStartY = 0;


		/**
		 * ID of the last touch, retrieved from Touch.identifier.
		 *
		 * @type number
		 */
		this.lastTouchIdentifier = 0;


		/**
		 * Touchmove boundary, beyond which a click will be cancelled.
		 *
		 * @type number
		 */
		this.touchBoundary = options.touchBoundary || 10;


		/**
		 * The FastClick layer.
		 *
		 * @type Element
		 */
		this.layer = layer;

		/**
		 * The minimum time between tap(touchstart and touchend) events
		 *
		 * @type number
		 */
		this.tapDelay = options.tapDelay || 200;

		/**
		 * The maximum time for a tap
		 *
		 * @type number
		 */
		this.tapTimeout = options.tapTimeout || 700;

		if (FastClick.notNeeded(layer)) {
			return;
		}

		// Some old versions of Android don't have Function.prototype.bind
		function bind(method, context) {
			return function() { return method.apply(context, arguments); };
		}


		var methods = ['onMouse', 'onClick', 'onTouchStart', 'onTouchMove', 'onTouchEnd', 'onTouchCancel'];
		var context = this;
		for (var i = 0, l = methods.length; i < l; i++) {
			context[methods[i]] = bind(context[methods[i]], context);
		}

		// Set up event handlers as required
		if (deviceIsAndroid) {
			layer.addEventListener('mouseover', this.onMouse, true);
			layer.addEventListener('mousedown', this.onMouse, true);
			layer.addEventListener('mouseup', this.onMouse, true);
		}

		layer.addEventListener('click', this.onClick, true);
		layer.addEventListener('touchstart', this.onTouchStart, false);
		layer.addEventListener('touchmove', this.onTouchMove, false);
		layer.addEventListener('touchend', this.onTouchEnd, false);
		layer.addEventListener('touchcancel', this.onTouchCancel, false);

		// Hack is required for browsers that don't support Event#stopImmediatePropagation (e.g. Android 2)
		// which is how FastClick normally stops click events bubbling to callbacks registered on the FastClick
		// layer when they are cancelled.
		if (!Event.prototype.stopImmediatePropagation) {
			layer.removeEventListener = function(type, callback, capture) {
				var rmv = Node.prototype.removeEventListener;
				if (type === 'click') {
					rmv.call(layer, type, callback.hijacked || callback, capture);
				} else {
					rmv.call(layer, type, callback, capture);
				}
			};

			layer.addEventListener = function(type, callback, capture) {
				var adv = Node.prototype.addEventListener;
				if (type === 'click') {
					adv.call(layer, type, callback.hijacked || (callback.hijacked = function(event) {
						if (!event.propagationStopped) {
							callback(event);
						}
					}), capture);
				} else {
					adv.call(layer, type, callback, capture);
				}
			};
		}

		// If a handler is already declared in the element's onclick attribute, it will be fired before
		// FastClick's onClick handler. Fix this by pulling out the user-defined handler function and
		// adding it as listener.
		if (typeof layer.onclick === 'function') {

			// Android browser on at least 3.2 requires a new reference to the function in layer.onclick
			// - the old one won't work if passed to addEventListener directly.
			oldOnClick = layer.onclick;
			layer.addEventListener('click', function(event) {
				oldOnClick(event);
			}, false);
			layer.onclick = null;
		}
	}

	/**
	* Windows Phone 8.1 fakes user agent string to look like Android and iPhone.
	*
	* @type boolean
	*/
	var deviceIsWindowsPhone = navigator.userAgent.indexOf("Windows Phone") >= 0;

	/**
	 * Android requires exceptions.
	 *
	 * @type boolean
	 */
	var deviceIsAndroid = navigator.userAgent.indexOf('Android') > 0 && !deviceIsWindowsPhone;


	/**
	 * iOS requires exceptions.
	 *
	 * @type boolean
	 */
	var deviceIsIOS = /iP(ad|hone|od)/.test(navigator.userAgent) && !deviceIsWindowsPhone;


	/**
	 * iOS 4 requires an exception for select elements.
	 *
	 * @type boolean
	 */
	var deviceIsIOS4 = deviceIsIOS && (/OS 4_\d(_\d)?/).test(navigator.userAgent);


	/**
	 * iOS 6.0-7.* requires the target element to be manually derived
	 *
	 * @type boolean
	 */
	var deviceIsIOSWithBadTarget = deviceIsIOS && (/OS [6-7]_\d/).test(navigator.userAgent);

	/**
	 * BlackBerry requires exceptions.
	 *
	 * @type boolean
	 */
	var deviceIsBlackBerry10 = navigator.userAgent.indexOf('BB10') > 0;

	/**
	 * Determine whether a given element requires a native click.
	 *
	 * @param {EventTarget|Element} target Target DOM element
	 * @returns {boolean} Returns true if the element needs a native click
	 */
	FastClick.prototype.needsClick = function(target) {
		switch (target.nodeName.toLowerCase()) {

		// Don't send a synthetic click to disabled inputs (issue #62)
		case 'button':
		case 'select':
		case 'textarea':
			if (target.disabled) {
				return true;
			}

			break;
		case 'input':

			// File inputs need real clicks on iOS 6 due to a browser bug (issue #68)
			if ((deviceIsIOS && target.type === 'file') || target.disabled) {
				return true;
			}

			break;
		case 'label':
		case 'iframe': // iOS8 homescreen apps can prevent events bubbling into frames
		case 'video':
			return true;
		}

		return (/\bneedsclick\b/).test(target.className);
	};


	/**
	 * Determine whether a given element requires a call to focus to simulate click into element.
	 *
	 * @param {EventTarget|Element} target Target DOM element
	 * @returns {boolean} Returns true if the element requires a call to focus to simulate native click.
	 */
	FastClick.prototype.needsFocus = function(target) {
		switch (target.nodeName.toLowerCase()) {
		case 'textarea':
			return true;
		case 'select':
			return !deviceIsAndroid;
		case 'input':
			switch (target.type) {
			case 'button':
			case 'checkbox':
			case 'file':
			case 'image':
			case 'radio':
			case 'submit':
				return false;
			}

			// No point in attempting to focus disabled inputs
			return !target.disabled && !target.readOnly;
		default:
			return (/\bneedsfocus\b/).test(target.className);
		}
	};


	/**
	 * Send a click event to the specified element.
	 *
	 * @param {EventTarget|Element} targetElement
	 * @param {Event} event
	 */
	FastClick.prototype.sendClick = function(targetElement, event) {
		var clickEvent, touch;

		// On some Android devices activeElement needs to be blurred otherwise the synthetic click will have no effect (#24)
		if (document.activeElement && document.activeElement !== targetElement) {
			document.activeElement.blur();
		}

		touch = event.changedTouches[0];

		// Synthesise a click event, with an extra attribute so it can be tracked
		clickEvent = document.createEvent('MouseEvents');
		clickEvent.initMouseEvent(this.determineEventType(targetElement), true, true, window, 1, touch.screenX, touch.screenY, touch.clientX, touch.clientY, false, false, false, false, 0, null);
		clickEvent.forwardedTouchEvent = true;
		targetElement.dispatchEvent(clickEvent);
	};

	FastClick.prototype.determineEventType = function(targetElement) {

		//Issue #159: Android Chrome Select Box does not open with a synthetic click event
		if (deviceIsAndroid && targetElement.tagName.toLowerCase() === 'select') {
			return 'mousedown';
		}

		return 'click';
	};


	/**
	 * @param {EventTarget|Element} targetElement
	 */
	FastClick.prototype.focus = function(targetElement) {
		var length;

		// Issue #160: on iOS 7, some input elements (e.g. date datetime month) throw a vague TypeError on setSelectionRange. These elements don't have an integer value for the selectionStart and selectionEnd properties, but unfortunately that can't be used for detection because accessing the properties also throws a TypeError. Just check the type instead. Filed as Apple bug #15122724.
		if (deviceIsIOS && targetElement.setSelectionRange && targetElement.type.indexOf('date') !== 0 && targetElement.type !== 'time' && targetElement.type !== 'month' && targetElement.type !== 'email') {
			length = targetElement.value.length;
			targetElement.setSelectionRange(length, length);
		} else {
			targetElement.focus();
		}
	};


	/**
	 * Check whether the given target element is a child of a scrollable layer and if so, set a flag on it.
	 *
	 * @param {EventTarget|Element} targetElement
	 */
	FastClick.prototype.updateScrollParent = function(targetElement) {
		var scrollParent, parentElement;

		scrollParent = targetElement.fastClickScrollParent;

		// Attempt to discover whether the target element is contained within a scrollable layer. Re-check if the
		// target element was moved to another parent.
		if (!scrollParent || !scrollParent.contains(targetElement)) {
			parentElement = targetElement;
			do {
				if (parentElement.scrollHeight > parentElement.offsetHeight) {
					scrollParent = parentElement;
					targetElement.fastClickScrollParent = parentElement;
					break;
				}

				parentElement = parentElement.parentElement;
			} while (parentElement);
		}

		// Always update the scroll top tracker if possible.
		if (scrollParent) {
			scrollParent.fastClickLastScrollTop = scrollParent.scrollTop;
		}
	};


	/**
	 * @param {EventTarget} targetElement
	 * @returns {Element|EventTarget}
	 */
	FastClick.prototype.getTargetElementFromEventTarget = function(eventTarget) {

		// On some older browsers (notably Safari on iOS 4.1 - see issue #56) the event target may be a text node.
		if (eventTarget.nodeType === Node.TEXT_NODE) {
			return eventTarget.parentNode;
		}

		return eventTarget;
	};


	/**
	 * On touch start, record the position and scroll offset.
	 *
	 * @param {Event} event
	 * @returns {boolean}
	 */
	FastClick.prototype.onTouchStart = function(event) {
		var targetElement, touch, selection;

		// Ignore multiple touches, otherwise pinch-to-zoom is prevented if both fingers are on the FastClick element (issue #111).
		if (event.targetTouches.length > 1) {
			return true;
		}

		targetElement = this.getTargetElementFromEventTarget(event.target);
		touch = event.targetTouches[0];

		if (deviceIsIOS) {

			// Only trusted events will deselect text on iOS (issue #49)
			selection = window.getSelection();
			if (selection.rangeCount && !selection.isCollapsed) {
				return true;
			}

			if (!deviceIsIOS4) {

				// Weird things happen on iOS when an alert or confirm dialog is opened from a click event callback (issue #23):
				// when the user next taps anywhere else on the page, new touchstart and touchend events are dispatched
				// with the same identifier as the touch event that previously triggered the click that triggered the alert.
				// Sadly, there is an issue on iOS 4 that causes some normal touch events to have the same identifier as an
				// immediately preceeding touch event (issue #52), so this fix is unavailable on that platform.
				// Issue 120: touch.identifier is 0 when Chrome dev tools 'Emulate touch events' is set with an iOS device UA string,
				// which causes all touch events to be ignored. As this block only applies to iOS, and iOS identifiers are always long,
				// random integers, it's safe to to continue if the identifier is 0 here.
				if (touch.identifier && touch.identifier === this.lastTouchIdentifier) {
					event.preventDefault();
					return false;
				}

				this.lastTouchIdentifier = touch.identifier;

				// If the target element is a child of a scrollable layer (using -webkit-overflow-scrolling: touch) and:
				// 1) the user does a fling scroll on the scrollable layer
				// 2) the user stops the fling scroll with another tap
				// then the event.target of the last 'touchend' event will be the element that was under the user's finger
				// when the fling scroll was started, causing FastClick to send a click event to that layer - unless a check
				// is made to ensure that a parent layer was not scrolled before sending a synthetic click (issue #42).
				this.updateScrollParent(targetElement);
			}
		}

		this.trackingClick = true;
		this.trackingClickStart = event.timeStamp;
		this.targetElement = targetElement;

		this.touchStartX = touch.pageX;
		this.touchStartY = touch.pageY;

		// Prevent phantom clicks on fast double-tap (issue #36)
		if ((event.timeStamp - this.lastClickTime) < this.tapDelay) {
			event.preventDefault();
		}

		return true;
	};


	/**
	 * Based on a touchmove event object, check whether the touch has moved past a boundary since it started.
	 *
	 * @param {Event} event
	 * @returns {boolean}
	 */
	FastClick.prototype.touchHasMoved = function(event) {
		var touch = event.changedTouches[0], boundary = this.touchBoundary;

		if (Math.abs(touch.pageX - this.touchStartX) > boundary || Math.abs(touch.pageY - this.touchStartY) > boundary) {
			return true;
		}

		return false;
	};


	/**
	 * Update the last position.
	 *
	 * @param {Event} event
	 * @returns {boolean}
	 */
	FastClick.prototype.onTouchMove = function(event) {
		if (!this.trackingClick) {
			return true;
		}

		// If the touch has moved, cancel the click tracking
		if (this.targetElement !== this.getTargetElementFromEventTarget(event.target) || this.touchHasMoved(event)) {
			this.trackingClick = false;
			this.targetElement = null;
		}

		return true;
	};


	/**
	 * Attempt to find the labelled control for the given label element.
	 *
	 * @param {EventTarget|HTMLLabelElement} labelElement
	 * @returns {Element|null}
	 */
	FastClick.prototype.findControl = function(labelElement) {

		// Fast path for newer browsers supporting the HTML5 control attribute
		if (labelElement.control !== undefined) {
			return labelElement.control;
		}

		// All browsers under test that support touch events also support the HTML5 htmlFor attribute
		if (labelElement.htmlFor) {
			return document.getElementById(labelElement.htmlFor);
		}

		// If no for attribute exists, attempt to retrieve the first labellable descendant element
		// the list of which is defined here: http://www.w3.org/TR/html5/forms.html#category-label
		return labelElement.querySelector('button, input:not([type=hidden]), keygen, meter, output, progress, select, textarea');
	};


	/**
	 * On touch end, determine whether to send a click event at once.
	 *
	 * @param {Event} event
	 * @returns {boolean}
	 */
	FastClick.prototype.onTouchEnd = function(event) {
		var forElement, trackingClickStart, targetTagName, scrollParent, touch, targetElement = this.targetElement;

		if (!this.trackingClick) {
			return true;
		}

		// Prevent phantom clicks on fast double-tap (issue #36)
		if ((event.timeStamp - this.lastClickTime) < this.tapDelay) {
			this.cancelNextClick = true;
			return true;
		}

		if ((event.timeStamp - this.trackingClickStart) > this.tapTimeout) {
			return true;
		}

		// Reset to prevent wrong click cancel on input (issue #156).
		this.cancelNextClick = false;

		this.lastClickTime = event.timeStamp;

		trackingClickStart = this.trackingClickStart;
		this.trackingClick = false;
		this.trackingClickStart = 0;

		// On some iOS devices, the targetElement supplied with the event is invalid if the layer
		// is performing a transition or scroll, and has to be re-detected manually. Note that
		// for this to function correctly, it must be called *after* the event target is checked!
		// See issue #57; also filed as rdar://13048589 .
		if (deviceIsIOSWithBadTarget) {
			touch = event.changedTouches[0];

			// In certain cases arguments of elementFromPoint can be negative, so prevent setting targetElement to null
			targetElement = document.elementFromPoint(touch.pageX - window.pageXOffset, touch.pageY - window.pageYOffset) || targetElement;
			targetElement.fastClickScrollParent = this.targetElement.fastClickScrollParent;
		}

		targetTagName = targetElement.tagName.toLowerCase();
		if (targetTagName === 'label') {
			forElement = this.findControl(targetElement);
			if (forElement) {
				this.focus(targetElement);
				if (deviceIsAndroid) {
					return false;
				}

				targetElement = forElement;
			}
		} else if (this.needsFocus(targetElement)) {

			// Case 1: If the touch started a while ago (best guess is 100ms based on tests for issue #36) then focus will be triggered anyway. Return early and unset the target element reference so that the subsequent click will be allowed through.
			// Case 2: Without this exception for input elements tapped when the document is contained in an iframe, then any inputted text won't be visible even though the value attribute is updated as the user types (issue #37).
			if ((event.timeStamp - trackingClickStart) > 100 || (deviceIsIOS && window.top !== window && targetTagName === 'input')) {
				this.targetElement = null;
				return false;
			}

			this.focus(targetElement);
			this.sendClick(targetElement, event);

			// Select elements need the event to go through on iOS 4, otherwise the selector menu won't open.
			// Also this breaks opening selects when VoiceOver is active on iOS6, iOS7 (and possibly others)
			if (!deviceIsIOS || targetTagName !== 'select') {
				this.targetElement = null;
				event.preventDefault();
			}

			return false;
		}

		if (deviceIsIOS && !deviceIsIOS4) {

			// Don't send a synthetic click event if the target element is contained within a parent layer that was scrolled
			// and this tap is being used to stop the scrolling (usually initiated by a fling - issue #42).
			scrollParent = targetElement.fastClickScrollParent;
			if (scrollParent && scrollParent.fastClickLastScrollTop !== scrollParent.scrollTop) {
				return true;
			}
		}

		// Prevent the actual click from going though - unless the target node is marked as requiring
		// real clicks or if it is in the allowlist in which case only non-programmatic clicks are permitted.
		if (!this.needsClick(targetElement)) {
			event.preventDefault();
			this.sendClick(targetElement, event);
		}

		return false;
	};


	/**
	 * On touch cancel, stop tracking the click.
	 *
	 * @returns {void}
	 */
	FastClick.prototype.onTouchCancel = function() {
		this.trackingClick = false;
		this.targetElement = null;
	};


	/**
	 * Determine mouse events which should be permitted.
	 *
	 * @param {Event} event
	 * @returns {boolean}
	 */
	FastClick.prototype.onMouse = function(event) {

		// If a target element was never set (because a touch event was never fired) allow the event
		if (!this.targetElement) {
			return true;
		}

		if (event.forwardedTouchEvent) {
			return true;
		}

		// Programmatically generated events targeting a specific element should be permitted
		if (!event.cancelable) {
			return true;
		}

		// Derive and check the target element to see whether the mouse event needs to be permitted;
		// unless explicitly enabled, prevent non-touch click events from triggering actions,
		// to prevent ghost/doubleclicks.
		if (!this.needsClick(this.targetElement) || this.cancelNextClick) {

			// Prevent any user-added listeners declared on FastClick element from being fired.
			if (event.stopImmediatePropagation) {
				event.stopImmediatePropagation();
			} else {

				// Part of the hack for browsers that don't support Event#stopImmediatePropagation (e.g. Android 2)
				event.propagationStopped = true;
			}

			// Cancel the event
			event.stopPropagation();
			event.preventDefault();

			return false;
		}

		// If the mouse event is permitted, return true for the action to go through.
		return true;
	};


	/**
	 * On actual clicks, determine whether this is a touch-generated click, a click action occurring
	 * naturally after a delay after a touch (which needs to be cancelled to avoid duplication), or
	 * an actual click which should be permitted.
	 *
	 * @param {Event} event
	 * @returns {boolean}
	 */
	FastClick.prototype.onClick = function(event) {
		var permitted;

		// It's possible for another FastClick-like library delivered with third-party code to fire a click event before FastClick does (issue #44). In that case, set the click-tracking flag back to false and return early. This will cause onTouchEnd to return early.
		if (this.trackingClick) {
			this.targetElement = null;
			this.trackingClick = false;
			return true;
		}

		// Very odd behaviour on iOS (issue #18): if a submit element is present inside a form and the user hits enter in the iOS simulator or clicks the Go button on the pop-up OS keyboard the a kind of 'fake' click event will be triggered with the submit-type input element as the target.
		if (event.target.type === 'submit' && event.detail === 0) {
			return true;
		}

		permitted = this.onMouse(event);

		// Only unset targetElement if the click is not permitted. This will ensure that the check for !targetElement in onMouse fails and the browser's click doesn't go through.
		if (!permitted) {
			this.targetElement = null;
		}

		// If clicks are permitted, return true for the action to go through.
		return permitted;
	};


	/**
	 * Remove all FastClick's event listeners.
	 *
	 * @returns {void}
	 */
	FastClick.prototype.destroy = function() {
		var layer = this.layer;

		if (deviceIsAndroid) {
			layer.removeEventListener('mouseover', this.onMouse, true);
			layer.removeEventListener('mousedown', this.onMouse, true);
			layer.removeEventListener('mouseup', this.onMouse, true);
		}

		layer.removeEventListener('click', this.onClick, true);
		layer.removeEventListener('touchstart', this.onTouchStart, false);
		layer.removeEventListener('touchmove', this.onTouchMove, false);
		layer.removeEventListener('touchend', this.onTouchEnd, false);
		layer.removeEventListener('touchcancel', this.onTouchCancel, false);
	};


	/**
	 * Check whether FastClick is needed.
	 *
	 * @param {Element} layer The layer to listen on
	 */
	FastClick.notNeeded = function(layer) {
		var metaViewport;
		var chromeVersion;
		var blackberryVersion;
		var firefoxVersion;

		// Devices that don't support touch don't need FastClick
		if (typeof window.ontouchstart === 'undefined') {
			return true;
		}

		// Chrome version - zero for other browsers
		chromeVersion = +(/Chrome\/([0-9]+)/.exec(navigator.userAgent) || [,0])[1];

		if (chromeVersion) {

			if (deviceIsAndroid) {
				metaViewport = document.querySelector('meta[name=viewport]');

				if (metaViewport) {
					// Chrome on Android with user-scalable="no" doesn't need FastClick (issue #89)
					if (metaViewport.content.indexOf('user-scalable=no') !== -1) {
						return true;
					}
					// Chrome 32 and above with width=device-width or less don't need FastClick
					if (chromeVersion > 31 && document.documentElement.scrollWidth <= window.outerWidth) {
						return true;
					}
				}

			// Chrome desktop doesn't need FastClick (issue #15)
			} else {
				return true;
			}
		}

		if (deviceIsBlackBerry10) {
			blackberryVersion = navigator.userAgent.match(/Version\/([0-9]*)\.([0-9]*)/);

			// BlackBerry 10.3+ does not require Fastclick library.
			// https://github.com/ftlabs/fastclick/issues/251
			if (blackberryVersion[1] >= 10 && blackberryVersion[2] >= 3) {
				metaViewport = document.querySelector('meta[name=viewport]');

				if (metaViewport) {
					// user-scalable=no eliminates click delay.
					if (metaViewport.content.indexOf('user-scalable=no') !== -1) {
						return true;
					}
					// width=device-width (or less than device-width) eliminates click delay.
					if (document.documentElement.scrollWidth <= window.outerWidth) {
						return true;
					}
				}
			}
		}

		// IE10 with -ms-touch-action: none or manipulation, which disables double-tap-to-zoom (issue #97)
		if (layer.style.msTouchAction === 'none' || layer.style.touchAction === 'manipulation') {
			return true;
		}

		// Firefox version - zero for other browsers
		firefoxVersion = +(/Firefox\/([0-9]+)/.exec(navigator.userAgent) || [,0])[1];

		if (firefoxVersion >= 27) {
			// Firefox 27+ does not have tap delay if the content is not zoomable - https://bugzilla.mozilla.org/show_bug.cgi?id=922896

			metaViewport = document.querySelector('meta[name=viewport]');
			if (metaViewport && (metaViewport.content.indexOf('user-scalable=no') !== -1 || document.documentElement.scrollWidth <= window.outerWidth)) {
				return true;
			}
		}

		// IE11: prefixed -ms-touch-action is no longer supported and it's recomended to use non-prefixed version
		// http://msdn.microsoft.com/en-us/library/windows/apps/Hh767313.aspx
		if (layer.style.touchAction === 'none' || layer.style.touchAction === 'manipulation') {
			return true;
		}

		return false;
	};


	/**
	 * Factory method for creating a FastClick object
	 *
	 * @param {Element} layer The layer to listen on
	 * @param {Object} [options={}] The options to override the defaults
	 */
	FastClick.attach = function(layer, options) {
		return new FastClick(layer, options);
	};


	if (typeof define === 'function' && typeof define.amd === 'object' && define.amd) {

		// AMD. Register as an anonymous module.
		define(function() {
			return FastClick;
		});
	} else if (typeof module !== 'undefined' && module.exports) {
		module.exports = FastClick.attach;
		module.exports.FastClick = FastClick;
	} else {
		window.FastClick = FastClick;
	}
}());
if ('addEventListener' in document) {
    document.addEventListener('DOMContentLoaded', function() {
        FastClick.attach(document.body);
    }, false);
}
</script>
FAST
our $ext_logo_base64 = "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";
our $ext_script = <<'JS';
<script>
var lets;
var nw;
var hnw;
var main;
function init() {
    nw   = document.getElementById('new_words');
    hnw  = document.getElementById('hidden_new_words');
    lets = document.getElementById('lets');
    main = document.getElementById('main');
}
function empty(s) {
    return s.trim().length === 0;
}
var lets_font_size = 28;    // initial numeric value
function add_let(c) {
    var x = c.substring(0, 1);
    if (x == '+' || x == '-') {
        // for the PF command flash mode
        // c is actually a string like +4 or -10
        lets.style.fontSize = '20pt'; 
        lets.innerHTML += c;
        // let it show for a little while
        // then restore the original font size
        // for subsequent word letters
        setTimeout(() => {
            lets.style.fontSize = '28pt'; 
        }, 1300);
        return;
    }
    if (c == ' ') {
        var dis = document.getElementById('pos31');
        if (dis && dis.style.display != 'none') {
            // turn off these links so there is more room
            // for words
            for (num = 1; num <= 3; ++num) {
                document.getElementById('pos3' + num).style.display = 'none';
            }
        }
        var len = lets.innerHTML.length;
        var last_char = lets.innerHTML.substring(len-1);
        if (last_char == ' ') {
            lets_font_size -= 1;
            lets.style.fontSize = lets_font_size.toString()+'px';
            // no need to append another blank
            return;
        }
        if (lets_font_size == 28 && len > 16) {
            lets_font_size = 24;
            lets.style.fontSize = '24px';
        }
    }
    // just append the character (whatever it is)
    lets.innerHTML += c;
}
function add_redlet(c) {
    lets.innerHTML += '<span class=red>' + c + '</span>';
}
// hello => hell
// hell<span class="red">o</span> => hell
function del_let() {
    var s = lets.innerHTML;
    var l = s.length;
    if (s.substring(l-1) == '>') {
        s = s.substring(0, l-26);
    }
    else {
        s = s.substring(0, l-1);
    }
    lets.innerHTML = s;
}
function issue_cmd(s) {
    hnw.value = s;
    main.submit();
}
function stash_lets() {
    hnw.value = 'SW ' + lets.textContent + ' ' + nw.value;
    main.submit();
}
function sub_lets() {
    hnw.value = lets.textContent;
    main.submit();
}
function check_name_location() {
    var name = document.getElementById('name');
    if (empty(name.value)) {
        alert('Please provide a Name.');
        name.focus();
        return false;
    }
    var location = document.getElementById('location');
    if (empty(location.value)) {
        alert('Please provide a Location.');
        location.focus();
        return false;
    }
    return true;
}
function add_clues() {
    set_focus();
    document.getElementById('add_clues').submit();
}
function clues_by(person_id) {
    document.getElementById('person_id').value = person_id;
    document.getElementById('clues_by').submit();
    set_focus();
}
function set_focus() {
    setTimeout(() => { window.scrollTo(0, 0); }, 20);
    nw.focus();
    return true;
}
function copy_uuid_to_clipboard(uuid) {
    navigator.clipboard.writeText(uuid);
    show_copied('uuid');
}
function show_copied(id) {
    var el = document.getElementById(id);
    el.innerHTML = 'copied';
    setTimeout(() => {
        el.innerHTML = "";
    }, 1000);
}
function full_def(word) {
    window.open('https://wordnik.com/words/' + word,
                '_blank', 'width=1000');
    set_focus();
}
function popup_define(word, height, width) {
    newwin = window.open(
        "https://logicalpoetry.com/cgi-bin/nytbee_define.pl/"
            + word, 'define',
        'height=' + height + ',width=' + width +', scrollbars'
    );
    newwin.moveTo(800, 0);
    document.getElementById(word + '_clue').focus();
}
function del_post(id) {
    document.getElementById('x' + id).style.pointerEvents = "none";
    if (confirm('Deleting your post. Are you sure?')) {
        hnw.value = 'FX' + id;
        main.submit();
    }
}
function edit_post(id) {
    document.getElementById('e' + id).style.pointerEvents = "none";
    hnw.value = 'FE' + id;
    main.submit();
}
function blink_pink(the_id, color) {
    var p = document.getElementById(the_id);
    p.style = 'fill:rgb(255,217, 231)';
    setTimeout(() => {
        p.style = 'fill:' + color;
    }, 200);
}
</script>
JS

1;
