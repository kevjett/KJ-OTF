//! View during workout

using Toybox.WatchUi as Ui;
using Toybox.Graphics as Gfx;
using Toybox.Application;
using Toybox.Lang;
using Toybox.System;
using Toybox.Timer;

class OTFWorkoutView extends Ui.View {

    hidden var mModel;
    hidden var mController;
    hidden var mTimer;

    //! UI Variables
    hidden var uiStatusTime;
    hidden var uiTimer;
    hidden var uiHRbpmText;
    hidden var uiCaloriesText;
    hidden var uiSplatText;
    hidden var uiDetail1Label;
    hidden var uiDetail1Value;
    hidden var uiDetail2Label;
    hidden var uiDetail2Value;
    hidden var uiDetail3Label;
    hidden var uiDetail3Value;
    hidden var uiDetail4Label;
    hidden var uiDetail4Value;
    hidden var uiDetail5Label;
    hidden var uiDetail5Value;

    hidden var uiHRpctText;
    hidden var uiHRZoneBackground;
    hidden var uiHRZoneBars;
    hidden var uiHRZoneColor;
    hidden var uiHRZoneColorText;
    hidden var uiGPSStatus;

    hidden var prevZone;
    hidden var vibeTime;


    function initialize() {
        View.initialize();
        // Start timer used to push UI updates
        mTimer = new Timer.Timer();
        // Get the model and controller from the Application
        mModel = Application.getApp().model;
        mController = Application.getApp().controller;

        uiStatusTime = null;
        uiTimer = null;
        uiHRbpmText = null;
        uiCaloriesText = null;
        uiDetail1Value = null;
        uiDetail2Value = null;
        uiDetail3Value = null;
        uiDetail4Value = null;
        uiDetail5Value = null;
        uiDetail1Label = null;
        uiDetail2Label = null;
        uiDetail3Label = null;
        uiDetail4Label = null;
        uiDetail5Label = null;
        uiSplatText = null;
        uiHRpctText = null;
        uiGPSStatus = null;

        uiHRZoneBackground = null;
        uiHRZoneBars = null;
        uiHRZoneColor = [ Gfx.COLOR_LT_GRAY, Gfx.COLOR_LT_GRAY, Gfx.COLOR_BLUE, Gfx.COLOR_GREEN, Gfx.COLOR_ORANGE, Gfx. COLOR_DK_RED ];
        uiHRZoneColorText = [ Gfx.COLOR_WHITE, Gfx.COLOR_WHITE, Gfx.COLOR_WHITE, Gfx.COLOR_BLACK, Gfx.COLOR_WHITE, Gfx. COLOR_WHITE ];

        prevZone = 0;
        vibeTime = 0;
    }

    //! Load your resources here
    function onLayout(dc) {
        // Load the layout from the resource file
        setLayout(Rez.Layouts.PrimaryWorkoutScreen(dc));

        // Load UI resources
        uiStatusTime = View.findDrawableById("StatusTime");
        uiHRbpmText = View.findDrawableById("WorkoutHRbpmText");
        uiTimer = View.findDrawableById("WorkoutTimer");
        uiCaloriesText = View.findDrawableById("WorkoutCaloriesText");
        
        uiDetail1Label = View.findDrawableById("WorkoutDetail1Label");
        uiDetail1Value = View.findDrawableById("WorkoutDetail1Value");
        
        uiDetail2Label = View.findDrawableById("WorkoutDetail2Label");
        uiDetail2Value = View.findDrawableById("WorkoutDetail2Value");
        
        uiDetail3Label = View.findDrawableById("WorkoutDetail3Label");
        uiDetail3Value = View.findDrawableById("WorkoutDetail3Value");
        
        uiDetail4Label = View.findDrawableById("WorkoutDetail4Label");
        uiDetail4Value = View.findDrawableById("WorkoutDetail4Value");
        
        uiDetail5Label = View.findDrawableById("WorkoutDetail5Label");
        uiDetail5Value = View.findDrawableById("WorkoutDetail5Value");
        
        uiSplatText = View.findDrawableById("WorkoutSplatText");
        uiHRpctText = View.findDrawableById("WorkoutHRpctText");
        uiGPSStatus = View.findDrawableById("GPSStatus");

        uiHRZoneBackground = View.findDrawableById("WorkoutZoneBg");
        uiHRZoneBars = View.findDrawableById("WorkoutZoneBars");
    }

