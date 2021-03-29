//
//  KeyboardViewController.swift
//  KeyboardKit
//
//  Created by Daniel Saidi on 2018-03-13.
//  Copyright © 2021 Daniel Saidi. All rights reserved.
//

import Combine
import SwiftUI
import UIKit

/**
 This class extends `UIInputViewController` with KeyboardKit
 specific functionality.
 
 With KeyboardKit, let your `KeyboardViewController` inherit
 this class instead of `UIInputViewController`. You then get
 access to a bunch of features that regular controllers lack.
 
 To change the keyboard type and automatically setup the new
 keyboard, set the `keyboardType` property of this class and
 not of its context. You can also call `changeKeyboardType()`
 which can be overridden and customized.
 
 To setup autocomplete, simply override `performAutocomplete`
 and `resetAutocomplete`. They are automatically called when
 the texst position changes or the action handler performs a
 keyboard action.
 */
open class KeyboardInputViewController: UIInputViewController {
    
    
    // MARK: - View Controller Lifecycle
    
    open override func viewDidLoad() {
        super.viewDidLoad()
        Self.shared = self
        setupLocaleObservation()
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        keyboardContext.sync(with: self)
        viewWillSyncWithTextDocumentProxy()
    }
    
    open override func viewWillLayoutSubviews() {
        keyboardContext.sync(with: self)
        super.viewWillLayoutSubviews()
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        keyboardContext.sync(with: self)
        super.traitCollectionDidChange(previousTraitCollection)
    }
    
    open func viewWillSyncWithTextDocumentProxy() {
        keyboardContext.textDocumentProxy = textDocumentProxy
    }
    
    /**
     This is boilerplate code for retrieving text input mode
     from the active input modes, given the context's locale.
     However, since the context syncs the input mode and the
     code uses the context, we get a death loop. Solve this.
     */
    //    override var textInputMode: UITextInputMode? {
    //        guard let languageCode = keyboardContext.locale.languageCode else { return super.textInputMode }
    //        let modes = UITextInputMode.activeInputModes
    //        let match = modes.first { $0.primaryLanguage?.hasPrefix(languageCode) == true }
    //        return match ?? super.textInputMode
    //    }
    
    
    // MARK: - Setup

    /**
     Setup KeyboardKit with a SwiftUI view.
     
     This will remove all subviews from the vc view then add
     the provided view to it. The view will be pinned to the
     edges of the vc view and resize the extension to fit.
     
     This also applies `@EnvironmentObject` instances to the
     view, that can be used within the entire view hierarchy.
     */
    open func setup<Content: View>(with view: Content) {
        self.view.subviews.forEach { $0.removeFromSuperview() }
        let view = view
            .environmentObject(autocompleteContext)
            .environmentObject(keyboardContext)
            .environmentObject(keyboardInputCalloutContext)
            .environmentObject(keyboardSecondaryInputCalloutContext)
        let controller = KeyboardHostingController(rootView: view)
        controller.add(to: self)
    }
    
    
    // MARK: - Combine
    
    var cancellables = Set<AnyCancellable>()
    
    
    // MARK: - Properties
    
    /**
     The shared input view controller. This is registered as
     the keyboard extension is started.
     */
    public static var shared: KeyboardInputViewController!
    
    /**
     The extension's default keyboard context.
     */
    public lazy var autocompleteContext = AutocompleteContext()
    
    /**
     The extension's default autocomplete suggestion provider.
     */
    public lazy var autocompleteSuggestionProvider: AutocompleteSuggestionProvider = DisabledAutocompleteSuggestionProvider()
    
    /**
     The extension's default keyboard action handler.
     */
    public lazy var keyboardActionHandler: KeyboardActionHandler = StandardKeyboardActionHandler(
        inputViewController: self)

    /**
     The extension's default keyboard appearance.
     */
    public lazy var keyboardAppearance: KeyboardAppearance = StandardKeyboardAppearance(
        context: keyboardContext)

    /**
     The extension's default keyboard behavior.
     */
    public lazy var keyboardBehavior: KeyboardBehavior = StandardKeyboardBehavior(
        context: keyboardContext)
    
    /**
     The extension's default keyboard context.
     */
    public lazy var keyboardContext = KeyboardContext(controller: self)
    
