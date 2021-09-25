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
 
 When you use KeyboardKit, inherit this class instead of the
 regular `UIInputViewController` class. This will extend the
 keyboard extension with a lot of additional features that a
 regular keyboard extension lacks.
 
 This class provides you with many utils that you can use to
 build a more powerful keyboard extension, for instance:
 
 * `autocompleteProvider` provides autocomplete suggestions
 * `keyboardActionHandler` handles keyboard actions
 * `keyboardAppearance` determines the keyboard design
 * `keyboardBehavior` determines the keyboard behavior
 * `keyboardFeedbackHandler` handles autio & haptic feedback
 * `keyboardInputSetProvider` provides keybpard input actions
 * `keyboardLayoutProvider` provides a keyboard layout
 * `keyboardSecondaryCalloutActionProvider` provides secondary callout actions
 
 You can replace any of these to customize how your keyboard
 extension behaves.
  
 This class also provides you with many observable instances,
 for instance:
 
 * `autocompleteContext` provides autocomplete information
 * `keyboardContext` provides keybard information
 * `keyboardFeedbackSettings` provides feedback settings
 * `keyboardInputCalloutContext` provides callout information
 * `keyboardSecondaryInputCalloutContext` provides secondary callout information
 
 These contexts are injected as environment objects into the
 root view and can be accessed anywhere in the hierarchy.
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
    }
    
    open override func viewWillLayoutSubviews() {
        keyboardContext.sync(with: self)
        super.viewWillLayoutSubviews()
    }
    
    open override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        keyboardContext.sync(with: self)
        super.traitCollectionDidChange(previousTraitCollection)
    }
    
    
    // MARK: - Root View
    
    /**
     This view is used as a wrapper view, to be able to bind
     the keyboard view to properties that affect your layout
     without triggering a view update.
     */
    private struct RootView<ViewType: View>: View {
        
        init(_ view: ViewType) {
            self.view = view
        }
        
        var view: ViewType
        
        @EnvironmentObject private var context: KeyboardContext
        
        var body: some View {
            view.id("\(context.locale)\(context.screenOrientation.isLandscape)")
        }
    }
    
    
    // MARK: - Setup

    /**
     Setup KeyboardKit with a SwiftUI `View`.
     
     This will remove all subviews, then add the view, which
     will be pinned to the edges and resize the extension to
     fit its content.
     
     The function also injects the various contexts into the
     view hiearchy, as `@EnvironmentObject`s.
     */
    open func setup<Content: View>(with view: Content) {
        self.view.subviews.forEach { $0.removeFromSuperview() }
        let view = RootView(view)
            .environmentObject(autocompleteContext)
            .environmentObject(keyboardContext)
            .environmentObject(keyboardFeedbackSettings)
            .environmentObject(keyboardInputCalloutContext)
            .environmentObject(keyboardSecondaryInputCalloutContext)
        let host = KeyboardHostingController(rootView: view)
        host.add(to: self)
    }
    
    
    // MARK: - Combine
    
    var cancellables = Set<AnyCancellable>()
    
    
    
    // MARK: - Properties
    
    /**
     Get the bundle id of the currently active app, that was
     used to initialize the keyboard extension.
     */
    public var activeAppBundleId: String? {
        parent?.value(forKey: "_hostBundleID") as? String
    }
    
    /**
     This internal property always returns the original text
     document proxy, regardless of if another proxy is set.
     */
    var originalTextDocumentProxy: UITextDocumentProxy {
        super.textDocumentProxy
    }
    
    /**
     The shared input view controller. This is registered as
     the keyboard extension is started.
     */
    public static var shared = KeyboardInputViewController()

    /**
     A proxy to the text input object with which this custom
     keyboard is interacting with.
     
     If you set `textInputProxy` to a custom object, it will
     be used instead of the real text document proxy.
     */
    open override var textDocumentProxy: UITextDocumentProxy {
        textInputProxy ?? originalTextDocumentProxy
    }
    
    /**
     A custom text input proxy to which text input should be
     redirected instead of the `textDocumentProxy`.
     
     If you want to modify this proxy, you can override this
     property and apply another `didSet`.
     */
    public var textInputProxy: TextInputProxy? {
        didSet { keyboardContext.sync(with: self) }
    }
    
    
    // MARK: - Observables
    
    /**
     The default, observable autocomplete context.
     */
    public lazy var autocompleteContext = AutocompleteContext()
    
    /**
     The default, observable keyboard context.
     */
    public lazy var keyboardContext = KeyboardContext(controller: self)
    
    /**
     The default, observable keyboard feedback settings.
     */
    public lazy var keyboardFeedbackSettings = KeyboardFeedbackSettings()
    
    /**
     The default, observable input callout context.
     */
    public lazy var keyboardInputCalloutContext = InputCalloutContext()
    
    /**
     The default, observable secondary input callout context.
     */
    public lazy var keyboardSecondaryInputCalloutContext = SecondaryInputCalloutContext(
        actionProvider: keyboardSecondaryCalloutActionProvider,
        actionHandler: keyboardActionHandler)
    
    
    
    // MARK: - Services
    
    /**
     The default autocomplete suggestion provider.
     */
    public lazy var autocompleteProvider: AutocompleteProvider = DisabledAutocompleteProvider()
    
    /**
     The default keyboard action handler.
     */
    public lazy var keyboardActionHandler: KeyboardActionHandler = StandardKeyboardActionHandler(
        inputViewController: self) {
        didSet { refreshProperties() }
    }

    /**
     The default keyboard appearance.
     */
    public lazy var keyboardAppearance: KeyboardAppearance = StandardKeyboardAppearance(
        context: keyboardContext)

    /**
     The default keyboard behavior.
     */
    public lazy var keyboardBehavior: KeyboardBehavior = StandardKeyboardBehavior(
        context: keyboardContext)
    
    /**
     The default keyboard feedback handler.
     
     If you replace this with a custom implementation, it is
     very important to update the action handler as well, if
     you are using the standard one.
     */
    public lazy var keyboardFeedbackHandler: KeyboardFeedbackHandler = StandardKeyboardFeedbackHandler(
        settings: keyboardFeedbackSettings)
    
    /**
     The default keyboard input set provider.
     
     If you replace this with a custom implementation, it is
     very important that `didSet` is called, to register the
     new instance with the `keyboardLayoutProvider`.
     */
    public lazy var keyboardInputSetProvider: KeyboardInputSetProvider = StandardKeyboardInputSetProvider(
        context: keyboardContext) {
        didSet { refreshProperties() }
    }
                    
    /**
     The default keyboard layout provider.
     */
    public lazy var keyboardLayoutProvider: KeyboardLayoutProvider = StandardKeyboardLayoutProvider(
        inputSetProvider: keyboardInputSetProvider)
    
    /**
     The default secondary input action provider.
     */
    public lazy var keyboardSecondaryCalloutActionProvider: SecondaryCalloutActionProvider = StandardSecondaryCalloutActionProvider(
        context: keyboardContext) {
        didSet { refreshProperties() }
    }
    
    
    
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
    
    
    
    // MARK: - Autocomplete
    
    /**
     Perform an autocomplete operation. You can override the
     function to provide custom autocomplete logic.
     
     This function can be called directly or injected into a
     nested service class to avoid bilinear dependencies. It
     is injected into `StandardKeyboardActionHandler`.
     */
    open func performAutocomplete() {
        guard let word = textDocumentProxy.currentWord else { return resetAutocomplete() }
        autocompleteProvider.autocompleteSuggestions(for: word) { [weak self] result in
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
    
    
    
    // MARK: - Deprecated
    
    @available(*, deprecated, message: "Use the stack view-based setup(with:) and provide your own stack view.")
    public lazy var keyboardStackView: UIStackView = {
        let stackView = UIStackView(frame: .zero)
        setup(with: stackView)
        return stackView
    }()
    
    @available(*, deprecated, message: "Change keyboardContext.locale directly.")
    open func changeKeyboardLocale(to locale: Locale) {
        keyboardContext.locale = locale
    }
    
    @available(*, deprecated, message: "Change keyboardContext.keyboardType directly.")
    open func changeKeyboardType(to type: KeyboardType) {
        keyboardContext.keyboardType = type
    }
    
    @available(*, deprecated, message: "This will be removed in 5.0")
    open func setup(with view: UIStackView) {
        self.view.subviews.forEach { $0.removeFromSuperview() }
        view.frame = .zero
        view.axis = .vertical
        view.alignment = .fill
        view.distribution = .equalSpacing
        self.view.addSubview(view, fill: true)
    }
    
}


// MARK: - Private Functions

private extension KeyboardInputViewController {
    
    func refreshProperties() {
        refreshLayoutProvider()
        refreshSecondaryInputCalloutContext()
    }
    
    func refreshLayoutProvider() {
        keyboardLayoutProvider.register(
            inputSetProvider: keyboardInputSetProvider)
    }
    
    func refreshSecondaryInputCalloutContext() {
        keyboardSecondaryInputCalloutContext = SecondaryInputCalloutContext(
            actionProvider: keyboardSecondaryCalloutActionProvider,
            actionHandler: keyboardActionHandler)
    }
    
    func setupLocaleObservation() {
        keyboardContext.$locale.sink { [weak self] in
            guard let self = self else { return }
            let locale = $0
            self.autocompleteProvider.locale = locale
        }.store(in: &cancellables)
    }
    
    func tryChangeToPreferredKeyboardTypeAfterTextDidChange() {
        let context = keyboardContext
        let shouldSwitch = keyboardBehavior.shouldSwitchToPreferredKeyboardTypeAfterTextDidChange()
        guard shouldSwitch else { return }
        keyboardContext.keyboardType = context.preferredKeyboardType
    }
}