    //! Called when this View is brought to the foreground. Restore
    //! the state of this View and prepare it to be shown. This includes
    //! loading resources into memory.
    function onShow() {
        mTimer.start(method(:onTimer), 1000, true);
        // If we come back to this view via back button, resume
        if (!mController.isRunning()) {
            mController.onStartStop();
        }
    }

    //! Called when this View is removed from the screen. Save the
    //! state of this View here. This includes freeing resources from
    //! memory.
    function onHide() {
        mTimer.stop();
    }

    //! Update the view
    function onUpdate(dc) {
    	var clock = System.getClockTime();
        var ampm = clock.hour >= 12 ? "PM" : "AM";
        var clockString = Lang.format("$1$:$2$ $3$", [(clock.hour%12).format("%02d"),clock.min.format("%02d"),ampm]);
        
        uiStatusTime.setText( clockString );
        
        
        var curZone = mModel.getHRzone();
        var time = mModel.getTimeElapsed();
        var timeString = Lang.format("$1$:$2$", [time / 60, (time % 60).format("%02d")]);

        if( curZone != null ) {
            uiHRZoneBackground.color = uiHRZoneColor[ curZone ];
            uiHRZoneBars.zone = curZone;
            
            uiStatusTime.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail1Label.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail1Value.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail2Label.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail2Value.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail3Label.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail3Value.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail4Label.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail4Value.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail5Label.setColor(uiHRZoneColorText[ curZone ]);
            uiDetail5Value.setColor(uiHRZoneColorText[ curZone ]);

            // Prevent back to back vibration events
            if(( time - vibeTime) > 10) {
                zoneCheck(curZone);
            }
        }
        
        
        var activity = Activity.getActivityInfo();

        uiTimer.setText( timeString );
        uiHRpctText.setText(Lang.format("$1$", [mModel.getHRpct()]));
        uiHRbpmText.setText(Lang.format("$1$", [mModel.getHRbpm()]));
        uiSplatText.setText(Lang.format("$1$", [mModel.getSplats()]));
        uiCaloriesText.setText(Lang.format("$1$", [mModel.getCalories()]));
        
        
        uiDetail1Label.setText("Pace");
        uiDetail1Value.setText(Lang.format("$1$", [mModel.getPace(activity)]));
        uiDetail2Label.setText("Dist");
        uiDetail2Value.setText(Lang.format("$1$", [mModel.getDistance(activity)]));
        uiDetail3Label.setText("Speed");
        uiDetail3Value.setText(Lang.format("$1$", [mModel.getSpeed(activity)]));
        uiDetail4Label.setText("Avg");
        uiDetail4Value.setText(Lang.format("$1$", [mModel.getAvgPace(activity)]));
        uiDetail5Label.setText("");
        uiDetail5Value.setText("");

        // Call the parent onUpdate function to redraw the layout
        View.onUpdate(dc);
        
        if (mModel.isGpsEnabled()) {
        	mController.drawGps(dc, activity.currentLocationAccuracy, uiGPSStatus.locX, uiGPSStatus.locY);
        }
    }

    //! Handler for the timer callback
    function onTimer() {
        Ui.requestUpdate();
    }

    function zoneCheck(zone) {
        // Transitioned into orange
        if ( prevZone <= 3 && zone == 4 ) {
            mController.vibrate(2);
            vibeTime = mModel.getTimeElapsed();
        // Transitioned into red
        } else if ( prevZone <= 4 && zone == 5 ) {
            mController.vibrate(3);
            vibeTime = mModel.getTimeElapsed();
        // Transitioned below green
        } else if ( prevZone >= 3 && zone <= 2 ) {
            mController.vibrate(1);
            vibeTime = mModel.getTimeElapsed();
        }
        prevZone = zone;
    }

}