    /**
     The extension's default input callout context.
     */
    public lazy var keyboardInputCalloutContext = InputCalloutContext()
    
    /**
     The extension's default keyboard input set provider.
     */
    public lazy var keyboardInputSetProvider: KeyboardInputSetProvider = StandardKeyboardInputSetProvider(
        context: keyboardContext) {
        didSet {
            keyboardLayoutProvider.register(inputSetProvider: keyboardInputSetProvider)
        }
    }
                    
    /**
     The extension's default keyboard layout provider.
     */
    public lazy var keyboardLayoutProvider: KeyboardLayoutProvider = StandardKeyboardLayoutProvider(
        inputSetProvider: keyboardInputSetProvider)
    
    /**
     The extension's default secondary input action provider.
     */
    public lazy var keyboardSecondaryCalloutActionProvider: SecondaryCalloutActionProvider = StandardSecondaryCalloutActionProvider(
        context: keyboardContext)
    
    /**
     The extension's default secondary input callout context.
     */
    public lazy var keyboardSecondaryInputCalloutContext = SecondaryInputCalloutContext(
        actionProvider: keyboardSecondaryCalloutActionProvider,
        actionHandler: keyboardActionHandler)
    
    
    // MARK: - View Properties
    
    /**
     This is a regular, vertical `UIStackView`, to which you
     can add toolbars, rows etc. to create `UIKit` keyboards.
     */
    public lazy var keyboardStackView: UIStackView = {
        let stackView = UIStackView(frame: .zero)
        stackView.axis = .vertical
        stackView.alignment = .fill
        stackView.distribution = .equalSpacing
        view.addSubview(stackView, fill: true)
        return stackView
    }()
    
    
    // MARK: - Text And Selection Change
    
    open override func selectionWillChange(_ textInput: UITextInput?) {
        super.selectionWillChange(textInput)
        resetAutocomplete()
    }
    
    open override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        resetAutocomplete()
    }
    
    open override func textWillChange(_ textInput: UITextInput?) {
        super.textWillChange(textInput)
        keyboardContext.textDocumentProxy = textDocumentProxy
    }
    
    open override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        performAutocomplete()
        tryChangeToPreferredKeyboardTypeAfterTextDidChange()
    }
    
    
    // MARK: - Public Functions
    
    @available(*, deprecated, message: "Change the keyboard context locale directly. Use Combine to observe the result.")
    open func changeKeyboardLocale(to locale: Locale) {
        keyboardContext.locale = locale
    }
    
    @available(*, deprecated, message: "Change the keyboard context keyboardType directly. Use Combine to observe the result.")
    open func changeKeyboardType(to type: KeyboardType) {
        keyboardContext.keyboardType = type
    }
    
    /**
     Perform an autocomplete operation. You can override the
     function to provide custom autocomplete logic.
     
     This function can be called directly or injected into a
     nested service class to avoid bilinear dependencies. It
     is injected into `StandardKeyboardActionHandler`.
     */
    open func performAutocomplete() {
        guard let word = textDocumentProxy.currentWord else { return resetAutocomplete() }
        autocompleteSuggestionProvider.autocompleteSuggestions(for: word) { [weak self] result in
            switch result {
            case .failure(let error): print(error.localizedDescription)
            case .success(let result): self?.autocompleteContext.suggestions = result
            }
        }
    }
    
    /**
     Reset autocomplete state. You can override the function
     to provide custom autocomplete logic.
     */
    open func resetAutocomplete() {
        autocompleteContext.suggestions = []
    }
}


// MARK: - Private Functions

private extension KeyboardInputViewController {
    
    func setupLocaleObservation() {
        keyboardContext.$locale.sink { [weak self] in
            guard let self = self else { return }
            let locale = $0
            self.autocompleteSuggestionProvider.locale = locale
        }.store(in: &cancellables)
    }
    
    func tryChangeToPreferredKeyboardTypeAfterTextDidChange() {
        let context = keyboardContext
        let shouldSwitch = keyboardBehavior.shouldSwitchToPreferredKeyboardTypeAfterTextDidChange()
        guard shouldSwitch else { return }
        keyboardContext.keyboardType = context.preferredKeyboardType
    }
}
