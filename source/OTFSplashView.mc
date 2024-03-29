//! Default starting view

using Toybox.WatchUi as Ui;
using Toybox.Application;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;

class OTFSplashView extends Ui.View {

    hidden var mModel;
    hidden var mController;
    hidden var mTimer;

    //! UI Variables
    hidden var uiStatusTime;
    hidden var uiStatusHRText;
    hidden var uiStatusHRIconWhite;
    hidden var uiStatusHRIconRed;
    hidden var uiGPS;
    hidden var uiGPSStatus;
    hidden var xOffsetHR;
    hidden var xOffsetGPS;
    hidden var mBlinkOn = true;

    function initialize() {
        View.initialize();
        // Start timer used to push UI updates
        mTimer = new Timer.Timer();
        // Get the model and controller from the Application
        mModel = Application.getApp().model;
        mController = Application.getApp().controller;

        // Get values from resources
        uiStatusTime = null;
        uiStatusHRIconWhite = null;
        uiStatusHRIconRed = null;
        uiStatusHRText = null;
        uiGPS = null;
        uiGPSStatus = null;
        xOffsetHR = null;
        xOffsetGPS = null;
    }

    //! Load your resources here
    function onLayout(dc) {
        // Load the layout from the resource file
        setLayout(Rez.Layouts.SplashScreen(dc));

        uiStatusTime = View.findDrawableById("StatusTime");
        uiStatusHRText = View.findDrawableById("StatusHRText");
        uiStatusHRIconWhite = View.findDrawableById("StatusHRIconWhite");
        uiStatusHRIconRed = View.findDrawableById("StatusHRIconRed");
        uiGPS = View.findDrawableById("GPS");
        uiGPSStatus = View.findDrawableById("GPSStatus");

        xOffsetHR = uiStatusHRIconWhite.locX;
        xOffsetGPS = uiGPS.locX;
    }

    //! Called when this View is brought to the foreground. Restore
    //! the state of this View and prepare it to be shown. This includes
    //! loading resources into memory.
    function onShow() {
        // Load preferencese
        mController.loadPreferences();
        
        if ( mController.confirmed == true ) {
            mController.startWorkout();
        }
        
        // Refresh timer      
        mTimer.start(method(:onTimer), 1000, true);
    }

    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
    function onHide() {
        mTimer.stop();
    }

    //! Update the view
    function onUpdate(dc) {
        // Draw the splash screen
        drawSplash();

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        
        if (mModel.isGpsEnabled() && mModel.checkGps()) {
        	mController.drawGps(dc, mModel.getGpsAccuracy(), uiGPSStatus.locX, uiGPSStatus.locY);
        }
    }

    //! Handler for the timer callback
    function onTimer() {
        Ui.requestUpdate();
    }

    hidden function drawSplash() {
        var time = System.getClockTime();
        var ampm = time.hour >= 12 ? "PM" : "AM";
        var timeString = Lang.format("$1$:$2$ $3$", [(time.hour%12).format("%02d"),time.min.format("%02d"),ampm]);
        var heartrate = mModel.getHRbpm();
        
        mBlinkOn = !mBlinkOn;

        uiStatusTime.setText( timeString );

        // Change the Heart Rate icon and text based on sensor data
        // Flashing White is no HR data
        // Steady Red is valid HR data
        if (heartrate == 0 || heartrate == null) {
            uiStatusHRIconRed.locX = -50;
            uiStatusHRIconWhite.locX = mBlinkOn ? xOffsetHR : -50;
            uiStatusHRText.setText("");
        } else {
            heartrate = Lang.format("$1$", [heartrate]);
            uiStatusHRIconRed.locX = xOffsetHR;
            uiStatusHRIconWhite.locX = -50;
            uiStatusHRText.setText( heartrate );
        }
        
        if (mModel.isGpsEnabled()) {
	        if (!mModel.checkGps()) {
	        	uiGPS.locX = mBlinkOn ? xOffsetGPS : -50;
	        } else {
	        	uiGPS.locX = xOffsetGPS;
	        }
        } else {
	    	uiGPS.locX = -50;
        }

    }
    
    

}