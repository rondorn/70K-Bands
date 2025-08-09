//
//  DetailViewController.swift
//  70000TonsBands
//
//  Created by Ron Dorn on 1/2/15.
//  Copyright (c) 2015 Ron Dorn. All rights reserved.
//

import UIKit
import CoreData

class DetailViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate{
    
    @IBOutlet weak var linkGroup: UIStackView!
    
    @IBOutlet weak var titleLable: UINavigationItem!
    @IBOutlet weak var bandLogo: UIImageView!

    @IBOutlet weak var linkViewTopSpacingConstraint: NSLayoutConstraint!
    @IBOutlet weak var dataViewTopSpacingConstraint: NSLayoutConstraint!
    @IBOutlet weak var notesViewTopSpacingConstraint: NSLayoutConstraint!
    
    var heightConstraint:NSLayoutConstraint = NSLayoutConstraint()
    var linkViewNumber = CGFloat(0)
    var dataViewNumber = CGFloat(0)
    var notesViewNumber = CGFloat(0)
    
    // Break area constants for spacing around links section
    let linkBreakAreaTop = CGFloat(10)    // Space above links section
    let linkBreakAreaBottom = CGFloat(10) // Space below links section
    
    var mainConstraints:[NSLayoutConstraint] = [NSLayoutConstraint]()
    var notesViewConstraints:[NSLayoutConstraint] = [NSLayoutConstraint]()
    
    var everyOtherFlag = true
    var doNotSaveText = false
    
    @IBOutlet weak var vistLinksLable: UILabel!
    @IBOutlet weak var officialUrlButton: UIButton!
    @IBOutlet weak var wikipediaUrlButton: UIButton!
    @IBOutlet weak var youtubeUrlButton: UIButton!
    @IBOutlet weak var metalArchivesButton: UIButton!
    
    @IBOutlet weak var customNotesButton: UIButton!
    @IBOutlet weak var customNotesText: UITextView!
    
    // Language toggle buttons (will be created programmatically)
    var languageToggleStackView: UIStackView?
    var englishButton: UIButton?
    var localLanguageButton: UIButton?
    
    
    @IBOutlet var mainView: UIView!
    @IBOutlet weak var LinksSection: UIView!
    @IBOutlet weak var notesSection: UIView!
    @IBOutlet weak var extraData: UIView!

    @IBOutlet weak var returnToMaster: UINavigationItem!
    
    @IBOutlet weak var PriorityIcon: UIImageView!
    @IBOutlet weak var priorityButtons: UISegmentedControl!
    @IBOutlet weak var priorityView: UITextField!
    
    @IBOutlet weak var Country: UITextField!
    @IBOutlet weak var Genre: UITextField!
    @IBOutlet weak var LastOnCruise: UITextField!
    @IBOutlet weak var NoteWorthy: UITextField!
    
    @IBOutlet weak var topNavView: UINavigationItem!
    @IBOutlet weak var EventView1: UIView!
    @IBOutlet weak var EventView2: UIView!
    @IBOutlet weak var EventView3: UIView!
    @IBOutlet weak var EventView4: UIView!
    @IBOutlet weak var EventView5: UIView!
    
    var eventView1Hidden = false
    var eventView2Hidden = false
    var eventView3Hidden = false
    var eventView4Hidden = false
    var eventView5Hidden = false
    
    var blockSwiping = false;
    
    var backgroundNotesText = "";
    var bandName :String!
    
    // Store both English and translated descriptions
    var englishDescriptionText = ""
    var translatedDescriptionText = ""
    var schedule = scheduleHandler()
    let dataHandle = dataHandler()
    var bandNameHandle = bandNamesHandler()
    let attendedHandle = ShowsAttended()
    var bandPriorityStorage = [String:Int]()
    let bandNotes = CustomBandDescription();
    
    var imagePosition = CGFloat(0);
    
    var eventCount = 0;
    var displayedImaged:UIImage?
    
    var scheduleIndex : [String:[String:String]] = [String:[String:String]]()

    var detailItem: AnyObject? {
        didSet {
            // Update the view.
            self.configureView()
        }
    }
    
    /// Called after the controller's view is loaded into memory. Sets up the UI and loads band details.
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.configureView()
        
        // Ensure back button always says "Back"
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
        self.navigationController?.navigationBar.barStyle = UIBarStyle.blackTranslucent
        self.navigationController?.navigationBar.tintColor = UIColor.white
        self.navigationController?.navigationBar.titleTextAttributes = [NSAttributedString.Key.foregroundColor : UIColor.white]
        
        if (linkViewNumber == 0){
            linkViewNumber = linkViewTopSpacingConstraint.constant
            notesViewNumber = notesViewTopSpacingConstraint.constant
            dataViewNumber = dataViewTopSpacingConstraint.constant
            print ("Notes hight is \(notesViewNumber) 1")
            print ("Notes hight is \(linkViewNumber) 1-linkViewNumber")
            print ("Notes hight is \(dataViewNumber) 1-dataViewNumber")
        }
        print ("Notes hight is \(notesViewNumber) 2")
        print ("Notes hight is \(linkViewNumber) 2-linkViewNumber")
        print ("Notes hight is \(dataViewNumber) 2-dataViewNumber")
        customNotesText.textColor = UIColor.white
        
        // Add Done button to keyboard for iPhone
        if UIDevice.current.userInterfaceIdiom == .phone {
            addDoneButtonToKeyboard()
        }
        
        bandPriorityStorage = dataHandle.readFile(dateWinnerPassed: "")
        
        attendedHandle.loadShowsAttended()
        if (bandName == nil && bandSelected.isEmpty == false){
            bandName = bandSelected
            blockSwiping = false
        }
         //print ("bandName is 2 " + bandName)
        
        // Only provide a default band on iPad, not on iPhone
        if UIDevice.current.userInterfaceIdiom == .pad {
            if ((bandName == nil || bands.isEmpty == true) && bands.count > 0) {
                bandName = bands[0]
                print("Providing default band of " + bandName)
                blockSwiping = false
                
            } else if (bandName == nil || bands.isEmpty == true){
                bands = bandNameHandle.getBandNames()
                if (bands.count > 0){
                    bandName = bands[0]
                    blockSwiping = true
                }
            }
            //catch all if we are still screwed
            if (bandName == nil || bands.isEmpty == true){
                bandName = "Waiting for Data"
                blockSwiping = true
            }
        }
        
        self.title = bandName ?? ""
        print ("bandName is 3 " + (bandName ?? "nil"))
        
