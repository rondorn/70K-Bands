//
//  Settings70k.swift
//  70K Bands
//
//  Created by Ron Dorn on 10/2/23.
//  Copyright © 2023 Ron Dorn. All rights reserved.
//

import Foundation

var mustSeeOn = true;
var mightSeeOn = true;
var wontSeeOn = true;
var unknownSeeOn = true;
var hideExpireScheduleData = true;
var showTheaterShows = true
var showPoolShows = true
var showRinkShows = true
var showLoungeShows = true
var showOtherShows = true
var showUnofficalEvents = true
var showSpecialEvents = true
var showMeetAndGreetEvents = true
var showOnlyWillAttened = false;
var sortedBy = "time"

var mustSeeAlertValue = true
var mightSeeAlertValue = true
var onlyAlertForAttendedValue = false

var alertForShowsValue = true
var alertForSpecialValue = true
var alertForMandGValue = false
var alertForUnofficalEventsValue = true
var alertForClinicEvents = false
var alertForListeningEvents = false

var notesFontSizeLargeValue = false

var minBeforeAlertValue = 10

var promptForAttended = true

var artistUrlPointer = "Current"
var scheduleUrlPointer  = "Current"

func setArtistUrl(_ value: String){
    print ("setupCurrentYearUrls: setting setArtistUrl to \(value)")
    artistUrlPointer = value
}
func getArtistUrl() -> String{
    print ("setupCurrentYearUrls: loading ArtistUrl of \(artistUrlPointer)")
    return artistUrlPointer
}

func setScheduleUrl(_ value: String){

    scheduleUrlPointer = value
}
func getScheduleUrl() -> String{
    return scheduleUrlPointer
}

func setPromptForAttended(_ value: Bool){
    promptForAttended = value
}
func getPromptForAttended()->Bool{
    return promptForAttended
}

func setMinBeforeAlertValue(_ value: Int){
    minBeforeAlertValue = value
}
func getMinBeforeAlertValue()->Int{
    return minBeforeAlertValue
}

func setNotesFontSizeLargeValue(_ value: Bool){
    notesFontSizeLargeValue = value
}
func getNotesFontSizeLargeValue()->Bool{
    return notesFontSizeLargeValue
}

func setAlertForListeningEvents(_ value: Bool){
    alertForListeningEvents = value
}
func getAlertForListeningEvents()->Bool{
    return alertForListeningEvents
}

func setAlertForClinicEvents(_ value: Bool){
    alertForClinicEvents = value
}
func getAlertForClinicEvents()->Bool{
    return alertForClinicEvents
}

func setAlertForUnofficalEventsValue(_ value: Bool){
    alertForUnofficalEventsValue = value
}
func getAlertForUnofficalEventsValue()->Bool{
    return alertForUnofficalEventsValue
}

func setAlertForMandGValue(_ value: Bool){
    alertForMandGValue = value
}
func getAlertForMandGValue()->Bool{
    return alertForMandGValue
}

func setAlertForShowsValue(_ value: Bool){
    alertForShowsValue = value
}
func getAlertForShowsValue()->Bool{
    return alertForShowsValue
}

func setAlertForSpecialValue(_ value: Bool){
    alertForSpecialValue = value
}
func getAlertForSpecialValue()->Bool{
    return alertForSpecialValue
}

func setMustSeeAlertValue(_ value: Bool){
    mustSeeAlertValue = value
}
func getMustSeeAlertValue()->Bool{
    return mustSeeAlertValue
}

func setMightSeeAlertValue(_ value: Bool){
    mightSeeAlertValue = value
}
func getMightSeeAlertValue()->Bool{
    return mightSeeAlertValue
}

func setOnlyAlertForAttendedValue(_ value: Bool){
    onlyAlertForAttendedValue = value
}
func getOnlyAlertForAttendedValue()->Bool{
    return onlyAlertForAttendedValue
}

func setShowTheaterShows(_ value: Bool){
    showTheaterShows = value
}
func getShowTheaterShows() -> Bool{
    return showTheaterShows
}

func setShowPoolShows(_ value: Bool){
    showPoolShows = value
}
func getShowPoolShows() -> Bool{
    return showPoolShows
}

func setShowRinkShows(_ value: Bool){
    showRinkShows = value
}
func getShowRinkShows() -> Bool{
    return showRinkShows
}

func setShowLoungeShows(_ value: Bool){
    showLoungeShows = value
}
func getShowLoungeShows() -> Bool{
    return showLoungeShows
}

func setShowOtherShows(_ value: Bool){
    showOtherShows = value
}
func getShowOtherShows() -> Bool{
    return showOtherShows
}

func setShowUnofficalEvents(_ value: Bool){
    showUnofficalEvents = value
}
func getShowUnofficalEvents() -> Bool{
    return showUnofficalEvents
}

func setShowSpecialEvents(_ value: Bool){
    showSpecialEvents = value
}
func getShowSpecialEvents() -> Bool{
    return showSpecialEvents
}

func setShowMeetAndGreetEvents(_ value: Bool){
    showMeetAndGreetEvents = value
}
func getShowMeetAndGreetEvents() -> Bool{
    return showMeetAndGreetEvents
}

func setHideExpireScheduleData(_ value: Bool){
    hideExpireScheduleData = value
}
func getHideExpireScheduleData() -> Bool{
    return hideExpireScheduleData
}

func setHideScheduleButton(_ value: Bool){
    hideScheduleButton = value
}

func getHideScheduleButton() -> Bool{
    return hideScheduleButton
}

func setScheduleButton(_ value: Bool){
    hideScheduleButton = value
}
func getScheduleButton() -> Bool{
    return hideScheduleButton
}

func setMustSeeOn(_ value: Bool){
    mustSeeOn = value
}
func getMustSeeOn() -> Bool{
    return mustSeeOn
}
func setMightSeeOn(_ value: Bool){
    mightSeeOn = value
}

func getMightSeeOn() -> Bool{
    return mightSeeOn
}
func setWontSeeOn(_ value: Bool){
    wontSeeOn = value
}
func getWontSeeOn() -> Bool{
    return wontSeeOn
}

func setUnknownSeeOn(_ value: Bool){
    unknownSeeOn = value
}
func getUnknownSeeOn() -> Bool{
    return unknownSeeOn
}

func setShowOnlyWillAttened(_ value: Bool){
    showOnlyWillAttened = value
    print ("Setting showOnlyWillAttened to \(value)")
}
func getShowOnlyWillAttened() -> Bool{
    print ("Returning showOnlyWillAttened as \(showOnlyWillAttened)")
    return showOnlyWillAttened
}

func setSortedBy(_ value: String){
    sortedBy = value
}
func getSortedBy() -> String{
    return sortedBy
}