        //bandSelected = bandName
        if (bandName != nil && bandName.isEmpty == false && bandName != "None") {
            
            // Use combined image list instead of just band image URL
            let imageURL = CombinedImageListHandler.shared.getImageUrl(for: self.bandName)
            print ("urlString is - Sending imageURL of \(imageURL) for band \(String(describing: bandName))")
            
            // Load image with proper UI refresh
            loadBandImage(imageURL: imageURL, bandName: self.bandName)
            
            print ("Priority for bandName " + bandName + " ", terminator: "")
            print(dataHandle.getPriorityData(bandName))
            
            print ("showFullSchedule");
            showFullSchedule()
            
            
            print ("showBandDetails");
            showBandDetails()
            
            print ("Checking button status:" + bandName)
            disableButtonsIfNeeded()
            disableLinksWithEmptyData();
            
            if (getNotesFontSizeLargeValue() == true){
                customNotesText.font = UIFont(name: customNotesText.font!.fontName, size: 20)
            }
            NotificationCenter.default.addObserver(self, selector: #selector(DetailViewController.rotationChecking), name: UIDevice.orientationDidChangeNotification, object: nil)
            
            setupEventAttendClicks()
            setupSwipeGenstures()
            customNotesText.setContentOffset(.zero, animated: true)
            customNotesText.scrollRangeToVisible(NSRange(location:0, length:0))
            loadComments()
            rotationChecking()
            
            setButtonNames()
            
            // Setup language toggle buttons if translation is supported
            setupLanguageToggleButtons()
            
            if #available(iOS 26.0, *) {
                //topNavView.leftBarButtonItem?.hidesSharedBackground = true
            }
            
        }
        
    }
    
    /// Loads band image with proper UI refresh and error handling
    func loadBandImage(imageURL: String, bandName: String) {
        print("Loading band image for \(bandName) from URL: \(imageURL)")
        
        // Check if URL is valid
        guard !imageURL.isEmpty && imageURL != "http://" else {
            print("Invalid image URL for \(bandName), using default logo")
            DispatchQueue.main.async {
                self.bandLogo.image = UIImage(named: "70000TonsLogo")
                self.imageSizeController(special: "")
            }
            return
        }
        
        let imageHandle = imageHandler()
        
        // Always analyze URL for inversion requirement, even for cached images
        let shouldInvert = imageHandle.shouldApplyInversion(urlString: imageURL)
        print("URL analysis for \(bandName): shouldInvert=\(shouldInvert)")
        
        // Check if internet is available for download
        if isInternetAvailable() {
            print("Internet available for \(bandName), checking cache and downloading if needed")
            
            // First try to load from cache with proper inversion analysis
            let cachedImage = imageHandle.displayImage(urlString: imageURL, bandName: bandName)
            
            DispatchQueue.main.async {
                self.bandLogo.image = cachedImage
                self.imageSizeController(special: "")
            }
            
            // If no cached image exists, download it
            if cachedImage == UIImage(named: "70000TonsLogo") {
                print("No cached image for \(bandName), downloading from URL")
                downloadAndCacheImageWithInversion(imageURL: imageURL, bandName: bandName, imageHandle: imageHandle)
            }
        } else {
            print("No internet available for \(bandName), loading from cache only")
            loadImageFromCacheWithInversion(bandName: bandName, imageURL: imageURL, imageHandle: imageHandle)
        }
    }
    
    /// Loads image from local cache with proper inversion analysis
    func loadImageFromCacheWithInversion(bandName: String, imageURL: String, imageHandle: imageHandler) {
        let imageStore = URL(fileURLWithPath: getDocumentsDirectory().appendingPathComponent(bandName + ".png"))
        
        if let imageData = UIImage(contentsOfFile: imageStore.path) {
            print("Loading cached image for \(bandName) with inversion analysis")
            let processedImage = imageHandle.processImage(imageData, urlString: imageURL)
            DispatchQueue.main.async {
                self.bandLogo.image = processedImage
                self.imageSizeController(special: "")
            }
        } else {
            print("No cached image for \(bandName), using default logo")
            DispatchQueue.main.async {
                self.bandLogo.image = UIImage(named: "70000TonsLogo")
                self.imageSizeController(special: "")
            }
        }
    }
    
    /// Downloads and caches image from URL with proper inversion analysis
    func downloadAndCacheImageWithInversion(imageURL: String, bandName: String, imageHandle: imageHandler) {
        imageHandle.downloadAndCacheImage(urlString: imageURL, bandName: bandName) { [weak self] processedImage in
            guard let self = self else { return }
            
            DispatchQueue.main.async {
                // Only update if still showing the same band
                if self.bandName == bandName {
                    if let image = processedImage {
                        self.bandLogo.image = image
                        print("Updated image for \(bandName) with proper inversion")
                    } else {
                        self.bandLogo.image = UIImage(named: "70000TonsLogo")
                        print("Failed to download image for \(bandName), using default logo")
                    }
                    self.imageSizeController(special: "")
                }
            }
        }
    }
    
    /// Checks if the current text is actually translated (not English)
    @available(iOS 18.0, *)
    private func isCurrentTextTranslated(currentText: String) -> Bool {
        // If we don't have English text to compare with, assume current text is English
        guard !englishDescriptionText.isEmpty else {
            return false
        }
        
        // If current text is empty, it's not translated
        guard !currentText.isEmpty else {
            return false
        }
        
        // If current text matches English text exactly, it's not translated
        if currentText.trimmingCharacters(in: .whitespacesAndNewlines) == 
           englishDescriptionText.trimmingCharacters(in: .whitespacesAndNewlines) {
            return false
        }
        
        // Check if current text contains "Translated from English" in various languages
        let translatedFromEnglishTexts = [
            "Translated from English",      // English fallback
            "Aus dem Englischen übersetzt", // German
            "Vertaald uit het Engels",      // Dutch
            "Traduit de l'anglais",         // French
            "Käännetty englannista",        // Finnish
            "Traduzido do inglês",          // Portuguese
            "Traducido del inglés"          // Spanish
        ]
        
        for translatedText in translatedFromEnglishTexts {
            if currentText.contains(translatedText) {
                print("DEBUG: Found translation marker: \(translatedText)")
                return true
            }
        }
        
        // Legacy check for old translation markers (for backward compatibility)
        let legacyMarkers = ["[DE]", "[ES]", "[FR]", "[PT]", "[DA]", "[FI]", "🌐 Translation"]
        for marker in legacyMarkers {
            if currentText.contains(marker) {
                print("DEBUG: Found legacy translation marker: \(marker)")
                return true
            }
        }
        
        // If text is significantly different from English and we have a translation preference set
        let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
        if currentLangCode != "EN" && 
           BandDescriptionTranslator.shared.currentLanguagePreference != "EN" &&
            currentText.count > englishDescriptionText.count * Int(0.7) { // At least 70% of original length
            return true
        }
        
        return false
    }

    /// Sets up the translation buttons if translation is supported
    func setupLanguageToggleButtons() {
        guard #available(iOS 18.0, *) else {
            return // BandDescriptionTranslator requires iOS 18.0+
        }
        
        guard BandDescriptionTranslator.shared.isTranslationSupported() else {
            return // Don't show if translation isn't supported
        }
        
        guard let safeBandName = bandName else { 
            print("DEBUG: No band name available")
            return 
        }
        
        let currentLangCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
        let hasBeenTranslated = BandDescriptionTranslator.shared.hasBandBeenTranslated(safeBandName)
        
        // Check if we have a translated cache file
        let hasTranslatedCache = (currentLangCode != "EN") && 
                                BandDescriptionTranslator.shared.hasTranslatedCacheFile(for: safeBandName, targetLanguage: currentLangCode)
        
        // Check if the current text is actually translated by comparing with English text
        let currentText = customNotesText?.text ?? ""
        let isCurrentTextActuallyTranslated = isCurrentTextTranslated(currentText: currentText) || hasTranslatedCache
        
        print("DEBUG: Band: \(safeBandName)")
        print("DEBUG: Language: \(currentLangCode)")
        print("DEBUG: Has been translated: \(hasBeenTranslated)")
        print("DEBUG: Current text is actually translated: \(isCurrentTextActuallyTranslated)")
        print("DEBUG: English text length: \(englishDescriptionText.count)")
        print("DEBUG: Current text length: \(currentText.count)")
        
        // Remove ALL existing buttons if they exist
        languageToggleStackView?.removeFromSuperview()
        englishButton?.removeFromSuperview()
        localLanguageButton?.removeFromSuperview()
        englishButton = nil
        localLanguageButton = nil
        
        // Also remove any buttons that might be directly added to notesSection
        for subview in notesSection.subviews {
            if let button = subview as? UIButton {
                print("DEBUG: Removing old button: \(button.titleLabel?.text ?? "unknown")")
                button.removeFromSuperview()
            }
            if let stackView = subview as? UIStackView {
                for arrangedSubview in stackView.arrangedSubviews {
                    if let button = arrangedSubview as? UIButton {
                        print("DEBUG: Removing old button from stack: \(button.titleLabel?.text ?? "unknown")")
                        button.removeFromSuperview()
                    }
                }
                if stackView != languageToggleStackView {
                    print("DEBUG: Removing old stack view")
                    stackView.removeFromSuperview()
                }
            }
        }
        
        // Create container for the single button
        languageToggleStackView = UIStackView()
        guard let stackView = languageToggleStackView else { return }
        
        stackView.axis = .horizontal
        stackView.distribution = .fill
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        
        // Determine which button to show based on ACTUAL current text state
        if isCurrentTextActuallyTranslated {
            print("DEBUG: Showing RESTORE button - text is currently translated")
            // Show "Restore to English" button
            let restoreButton = UIButton(type: .system)
            restoreButton.setTitle(BandDescriptionTranslator.shared.getLocalizedRestoreButtonText(for: currentLangCode), for: .normal)
            restoreButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            restoreButton.backgroundColor = UIColor.systemOrange
            restoreButton.setTitleColor(.white, for: .normal)
            restoreButton.layer.cornerRadius = 8
            restoreButton.addTarget(self, action: #selector(restoreToEnglishTapped), for: .touchUpInside)
            
            stackView.addArrangedSubview(restoreButton)
            englishButton = restoreButton // Store reference
            
        } else {
            print("DEBUG: Showing TRANSLATE button - text is currently in English")
            // Show "Translate to [Language]" button
            let translateButton = UIButton(type: .system)
            translateButton.setTitle(BandDescriptionTranslator.shared.getLocalizedTranslateButtonText(for: currentLangCode), for: .normal)
            translateButton.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .medium)
            translateButton.backgroundColor = UIColor.systemBlue
            translateButton.setTitleColor(.white, for: .normal)
            translateButton.layer.cornerRadius = 8
            translateButton.addTarget(self, action: #selector(translateButtonTapped), for: .touchUpInside)
            
            stackView.addArrangedSubview(translateButton)
            localLanguageButton = translateButton // Store reference
        } 
        
        // Only add stack view if we have a button to show
        if !stackView.arrangedSubviews.isEmpty {
            // Add stack view to the main view, positioned above the priority buttons
            view.addSubview(stackView)
            
            // Set up constraints - position above the priority buttons widget
            NSLayoutConstraint.activate([
                stackView.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 16),
                stackView.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -16),
                stackView.bottomAnchor.constraint(equalTo: priorityButtons.topAnchor, constant: -16),
                stackView.heightAnchor.constraint(equalToConstant: 44)
            ])
        }
    }
    
    /// Updates the notes text view constraints to make room for translation button
    func updateNotesTextViewConstraints() {
        // No longer needed since button is positioned outside the notes section
        // Button is now positioned above the priority buttons widget
    }
    
    /// Updates the translation button display (replaced old two-button system)
    func updateLanguageButtonStates() {
        // This method now just refreshes the single button setup
        setupLanguageToggleButtons()
    }
    
    @objc func englishButtonTapped() {
        // This method is now an alias for restoreToEnglishTapped for compatibility
        restoreToEnglishTapped()
    }
    
    @objc func translateButtonTapped() {
        guard #available(iOS 18.0, *) else { return }
        
        guard let textView = customNotesText, let safeBandName = bandName else { return }
        
        print("DEBUG: Starting translation for band: \(safeBandName)")
        
        // Show Apple's translation overlay
        BandDescriptionTranslator.shared.showTranslationOverlay(for: textView, in: self) { [weak self] (success: Bool) in
            DispatchQueue.main.async {
                if success {
                    print("DEBUG: Translation completed successfully")
                    // Force a button refresh after a small delay to ensure text is updated
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        self?.setupLanguageToggleButtons()
                    }
                } else {
                    print("DEBUG: Translation failed")
                }
            }
        }
    }
    
    @objc func restoreToEnglishTapped() {
        guard #available(iOS 18.0, *) else { return }
        
        guard let safeBandName = bandName else { return }
        
        print("DEBUG: Restoring to English for band: \(safeBandName)")
        
        // Get the current language code to know which cache to delete
        let currentLanguageCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
        
        // Show loading indicator
        showToast(message: "🔄 Restoring to English...")
        
        // Use the comprehensive restore method
        BandDescriptionTranslator.shared.restoreToEnglish(
            for: safeBandName,
            currentLanguage: currentLanguageCode,
            bandNotes: bandNotes
        ) { [weak self] englishText in
            guard let self = self else { return }
            
            // Reset language preference to English FIRST
            BandDescriptionTranslator.shared.currentLanguagePreference = "EN"
            
            if let englishText = englishText {
                // Update both the display text and stored English text
                self.customNotesText?.text = englishText
                self.englishDescriptionText = englishText
                
                print("DEBUG: Successfully restored to English for \(safeBandName)")
                self.showToast(message: "✅ Restored to English")
            } else {
                // Fallback to existing English text if download failed
                self.customNotesText?.text = self.englishDescriptionText
                print("DEBUG: Fallback to existing English text for \(safeBandName)")
                self.showToast(message: "⚠️ Restored to cached English")
            }
            
            // Force a button refresh after a small delay to ensure state is updated
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                self.setupLanguageToggleButtons()
            }
        }
    }
    
    @objc func localLanguageButtonTapped() {
        // This method is kept for compatibility but now calls translateButtonTapped
        translateButtonTapped()
    }
    
    /// Displays the description in the currently selected language
    func displayDescriptionInCurrentLanguage() {
        guard let safeBandName = bandName else { return }
        
        if #available(iOS 18.0, *) {
            let currentLanguageCode = BandDescriptionTranslator.shared.getCurrentLanguageCode()
            
            // First, check if we have a translated cache file for the user's language
            if currentLanguageCode != "EN" && 
               BandDescriptionTranslator.shared.hasTranslatedCacheFile(for: safeBandName, targetLanguage: currentLanguageCode) {
                
                print("DEBUG: Found translated cache file for \(safeBandName) in \(currentLanguageCode)")
                
                // Load the translated text from cache
                BandDescriptionTranslator.shared.loadTranslatedTextFromDisk(for: safeBandName, targetLanguage: currentLanguageCode) { [weak self] translatedText in
                    if let translatedText = translatedText {
                        self?.customNotesText.text = translatedText
                        // Set preference to match the cached language
                        BandDescriptionTranslator.shared.currentLanguagePreference = currentLanguageCode
                        print("DEBUG: Loaded translated text from cache for \(safeBandName)")
                        
                        // Update buttons to reflect translated state
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            self?.setupLanguageToggleButtons()
                        }
                    } else {
                        // Cache file exists but couldn't load, fall back to English
                        self?.customNotesText.text = self?.englishDescriptionText
                        BandDescriptionTranslator.shared.currentLanguagePreference = "EN"
                    }
                }
            } else {
                // No translated cache file, show English
                customNotesText.text = englishDescriptionText
                BandDescriptionTranslator.shared.currentLanguagePreference = "EN"
                print("DEBUG: No translated cache found for \(safeBandName), showing English")
            }
        } else {
            // iOS < 18.0, always show English
            customNotesText.text = englishDescriptionText
        }
    }
    
    func setupSwipeGenstures(){
        
        var swipeRight = UISwipeGestureRecognizer(target: self, action: "swipeRightAction:")
        swipeRight.direction = UISwipeGestureRecognizer.Direction.right
        self.mainView.addGestureRecognizer(swipeRight)
        
        var swipeLeft = UISwipeGestureRecognizer(target: self, action: "swipeLeftAction:")
        swipeLeft.direction = UISwipeGestureRecognizer.Direction.left
        self.mainView.addGestureRecognizer(swipeLeft)
        
    }
    
    func resetScheduleGUI(){
        
        LinksSection.isHidden = false
        notesSection.isHidden = false
        extraData.isHidden = false
        
        vistLinksLable.isHidden = false
        officialUrlButton.isHidden = false
        wikipediaUrlButton.isHidden = false
        youtubeUrlButton.isHidden = false
        metalArchivesButton.isHidden = false
        
        vistLinksLable.text = NSLocalizedString("visitBands", comment: "Visit Band Via") + ":"
        
        disableLinksWithEmptyData()
        
        Country.isHidden = false
        Genre.isHidden = false
        LastOnCruise.isHidden = false
        NoteWorthy.isHidden = false
        
        // Apply break areas around links section
        dataViewTopSpacingConstraint.constant = dataViewNumber + linkBreakAreaBottom
        linkViewTopSpacingConstraint.constant = linkViewNumber + linkBreakAreaTop
        
        if (everyOtherFlag == false){
            everyOtherFlag = true
            notesViewTopSpacingConstraint.constant = notesViewNumber + linkBreakAreaBottom + 1
            print ("Notes hight is \(notesViewNumber) 3")
            print ("Notes hight is \(linkViewNumber) 3-linkViewNumber")
            print ("Notes hight is \(dataViewNumber) 3-dataViewNumber")
        } else {
            everyOtherFlag = false
            notesViewTopSpacingConstraint.constant = notesViewNumber + linkBreakAreaBottom - 1
            print ("Notes hight is \(notesViewNumber) 4")
            print ("Notes hight is \(linkViewNumber) 4-linkViewNumber")
            print ("Notes hight is \(dataViewNumber) 4-dataViewNumber")
        }
        
        if (eventView1Hidden == true){
            EventView1.isHidden = false
            eventView1Hidden = false
        } else {
            var eventTypeText1 = EventView1.viewWithTag(3) as! UILabel
            eventTypeText1.text = ""
        }
        
        if (eventView2Hidden == true){
            EventView2.isHidden = false
            eventView2Hidden = false
        } else {
            var eventTypeText2 = EventView2.viewWithTag(3) as! UILabel
            eventTypeText2.text = ""
        }
        if (eventView3Hidden == true){
            EventView3.isHidden = false
            eventView3Hidden = false
        } else {
            var eventTypeText3 = EventView3.viewWithTag(3) as! UILabel
            eventTypeText3.text = ""
        }
        if (eventView4Hidden == true){
            EventView4.isHidden = false
            eventView4Hidden = false
        } else {
            var eventTypeText4 = EventView4.viewWithTag(3) as! UILabel
            eventTypeText4.text = ""
        }
        if (eventView5Hidden == true){
            EventView5.isHidden = false
            eventView5Hidden = false
        } else {
            var eventTypeText5 = EventView5.viewWithTag(3) as! UILabel
            eventTypeText5.text = ""
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    func setupEventAttendClicks(){
            
        let gesture1 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView1.addGestureRecognizer(gesture1)
        
        let gesture2 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView2.addGestureRecognizer(gesture2)
 
        let gesture3 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView3.addGestureRecognizer(gesture3)
        
        let gesture4 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView4.addGestureRecognizer(gesture4)
        
        let gesture5 = UITapGestureRecognizer(target: self, action:  #selector(self.clickedOnEvent))
        self.EventView5.addGestureRecognizer(gesture5)
    }
    
    //used to disable keyboard input for event fields
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        print ("Started editing");
        return false
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?){
        print ("Ended editing");
        notesSection.endEditing(true)
        super.touchesBegan(touches, with: event)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            splitViewController?.preferredDisplayMode = UISplitViewController.DisplayMode.allVisible
        }
        
        // Ensure back button always says "Back" when navigating from this view
        let backItem = UIBarButtonItem()
        backItem.title = "Back"
        self.navigationItem.backBarButtonItem = backItem
        
        loadComments()
        super.viewDidAppear(animated)
                
    }
    
    func imageSizeController(special: String){
        
        let screenSize = UIScreen.main.bounds
        
        if (officialUrlButton.isHidden == false){
            if (special == "top"){
                self.bandLogo.contentMode = UIView.ContentMode.top
                self.bandLogo.contentMode = UIView.ContentMode.scaleAspectFit
            } else if (special == "scale"){
                self.bandLogo.contentMode = UIView.ContentMode.top
                self.bandLogo.contentMode = UIView.ContentMode.scaleAspectFit
            }
            customNotesText.scrollRangeToVisible(NSRange(location:0, length:0))
            self.bandLogo.sizeToFit()
        } else {
            
            //self.customNotesText.textContainerInset = UIEdgeInsets(top: 50, left: 0, bottom: 5, right: 0)
            customNotesText.scrollRangeToVisible(NSRange(location:0, length:0))
            self.bandLogo.contentMode = UIView.ContentMode.top
            self.bandLogo.contentMode = UIView.ContentMode.scaleAspectFit
            //self.bandLogo.sizeToFit()
        }
        
        if (eventCount <= 1){
            //customNotesText.frame.size.height = screenSize.height * 0.47
            //customNotesText.scrollRangeToVisible(NSRange(location:0, length:0))
        }
        
        self.bandLogo.contentMode = UIView.ContentMode.scaleAspectFit
        self.bandLogo.clipsToBounds = true
        

    }
    
    func disableLinksWithEmptyData(){
        
        if (bandNameHandle.getofficalPage(bandName).isEmpty == true || bandNameHandle.getofficalPage(bandName) == "Unavailable"){
            officialUrlButton.isHidden = true;
            wikipediaUrlButton.isHidden = true;
            youtubeUrlButton.isHidden = true;
            metalArchivesButton.isHidden = true;
            linkGroup.isHidden = true
            vistLinksLable.isHidden = true;
            LinksSection.isHidden = true;
            // Adjust for both the links section height and break areas when hidden
            notesViewTopSpacingConstraint.constant = notesViewTopSpacingConstraint.constant - (65 + linkBreakAreaTop + linkBreakAreaBottom)
        } else {
            officialUrlButton.isHidden = false;
            wikipediaUrlButton.isHidden = false;
            youtubeUrlButton.isHidden = false;
            metalArchivesButton.isHidden = false;
            linkGroup.isHidden = false
            vistLinksLable.isHidden = false;
            LinksSection.isHidden = false;
        }
    }
  
    func showBandDetails(){
        
        if (UIApplication.shared.statusBarOrientation  == .portrait ||
            UIDevice.current.userInterfaceIdiom == .pad){
            
            var allDetailsHidden = true
            let bandCountry = bandNameHandle.getBandCountry(bandName)
            print ("Band County is \(bandCountry)")
            
            
            Country.textColor = UIColor.lightGray
            Genre.textColor = UIColor.lightGray
            LastOnCruise.textColor = UIColor.lightGray
            NoteWorthy.textColor = UIColor.lightGray
            
            Country.font = UIFont.boldSystemFont(ofSize: 15)
            Genre.font = UIFont.boldSystemFont(ofSize: 15)
            LastOnCruise.font = UIFont.boldSystemFont(ofSize: 15)
            NoteWorthy.font = UIFont.boldSystemFont(ofSize: 15)
            
            if (bandCountry.isEmpty == true){
                Country.text = "";
                Country.isHidden = true
                extraData.isHidden = true

            } else {
                let countryLablel = NSLocalizedString("country", comment: "Country")
                Country.text = countryLablel + ":" + getTabs(label: countryLablel) + bandCountry
                Country.isHidden = false
                allDetailsHidden = false
            }
            
            let bandGenre = bandNameHandle.getBandGenre(bandName)
            if (bandGenre.isEmpty == true){
                Genre.text = ""
                Genre.isHidden = true

            } else {
                let genreLabel = NSLocalizedString("genre", comment: "Genre")
                Genre.text = genreLabel + ":" + getTabs(label: genreLabel) + bandGenre
                Genre.isHidden = false
                allDetailsHidden = false
            }
 
            let lastOnCruise = bandNameHandle.getPriorYears(bandName)
            if (lastOnCruise.isEmpty == true){
                LastOnCruise.text = ""
                LastOnCruise.isHidden = true

            } else {
                let lastOnCruiseLabel = NSLocalizedString("Last On Cruise", comment: "Last On Cruise")
                LastOnCruise.text = lastOnCruiseLabel + ":" + getTabs(label: lastOnCruiseLabel) + lastOnCruise
                LastOnCruise.isHidden = false
                allDetailsHidden = false
            }
            
            let bandNoteWorthy = bandNameHandle.getBandNoteWorthy(bandName)
            if (bandNoteWorthy.isEmpty == true){
                NoteWorthy.text = ""
                NoteWorthy.isHidden = true

            } else {
                let noteWorthyLabel = NSLocalizedString("Note", comment: "Note")
                NoteWorthy.text = noteWorthyLabel + ":" + getTabs(label: "Note") + bandNoteWorthy
                NoteWorthy.isHidden = false
                allDetailsHidden = false
            }
            
            if (allDetailsHidden == true){
                extraData.isHidden = true
            } else {
                extraData.isHidden = false
            }
            
        } else if (UIDevice.current.userInterfaceIdiom == .phone) {
            Country.text = ""
            Genre.text = ""
            LastOnCruise.text = ""
            NoteWorthy.text = ""
        }
        
        if (bandName.isEmpty) {
            bandName = "";
            priorityButtons.isHidden = true
            Country.text = ""
            Genre.text = ""
            NoteWorthy.text = ""
            LastOnCruise.text = ""
            officialUrlButton.isHidden = true;
            wikipediaUrlButton.isHidden = true;
            youtubeUrlButton.isHidden = true;
            metalArchivesButton.isHidden = true;
            customNotesText.isHidden = true;
            customNotesButton.isHidden = true;
            vistLinksLable.isHidden = true;
            LinksSection.isHidden = true;
            
            officialUrlButton.isEnabled = false;
            wikipediaUrlButton.isEnabled = false;
            youtubeUrlButton.isEnabled = false;
            metalArchivesButton.isEnabled = false;
        
        } else {
            officialUrlButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 1, bottom: 0, right: 1)
            wikipediaUrlButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            youtubeUrlButton.imageEdgeInsets = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            metalArchivesButton.imageEdgeInsets = UIEdgeInsets(top: -1, left: 0, bottom: -1, right: 0)
        }
        
    }
    
    func getTabs(label: String)-> String {
        
        var tabs = ""
        
        if (label.count <= 5){
            tabs = "\t\t\t\t"
            
        } else  if (label.count <= 10){
            tabs = "\t\t\t"
            
        } else if (label.count <= 14){
            tabs = "\t\t"
            
        } else {
            tabs = "\t"
        }
        
        return tabs
        
    }
    
    func textViewDidBeginEditing(_ textView: UITextView) {
        print ("Editing of commentFile has begun")
        if (customNotesText.text == "Add your custom notes here"){
            customNotesText.text = ""
            customNotesText.textColor = UIColor.white
        }
        
    }
    

    func loadComments(){
        guard let safeBandName = bandName else { return }
        
        print("Loading comments for \(safeBandName)")
        
        // First try to load from cache
        let noteText = bandNotes.getDescription(bandName: safeBandName)
        englishDescriptionText = noteText // Store the English version
        
        customNotesText.text = noteText
        customNotesText.textColor = UIColor.white
        setNotesHeight()
        
        if (customNotesText.text.contains("!!!!https://")){
            doNotSaveText = true
            customNotesText.text = customNotesText.text.replacingOccurrences(of: "!!!!https://", with: "https://")
            customNotesText.dataDetectorTypes = [.link]
            customNotesText.isEditable = false
            customNotesText.isSelectable = true
            customNotesText.isUserInteractionEnabled = true
        }
        
        if (bandNameHandle.getBandNoteWorthy(safeBandName).isEmpty == false){
            customNotesText.text = "\n" + customNotesText.text
            englishDescriptionText = "\n" + englishDescriptionText // Update stored English text too
        }
        
        // Check if we need to download description from URL
        let noteUrl = bandNotes.getDescriptionUrl(safeBandName)
        
        if shouldDownloadDescription(noteText: noteText, noteUrl: noteUrl) {
            downloadAndDisplayDescription(bandName: safeBandName, noteUrl: noteUrl)
        } else {
            // If we have text and translation is supported, check current language preference
            if #available(iOS 18.0, *) {
                if BandDescriptionTranslator.shared.isTranslationSupported() {
                    displayDescriptionInCurrentLanguage()
                }
            }
        }
    }
    
    /// Determines if description should be downloaded from URL
    func shouldDownloadDescription(noteText: String, noteUrl: String) -> Bool {
        // Download if:
        // 1. No local description exists or it's the default placeholder
        // 2. URL is available
        // 3. Internet is available
        let needsDownload = noteText.isEmpty || 
                           noteText.starts(with: "Comment text is not available yet") ||
                           noteText.starts(with: "Comment text is not available yet. Please wait")
        
        let hasUrl = !noteUrl.isEmpty
        let hasInternet = isInternetAvailable()
        
        print("Description download check: needsDownload=\(needsDownload), hasUrl=\(hasUrl), hasInternet=\(hasInternet)")
        
        return needsDownload && hasUrl && hasInternet
    }
    
    /// Downloads and displays description from URL
    func downloadAndDisplayDescription(bandName: String, noteUrl: String) {
        print("Downloading description for \(bandName) from \(noteUrl)")
        
        guard let url = URL(string: noteUrl) else {
            print("Invalid description URL for \(bandName): \(noteUrl)")
            return
        }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Error downloading description for \(bandName): \(error)")
                return
            }
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  let data = data,
                  let descriptionText = String(data: data, encoding: .utf8) else {
                print("Invalid response for \(bandName) description download")
                return
            }
            
            // Don't save if it's an HTML error page
            guard !descriptionText.starts(with: "<!DOCTYPE") else {
                print("Received HTML error page for \(bandName) description")
                return
            }
            
            // Cache the downloaded description
            let commentFileName: String = self.bandNotes.getNoteFileName(bandName: bandName)
            let commentFile: URL = directoryPath.appendingPathComponent(commentFileName)
            
            do {
                try descriptionText.write(to: commentFile, atomically: false, encoding: .utf8)
                print("Successfully cached description for \(bandName)")
            } catch {
                print("Error caching description for \(bandName): \(error)")
            }
            
            // Update UI on main thread
            DispatchQueue.main.async {
                // Only update if still showing the same band
                if self.bandName == bandName {
                    // Process the downloaded text the same way as cached text
                    let processedText = self.bandNotes.removeSpecialCharsFromString(text: descriptionText)
                    self.englishDescriptionText = processedText // Store English version
                    self.customNotesText.text = processedText
                    self.setNotesHeight()
                    self.showBandDetails()
                    self.customNotesText.setNeedsDisplay()
                    self.customNotesText.layoutIfNeeded()
                    print("Updated description for \(bandName)")
                    
                    // Check if we should display in translated language
                    if #available(iOS 18.0, *) {
                        if BandDescriptionTranslator.shared.isTranslationSupported() {
                            self.displayDescriptionInCurrentLanguage()
                        }
                    }
                }
            }
        }.resume()
    }
    
    func saveComments(){
        
        if (bandName != nil && bandName.isEmpty == false){
            let custCommentFile = directoryPath.appendingPathComponent( bandName + "_comment.note-cust")

            if (customNotesText.text.starts(with: "Comment text is not available yet") == true){
                print ("commentFile being deleted -- Default waiting message");
                removeBadNote(commentFile: custCommentFile)
                
            } else if (doNotSaveText == true){
                    print ("Description contains link, edit not available");
                    
            } else if (customNotesText.text.count < 2){
                print ("commentFile being deleted -- less then 2 characters");
                removeBadNote(commentFile: custCommentFile)
                
            } else if (bandNotes.custMatchesDefault(customNote: customNotesText.text, bandName: bandName) == true){
                print ("Description has not changed");
                
            } else if #available(iOS 18.0, *), isCurrentTextTranslated(currentText: customNotesText.text) {
                print ("DEBUG: Text is translated - NOT saving as custom English description");
                print ("DEBUG: Translated text should only be saved in translation cache files, not as custom English")
                // Don't save translated text as custom English description
                
            } else {
                print ("saving commentFile");
                
                let commentString = self.customNotesText.text;
                DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                    print ("Writting commentFile " + commentString! + "- \(custCommentFile)")

                    do {
                        try commentString?.write(to: custCommentFile, atomically: false, encoding: String.Encoding.utf8)
                    } catch {
                        print("commentFile " + error.localizedDescription)
                    }
                }
            }

        }
    }
    
    func removeBadNote(commentFile: URL){
        do {
            print ("commentFile being deleted \(commentFile) - removeBadNote")
            try FileManager.default.removeItem(atPath: commentFile.path)
            
        } catch let error as NSError {
            print ("Encountered an error removing old commentFile " + error.debugDescription)
        }
        
        if (FileManager.default.fileExists(atPath: commentFile.path) == true){
            print ("ERROR: commentFile was not deleted")
        } else {
            print ("CONFIRMATION: commentFile was deleted")
            loadComments()
        }
    }
    
    override func viewWillDisappear(_ animated : Bool) {
        super.viewWillDisappear(animated)
        saveComments()
    }
    
    @objc func rotationChecking(){
        
        //need to hide things to make room in the detail display
        if(UIApplication.shared.statusBarOrientation  == .landscapeLeft || UIApplication.shared.statusBarOrientation  == .landscapeRight){
            //if schdule exists, hide the web links that probably dont work anyway
            //only needed on iPhones. iPads have enought room for both

            print ("schedule.schedulingData[bandName] is \(schedule.schedulingData[bandName])")
            if (schedule.schedulingData[bandName]?.isEmpty == false && UIDevice.current.userInterfaceIdiom == .phone){
                
                LinksSection.isHidden = true

                vistLinksLable.isHidden = true
                officialUrlButton.isHidden = true
                wikipediaUrlButton.isHidden = true
                youtubeUrlButton.isHidden = true
                metalArchivesButton.isHidden = true
            
                priorityButtons.isHidden = true
                PriorityIcon.isHidden = true
                
            } else {
                LinksSection.isHidden = false

                vistLinksLable.isHidden = false
                officialUrlButton.isHidden = false
                wikipediaUrlButton.isHidden = false
                youtubeUrlButton.isHidden = false
                metalArchivesButton.isHidden = false
            
                priorityButtons.isHidden = false
                PriorityIcon.isHidden = false
                
                disableLinksWithEmptyData()
            }
            
            
            if (UIDevice.current.userInterfaceIdiom == .phone){
                extraData.isHidden = true
                extraData.sizeToFit()
                notesSection.isHidden = true
                customNotesText.text = "";
                setNotesHeight()


            }
            
            imageSizeController(special: "top")
            
        } else {

            if (UIDevice.current.userInterfaceIdiom == .phone){
                
                extraData.isHidden = false
                notesSection.isHidden = false
                
                if (bandNameHandle.getofficalPage(bandName).isEmpty == false && bandNameHandle.getofficalPage(bandName) != "Unavailable"){
                    LinksSection.isHidden = false
                    vistLinksLable.isHidden = false
                    officialUrlButton.isHidden = false
                    wikipediaUrlButton.isHidden = false
                    youtubeUrlButton.isHidden = false
                    metalArchivesButton.isHidden = false
                    LinksSection.sizeToFit()
                }
                
                extraData.sizeToFit()
                loadComments()
                
                priorityButtons.isHidden = false
                PriorityIcon.isHidden = false
                
            }
            
            imageSizeController(special: "scale")
        }

        showBandDetails();
    }
    
    func setNotesHeight(){

        customNotesText.scrollRangeToVisible(NSRange(location:0, length:0))

    }
    
    func setButtonNames(){
        
        let MustSee = NSLocalizedString("Must", comment: "A Must See Band")
        let MightSee: String = NSLocalizedString("Might", comment: "A Might See Band")
        let WontSee: String = NSLocalizedString("Wont", comment: "A Wont See Band")
        let UnknonwSee: String = NSLocalizedString("Unknown", comment: "A Wont See Band")
        
        priorityButtons.setTitle(MustSee, forSegmentAt: 1)
        priorityButtons.setTitle(MightSee, forSegmentAt: 2)
        priorityButtons.setTitle(WontSee, forSegmentAt: 3)

        priorityButtons.setTitle(UnknonwSee, forSegmentAt: 0)
        
        let font = UIFont.boldSystemFont(ofSize: 11)
        let fontColor = [NSAttributedString.Key.foregroundColor: UIColor.white, NSAttributedString.Key.font: font]
        priorityButtons.setTitleTextAttributes(fontColor, for: .normal)
        
        print ("Setting band priority  from Details, selelcted should be black font and background light gray")
        
        print ("Setting priorityButtons for \(bandName ?? "nil") - bandPriorityStorage")
        
        // Only proceed if bandName is not nil
        guard let safeBandName = bandName else {
            print("bandName is nil, skipping priority button setup")
            return
        }
        
        if (bandPriorityStorage[safeBandName] == nil){
            bandPriorityStorage[safeBandName] = 0
        }
        
        if (bandPriorityStorage[safeBandName] != nil){
            priorityButtons.selectedSegmentIndex = bandPriorityStorage[safeBandName]!
            let priorityImageName = getPriorityGraphic(bandPriorityStorage[safeBandName]!)
            // Avoid CUICatalog errors by checking for empty string before UIImage(named:)
            if priorityImageName.isEmpty {
                PriorityIcon.image = UIImage()
            } else {
                PriorityIcon.image = UIImage(named: priorityImageName) ?? UIImage()
            }
            print ("Setting priorityButtons for \(safeBandName) - \(priorityImageName)")
            let fontColorSelected = [NSAttributedString.Key.foregroundColor: UIColor.black, NSAttributedString.Key.font: font]
            priorityButtons.setTitleTextAttributes(fontColorSelected, for: .selected)
            priorityButtons.setTitleTextAttributes(fontColorSelected, for: .highlighted)
            priorityButtons.selectedSegmentTintColor = UIColor.lightGray
        }
    }
    
    @IBAction func swipeRightAction(_ sender: Any) {
        swipeNextRecord(direction: "Previous");
    }
        
    @IBAction func swipeLeftAction(_ sender: Any) {
        swipeNextRecord(direction: "Next");
    }
    
    func swipeNextRecord(direction: String){
            
        var loopThroughBandList = [String]()
        var previousInLoop = ""
        var bandNameNext = ""
        var timeView = true
        
        //disable swiping if needed
        if (blockSwiping == true){
            return
        }
        
        //build universal list of bands for all view types
        print ("Checking next bandName currentBandList is \(currentBandList)")
        for index in currentBandList {
            
            var bandInIndex = getBandFromIndex(index: index)
            
            //disallow back to back duplicates
            if (bandInIndex == previousInLoop){
                continue
            }
            previousInLoop = bandInIndex
            
            loopThroughBandList.append(bandInIndex)
            
            //determine if time applies here
            var indexSplit = index.components(separatedBy: ":")
            if (indexSplit.count == 1){
                timeView = false
            }
        }
        
        //find where in list
        var counter = 0
        let sizeBands = loopThroughBandList.count
        print ("Checking next bandName list of bands is \(loopThroughBandList)")
        for index in loopThroughBandList{
            
            var indexSplit = index.components(separatedBy: ":")
            var bandNamefromIndex = indexSplit[1]
            var timeIndex = indexSplit[0]
            
            if (index == nil){
                continue;
            }
            if (isGetFilteredBands == true){
                while (isGetFilteredBands == true){
                    print ("Encountred a conflict...need to sleep")
                    sleep(1);
                }
            }
            var scheduleIndex = timeIndexMap[index]
            
            counter = counter + 1
            
            print ("Checking next bandName \(eventSelectedIndex) == \(scheduleIndex) && \(bandNamefromIndex) == \(bandName)")
            if ((eventSelectedIndex == scheduleIndex || timeIndex == "0") && bandNamefromIndex == bandName){
                print ("Checking next bandName size \(sizeBands) == \(counter)")
                if (direction == "Previous"){
                    counter = counter - 2;
                    if (counter > -1){
                        var nextIndex = getBandFromIndex(index: loopThroughBandList[counter])
                        eventSelectedIndex = timeIndexMap[nextIndex] ?? ""
                        var bandNamefromIndex =  nextIndex.components(separatedBy: ":")
                        bandNameNext = bandNamefromIndex[1]
                        print ("Checking next bandName Previous \(nextIndex) - \(eventSelectedIndex) - \(bandNamefromIndex) - \(bandNameNext)")
                    }
                } else {
                    if (counter < sizeBands){
                        var nextIndex = getBandFromIndex(index: loopThroughBandList[counter])
                        eventSelectedIndex = timeIndexMap[nextIndex] ?? ""
                        var bandNamefromIndex =  nextIndex.components(separatedBy: ":")
                        bandNameNext = bandNamefromIndex[1]
                        print ("Checking next bandName Next \(nextIndex) - \(eventSelectedIndex) - \(bandNamefromIndex) - \(bandNameNext)")
                    }
                }
            }
        }
        
        print ("Checking next bandName Found \(eventSelectedIndex) - \(bandNameNext)")
        jumpToNextOrPreviousScreen(nextBandName: bandNameNext, direction: direction)
    }
    
    func getBandFromIndex(index: String)->String{
        
        var bandInIndex = ""
        var indexSplit = index.components(separatedBy: ":")
        
        if (indexSplit.count == 1){
            bandInIndex = "0:" + index
        
        } else if (indexSplit[0].isNumeric == true){
            bandInIndex = indexSplit[0] + ":" + indexSplit[1]
            
        } else if (indexSplit[1].isNumeric == true){
            bandInIndex = "0:" + indexSplit[0]
            
        } else if (indexSplit[0].isDouble() == true){
            bandInIndex = indexSplit[0] + ":" + indexSplit[1]
            
        } else if (indexSplit[1].isDouble() == true){
            bandInIndex = "0:" + indexSplit[0]
            
        }
        
        return bandInIndex
    }
    
    func bandNameFromIndex(index :String) -> String{
        
        var bandName = index;
        var indexSplit = index.components(separatedBy: ":")
        if (indexSplit.count >= 2){
            var index1 = indexSplit[0]
            var index2 = indexSplit[1]
            
            if (index1.isNumeric == true){
                bandName = index2;
            } else {
               bandName = index1;
            }
        }
        
        return bandName;
    }
    
    @IBAction func ClickOnNotes(_ sender: Any) {
        //ToastMessages("Edit Notes").show(self, cellLocation: self.view.frame)
        textViewDidBeginEditing(customNotesText)
        //customNotesText.font = UIFont(name: customNotesText.font!.fontName, size: 25)

    }
    @IBAction func setBandPriority() {
        if (bandName != nil){
            
            bandPriorityStorage[bandName!] = priorityButtons.selectedSegmentIndex
            
            print ("Setting band priority  from Details to \(bandPriorityStorage[bandName!])")
            dataHandle.addPriorityData(bandName, priority: priorityButtons.selectedSegmentIndex)
        
            let priorityImageName = getPriorityGraphic(priorityButtons.selectedSegmentIndex)
            // Avoid CUICatalog errors by checking for empty string before UIImage(named:)
            if priorityImageName.isEmpty {
                PriorityIcon.image = UIImage()
            } else {
                PriorityIcon.image = UIImage(named: priorityImageName) ?? UIImage()
            }
            
            setButtonNames()
            NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
            NotificationCenter.default.post(name: Notification.Name("DetailDidUpdate"), object: nil)
            if UIDevice.current.userInterfaceIdiom == .pad {
                masterView?.refreshDataWithBackgroundUpdate(reason: "Detail view priority update")
            }
        }
    }
    
    func jumpToNextOrPreviousScreen(nextBandName :String, direction :String){
        
        var message = ""
        var animationMovement = CGFloat.init();
        
        var translatedDirection = NSLocalizedString(direction, comment: "");
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            animationMovement = 0;
        } else {
            if (direction == "Next"){
                animationMovement = -600;
            } else {
                animationMovement = 600;
            }
        }
        
        print ("jumpToNextOrPreviousScreen -  bandName \(nextBandName)")
        
        if (nextBandName.isEmpty == true){
            if (direction == "Next"){
                message = NSLocalizedString("EndofList", comment: "");
            } else {
                message = NSLocalizedString("AlreadyAtStart", comment: "");
            }
            ToastMessages(message).show(self, cellLocation: self.view.frame, placeHigh: false )
        } else {
            message = translatedDirection + "-" + nextBandName
        
        
            bandSelected = nextBandName
            bandName = nextBandName
            
            ToastMessages(message).show(self, cellLocation: self.view.frame, placeHigh: false )
            print ("Starting animtion")
            
            UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseOut, animations: {
    

                var frameNotes = self.customNotesText.frame
                frameNotes.origin.x += animationMovement
                self.customNotesText.frame = frameNotes

                var frameLogo = self.bandLogo.frame
                frameLogo.origin.x += animationMovement
                self.bandLogo.frame = frameLogo

                var frameLinks = self.LinksSection.frame
                frameLinks.origin.x += animationMovement
                self.LinksSection.frame = frameLinks
                
                var frameEvents1 = self.EventView1.frame
                frameEvents1.origin.x += animationMovement
                self.EventView1.frame = frameEvents1
                
                var frameEvents2 = self.EventView2.frame
                frameEvents2.origin.x += animationMovement
                self.EventView2.frame = frameEvents2
                
                var frameEvents3 = self.EventView3.frame
                frameEvents3.origin.x += animationMovement
                self.EventView3.frame = frameEvents3
                
                var frameEvents4 = self.EventView4.frame
                frameEvents4.origin.x += animationMovement
                self.EventView4.frame = frameEvents4
                
                var frameEvents5 = self.EventView5.frame
                frameEvents5.origin.x += animationMovement
                self.EventView5.frame = frameEvents5
                
                var frameExtras = self.extraData.frame
                frameExtras.origin.x += animationMovement
                self.extraData.frame = frameExtras

                var framePriorityIcon = self.PriorityIcon.frame
                framePriorityIcon.origin.x += animationMovement
                self.PriorityIcon.frame = framePriorityIcon
                
                var framePriorityButtons = self.priorityButtons.frame
                framePriorityButtons.origin.x += animationMovement
                self.priorityButtons.frame = framePriorityButtons

                var framePriorityView = self.priorityButtons.frame
                framePriorityView.origin.x += animationMovement
                self.priorityButtons.frame = framePriorityView
                
            }, completion: { finished in })
            
            print ("Ending animtion")
            detailItem = bandName as AnyObject
            
            self.viewDidLoad()
            setButtonNames()
            self.viewWillAppear(true)
            
        }
    }
 
    
    @IBAction func openLink(_ sender: UIButton) {
        
        
        var sendToUrl = String()

        if (bandName != nil){
            if (sender.accessibilityIdentifier == officalSiteButtonName){
               webMessageHelp = NSLocalizedString("officialWebSiteLinkHelp", comment: "officialWebSiteLinkHelp")
               sendToUrl = bandNameHandle.getofficalPage(bandName)
            
            } else if (sender.accessibilityIdentifier == wikipediaButtonName){
                webMessageHelp = NSLocalizedString("WikipediaLinkHelp", comment: "WikipediaLinkHelp")
                sendToUrl = bandNameHandle.getWikipediaPage(bandName)
            
            } else if (sender.accessibilityIdentifier == youTubeButtonName){
                webMessageHelp = NSLocalizedString("YouTubeLinkHelp", comment: "YouTubeLinkHelp")
                sendToUrl = bandNameHandle.getYouTubePage(bandName)
                
            } else if (sender.accessibilityIdentifier == metalArchivesButtonName){
                webMessageHelp = NSLocalizedString("MetalArchiveLinkHelp", comment: "MetalArchiveLinkHelp")
                sendToUrl = bandNameHandle.getMetalArchives(bandName)
                
            }
            
            if (sender.isEnabled == true && sendToUrl.isEmpty == false){
                setUrl(sendToUrl)
            }
        }
    }
    
    /// Configures the view with the current detail item and updates the UI accordingly.
    func configureView() {
        // Update the user interface for the detail item.
        if let detail: AnyObject = self.detailItem {
            // Restore previous logic from setDetailItem
            bandName = self.detailItem?.description
            if let label = self.titleLable {
                print ("determining detail bandName \(detail) - \(label) - \(String(describing: detail.description))")
                bandName = detail.description
                label.title = bandName
            }
        }
        // Additional UI updates can be added here if needed.
    }
    
    func showFullSchedule () {
               
        resetScheduleGUI()
        schedule.getCachedData()
        scheduleQueue.sync {
            if (schedule.schedulingData[bandName]?.isEmpty == false){
                
                let keyValues = schedule.schedulingData[bandName]!.keys
                let sortedArray = keyValues.sorted();
                var count = 1
                eventCount = keyValues.count;

                schedule.buildTimeSortedSchedulingData();
                
                for index in sortedArray {
                    
                    let location = schedule.getData(bandName, index:index, variable: locationField)
                    let day = monthDateRegionalFormatting(dateValue: schedule.getData(bandName, index: index, variable: dayField))
                    var startTime = schedule.getData(bandName, index: index, variable: startTimeField)
                    var endTime = schedule.getData(bandName, index: index, variable: endTimeField)
                    let date = schedule.getData(bandName, index:index, variable: dateField)
                    let type = schedule.getData(bandName, index:index, variable: typeField)
                    let notes = schedule.getData(bandName, index:index, variable: notesField)
                    let scheduleDescriptionUrl = schedule.getData(bandName, index:index, variable: descriptionUrlField)
                    
                    if (scheduleDescriptionUrl.isEmpty == false && scheduleDescriptionUrl.count > 3){
                        print ("Loading customNotesTest from URL")
                        DispatchQueue.global(qos: DispatchQoS.QoSClass.default).async {
                            self.backgroundNotesText = self.bandNotes.getDescriptionFromUrl(bandName: self.bandName, descriptionUrl: scheduleDescriptionUrl)
                            
                            DispatchQueue.main.async {
                                self.customNotesText.text = self.backgroundNotesText;
                            }
                        }
                        
                        
                    }
                    
                    let rawStartTime = startTime
                    
                    startTime = formatTimeValue(timeValue: startTime)
                    endTime = formatTimeValue(timeValue: endTime)
                    
                    var scheduleText = String()
                    if (!date.isEmpty){
                        
                        let status = attendedHandle.getShowAttendedStatus(band: bandName, location: location, startTime: rawStartTime, eventType: type, eventYearString: String(eventYear));
                        
                        print ("Show Attended Load \(status) - \(location) - \(startTime) - \(type)")
                        switch count {
                        case 1:
                            populateScheduleData(eventSlot: "event1", eventView: EventView1, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type, notes: notes, timeIndex: index)
                        case 2:
                            populateScheduleData(eventSlot: "event2", eventView: EventView2, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type, notes: notes, timeIndex: index)
                            
                        case 3:
                            populateScheduleData(eventSlot: "event3", eventView: EventView3, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type,notes: notes, timeIndex: index)
                            
                        case 4:
                           populateScheduleData(eventSlot: "event4",eventView: EventView4, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type,notes: notes, timeIndex: index)
                            
                        case 5:
                            populateScheduleData(eventSlot: "event5",eventView: EventView5, location: location, day: day, startTime: rawStartTime, endTime: endTime, date: date, eventType: type,notes: notes, timeIndex: index)
                        default:
                            print("To many events")
                        }
                       
                        count += 1
                        
                    }
                }
            }
            hideEmptyData();
        }
    }
    
    func populateScheduleData(eventSlot: String, eventView: UIView, location: String, day:String, startTime: String,
                              endTime: String, date: String, eventType: String, notes: String,timeIndex: TimeInterval){
        
        scheduleIndex[eventSlot] = [String:String]();
        scheduleIndex[eventSlot]!["location"] = location
        scheduleIndex[eventSlot]!["eventType"] = eventType
        scheduleIndex[eventSlot]!["startTime"] = startTime
        
        let attendedView = eventView.viewWithTag(4) as! UIImageView
        print ("Icon parms \(bandName) \(location) \(startTime) \(eventType)")
        let icon = attendedHandle.getShowAttendedIcon(band: bandName,location: location,startTime: startTime,eventType: eventType,eventYearString: String(eventYear));
        attendedView.image = icon

        var locationColor = eventView.viewWithTag(1)
        locationColor?.backgroundColor = getVenueColor(venue: location);
        
        var locationView = eventView.viewWithTag(2) as! UILabel
        var locationText = location
        if (venueLocation[location] != nil){
            locationText += " " + venueLocation[location]!
        }
        locationView.textColor = UIColor.white
        locationView.text = locationText

        let eventTypeText = eventView.viewWithTag(3)  as! UILabel
        eventTypeText.textColor = UIColor.lightGray
        if (eventType == showType){
            eventTypeText.text = " "
        } else {
            eventTypeText.text = convertEventTypeToLocalLanguage(eventType: eventType)
        }
    
            
        let eventTypeImageView = eventView.viewWithTag(5) as! UIImageView
        let eventIcon = getEventTypeIcon(eventType: eventType, eventName: bandName)
        eventTypeImageView.image = eventIcon
        
        let startTimeView = eventView.viewWithTag(6) as! UILabel
        let startTime = schedule.getData(bandName, index: timeIndex, variable: startTimeField)
        let startTimeText = formatTimeValue(timeValue: startTime)
        startTimeView.textColor = UIColor.white
        startTimeView.text = startTimeText
        
        let endTimeView = eventView.viewWithTag(7) as! UILabel
        let endTime = schedule.getData(bandName, index: timeIndex, variable: endTimeField)
        let endTimeText = formatTimeValue(timeValue: endTime)
        endTimeView.textColor = hexStringToUIColor(hex: "#797D7F")
        endTimeView.text = endTimeText
        
        let dayLabelView = eventView.viewWithTag(8) as! UILabel
        dayLabelView.text = NSLocalizedString("Day", comment: "")
        
        let dayView = eventView.viewWithTag(9) as! UILabel
        dayView.textColor = UIColor.white
        var dayText = ""
        if day == "Day 1"{
            dayText = "1";
        
        } else if day == "Day 2"{
            dayText = "2";
            
        } else if day == "Day 3"{
            dayText = "3";
            
        } else if day == "Day 4"{
            dayText = "4";
            
        } else {
            dayText = day
        }
        
        dayView.text = dayText

 
        let notesView = eventView.viewWithTag(10) as! UILabel
        notesView.textColor = UIColor.lightGray
        notesView.text = notes
        
        eventView.frame = CGRect(x: 14 , y: 94, width: 386, height: 40)
        locationColor!.frame = CGRect(x: 0 , y: 0, width: 4, height: 40)
        locationView.frame = CGRect(x: 5 , y: 0, width: 236, height: 20)
        eventTypeText.frame = CGRect(x: 5 , y: 20, width: 233, height: 10)
        notesView.frame = CGRect(x: 5 , y: 30, width: 233, height: 10)
        attendedView.frame = CGRect(x: 241 , y: 0, width: 20, height: 20)
        eventTypeImageView.frame = CGRect(x: 241 , y: 20, width: 20, height: 20)
        startTimeView.frame = CGRect(x: 261 , y: 0, width: 93, height: 20)
        endTimeView.frame = CGRect(x: 251 , y: 20, width: 93, height: 20)
        dayLabelView.frame = CGRect(x: 361 , y: 0, width: 25, height: 20)
        dayView.frame = CGRect(x: 361 , y: 20, width: 25, height: 20)
    }
    
    func hideEmptyData() {
        
        var genericUIText:UILabel = UILabel()
        genericUIText.text = "placeHolder"
        
        var eventTypeText1:UILabel = UILabel()
        var eventTypeText2:UILabel  = UILabel()
        var eventTypeText3:UILabel  = UILabel()
        var eventTypeText4:UILabel  = UILabel()
        var eventTypeText5:UILabel  = UILabel()
        var reloadData = false
        
        eventTypeText1 = EventView1.viewWithTag(3) as! UILabel
        eventTypeText2 = EventView2.viewWithTag(3) as! UILabel
        eventTypeText3 = EventView3.viewWithTag(3) as! UILabel
        eventTypeText4 = EventView4.viewWithTag(3) as! UILabel
        eventTypeText5 = EventView5.viewWithTag(3) as! UILabel
        
        if (eventTypeText1.text?.isEmpty)!{
            hideEvent(eventView: EventView1, eventIndex: "event1")
            eventView1Hidden = true
        }
        if (eventTypeText2.text?.isEmpty)!{
            hideEvent(eventView: EventView2, eventIndex: "event2")
            eventView2Hidden = true
        }
        if (eventTypeText3.text?.isEmpty)!{
            hideEvent(eventView: EventView3, eventIndex: "event3")
            eventView3Hidden = true
        }
        if (eventTypeText4.text?.isEmpty)!{
            hideEvent(eventView: EventView4, eventIndex: "event4")
            eventView4Hidden = true
        }
        if (eventTypeText5.text?.isEmpty)!{
            hideEvent(eventView: EventView5, eventIndex: "event5")
            eventView5Hidden = true
        }
    }
    
    func restoreEvents(eventView: UIView, eventIndex: String){
        
        eventView.isHidden = false
        
    }
    
    func hideEvent(eventView: UIView, eventIndex: String){

        eventView.isHidden = true
        linkViewTopSpacingConstraint.constant = linkViewTopSpacingConstraint.constant - 40
        dataViewTopSpacingConstraint.constant = dataViewTopSpacingConstraint.constant - 40
        notesViewTopSpacingConstraint.constant = notesViewTopSpacingConstraint.constant - 40
    }
    
    /// Handles memory warnings by releasing any resources that can be recreated.
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func disableButtonsIfNeeded(){
        
        var offline = true
        
        if Reachability.isConnectedToNetwork(){
            offline = false;
        }
        
        print ("Checking button status " + bandName)
        if (offline == true || bandName == nil){
            
            
            print ("Offline is active")
            officialUrlButton.isUserInteractionEnabled = false
            officialUrlButton.tintColor = UIColor.gray
            
            wikipediaUrlButton.isUserInteractionEnabled = false
            wikipediaUrlButton.tintColor = UIColor.gray
            
            youtubeUrlButton.isUserInteractionEnabled = false
            youtubeUrlButton.tintColor = UIColor.gray
            
            metalArchivesButton.isUserInteractionEnabled = false
            metalArchivesButton.tintColor = UIColor.gray

        }

    }
    
    @IBAction func noteButtonClick(_ sender: Any) {
        print ("Clicked the notes button")
        let screenSize = UIScreen.main.bounds
        customNotesText.frame.size.height = screenSize.height
    }
    
    @objc func clickedOnEvent(sender: UITapGestureRecognizer) {
        
        var eventString = ""
        if (sender.view?.tag == 51){
            eventString = "event1";
        
        } else if (sender.view?.tag == 52){
            eventString = "event2";
        
        } else if (sender.view?.tag == 53){
            eventString = "event3";

        } else if (sender.view?.tag == 54){
            eventString = "event4";

        } else if (sender.view?.tag == 55){
            eventString = "event5";
        }

        let location = scheduleIndex[eventString]!["location"]
        let startTime = scheduleIndex[eventString]!["startTime"]
        let eventType = scheduleIndex[eventString]!["eventType"]
        
        let status = attendedHandle.addShowsAttended(band: bandName, location: location!, startTime: startTime!, eventType: eventType!,eventYearString: String(eventYear));
        
        let empty : UITextField = UITextField();
        let message = attendedHandle.setShowsAttendedStatus(empty,status: status);
        
        ToastMessages(message).show(self, cellLocation: self.view.frame, placeHigh: true)
        NotificationCenter.default.post(name: Notification.Name(rawValue: "RefreshDisplay"), object: nil)
        NotificationCenter.default.post(name: Notification.Name("DetailDidUpdate"), object: nil)
        showFullSchedule ()
    }
    
    /// Checks if internet is available using the global NetworkStatusManager
    func isInternetAvailable() -> Bool {
        return NetworkStatusManager.shared.isInternetAvailable
    }
    
    func showToast(message : String) {
        
        let toastLabel = UILabel(frame: CGRect(x: 10, y: self.view.frame.size.height-250, width: self.view.frame.size.width - 10, height: 45))
        
        toastLabel.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        toastLabel.textColor = UIColor.white
        toastLabel.textAlignment = .center;
        toastLabel.font = UIFont(name: "Montserrat-Light", size: 12.0)
        toastLabel.text = message
        toastLabel.alpha = 1.0
        toastLabel.layer.cornerRadius = 10;
        toastLabel.clipsToBounds  =  true
        self.view.addSubview(toastLabel)
        UIView.animate(withDuration: 4.0, delay: 0.1, options: .curveEaseOut, animations: {
            toastLabel.alpha = 0.0
        }, completion: {(isCompleted) in
            toastLabel.removeFromSuperview()
        })
    }
    
    /// Adds text editing buttons and dismiss button to the keyboard toolbar
    func addDoneButtonToKeyboard() {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.barStyle = .black
        toolbar.tintColor = .white
        
        // Create buttons for text editing
        let selectAllButton = UIBarButtonItem(
            title: NSLocalizedString("Select All", comment: "Select all text button"),
            style: .plain,
            target: self,
            action: #selector(selectAllText)
        )
        
        let copyButton = UIBarButtonItem(
            title: NSLocalizedString("Copy", comment: "Copy text button"),
            style: .plain,
            target: self,
            action: #selector(copyText)
        )
        
        let pasteButton = UIBarButtonItem(
            title: NSLocalizedString("Paste", comment: "Paste text button"),
            style: .plain,
            target: self,
            action: #selector(pasteText)
        )
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        let fixedSpace = UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil)
        fixedSpace.width = 10
        
        // Use existing "Close" key from localization
        let dismissButton = UIBarButtonItem(
            title: NSLocalizedString("Close", comment: "Close keyboard button"),
            style: .plain,
            target: self,
            action: #selector(dismissKeyboard)
        )
        
        // Arrange buttons: [Select All] [Copy] [Paste] [flexible space] [Dismiss]
        toolbar.items = [selectAllButton, fixedSpace, copyButton, fixedSpace, pasteButton, flexSpace, dismissButton]
        customNotesText.inputAccessoryView = toolbar
    }
    
    /// Selects all text in the notes text view
    @objc func selectAllText() {
        customNotesText.selectAll(nil)
    }
    
    /// Copies selected text to clipboard
    @objc func copyText() {
        if let selectedText = customNotesText.text {
            let selectedRange = customNotesText.selectedRange
            if selectedRange.length > 0 {
                // Copy selected text
                let startIndex = selectedText.index(selectedText.startIndex, offsetBy: selectedRange.location)
                let endIndex = selectedText.index(startIndex, offsetBy: selectedRange.length)
                let textToCopy = String(selectedText[startIndex..<endIndex])
                UIPasteboard.general.string = textToCopy
                showToast(message: "📋 Text copied")
            } else {
                // If no selection, copy all text
                UIPasteboard.general.string = selectedText
                showToast(message: "📋 All text copied")
            }
        }
    }
    
    /// Pastes text from clipboard at current cursor position
    @objc func pasteText() {
        if let clipboardText = UIPasteboard.general.string {
            customNotesText.paste(nil)
            showToast(message: "📋 Text pasted")
        } else {
            showToast(message: "📋 Nothing to paste")
        }
    }
    
    /// Dismisses the keyboard when Dismiss button is tapped
    @objc func dismissKeyboard() {
        customNotesText.resignFirstResponder()
    }

}


extension UITextField {
    func halfTextColorChange (fullText : String , changeText : String, locationColor: UIColor ) {
        let strNumber: NSString = fullText as NSString
        let range = (strNumber).range(of: changeText)
        let attribute = NSMutableAttributedString.init(string: fullText)
        attribute.addAttribute(NSAttributedString.Key.foregroundColor, value: locationColor , range: range)
        self.attributedText = attribute
    }
}


extension UIImage {
    
    func resize(maxWidthHeight : Double)-> UIImage? {
        
        let actualHeight = Double(size.height)
        let actualWidth = Double(size.width)
        var maxWidth = 0.0
        var maxHeight = 0.0
        
        if actualWidth > actualHeight {
            maxWidth = maxWidthHeight
            let per = (100.0 * maxWidthHeight / actualWidth)
            maxHeight = (actualHeight * per) / 100.0
        }else{
            maxHeight = maxWidthHeight
            let per = (100.0 * maxWidthHeight / actualHeight)
            maxWidth = (actualWidth * per) / 100.0
        }
        
        let hasAlpha = true
        let scale: CGFloat = 0.0
        
        UIGraphicsBeginImageContextWithOptions(CGSize(width: maxWidth, height: maxHeight), !hasAlpha, scale)
        self.draw(in: CGRect(origin: .zero, size: CGSize(width: maxWidth, height: maxHeight)))
        
        let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
        return scaledImage
    }
    
}

extension String {
    var isNumeric: Bool {
        return !isEmpty && rangeOfCharacter(from: CharacterSet.decimalDigits.inverted) == nil
    }
    func isDouble() -> Bool {

        if let doubleValue = Double(self) {
            return true
        }

        return false
    }
    func isFloat() -> Bool {

        if let floatValue = Float(self) {
            return true
        }

        return false
    }
}
