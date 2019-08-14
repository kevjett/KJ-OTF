//! OTFApp Model which handles the data processing of the activity

using Toybox.System;
using Toybox.Attention;
using Toybox.FitContributor as Fit;
using Toybox.Activity;
using Toybox.ActivityRecording as Recording;
using Toybox.UserProfile as Profile;
using Toybox.Time;
using Toybox.Timer;
using Toybox.Math;
using Toybox.WatchUi as Ui;
using Toybox.Position as Pos;

class OTFModel
{
	hidden const ZERO_TIME = "0:00";
    hidden const ZERO_SPEED = "0.0";
    hidden const ZERO_DISTANCE = "0.0";
    
    // Internal Timer and monitoring variables
    hidden var mTimer;
    hidden var mSeconds;
    hidden var mSession = null;
    hidden var mSplatsField = null;
    hidden var mStability;
    hidden var mStabilityTimer;
    hidden var mStabilityOn;
    hidden var mMaxHRFormula;

    // Primary stats used during intervals
    hidden var mHeartRate;
    hidden var mHeartRatePct;
    hidden var mHeartRateZone;
    hidden var mMaxHR;
    hidden var mZones;
    hidden var mZoneTimes;
    hidden var mSplats;
    hidden var mSecondsSplat;

    // Summarized and exposed statistics
    var elapsedTime;
    var calories;
    var averageHR;
    var averageHRPct;
    var peakHR;
    var peakHRPct;
    var splatPoints;
    var zoneTimes;

    //Time in Zones
    hidden var tz1 = 0;
    hidden var tz2 = 0;
    hidden var tz3 = 0;
    hidden var tz4 = 0;
    hidden var tz5 = 0;

    //HR Zone Percentage settings, based on Orange Theory, override user
    hidden var blueZone = 0.61;
    hidden var greenZone = 0.71;
    hidden var orangeZone = 0.84;
    hidden var redZone = 0.92;
    
    hidden var distanceUnits = System.UNIT_METRIC;
    hidden var kmOrMileInMeters = 1000;
    hidden var kmOrMileStr = "km";
    
    hidden var mIsGpsEnabled;

    // Initialize Activity
    function initialize() {
        // Sensor Heart Rate
        mHeartRate = 0;
        // Heart Rate as a Percentage
        mHeartRatePct = 0;
        // Current Heart Rate Zone
        mHeartRateZone = 0;
        // Max Heart Rate
        mMaxHR = 0;
        // Splat Points
        mSplats = 0;
        // Time elapsed
        mSeconds = 0;
        // Time HR is in Orange or Red range
        mSecondsSplat = 0;
        // HR Zones
        mZones = new [4];
        // HR Time in Each Zone
        mZoneTimes = new [5];
        // Stability is inactive
        mStabilityOn = false;
        mStabilityTimer = 0;
        // Max HR Formula
        mMaxHRFormula = 0;
        
        mIsGpsEnabled = false;
        
        distanceUnits = System.getDeviceSettings().distanceUnits;
        if (distanceUnits != System.UNIT_METRIC) {
            kmOrMileInMeters = 1610;
            kmOrMileStr = "mi";
        }

        // Define HR Zones
        setZones();
    }

    // Start session
    function start() {
        // Allocate the timer
        mTimer = new Timer.Timer();
        // Process the sensors at 10 Hz
        mTimer.start(method(:splatCallback), 1000, true);
        // Start the FIT recording
        if ( mSession != null ) {
            mSession.start();
        }
        
        checkActivityForGps();
    }

    // Stop sensor processing
    function stop() {
        // Stop the timer
        mTimer.stop();
        // Stop the FIT recording
        if ( mSession != null ) {
            mSession.stop();
        }
    }

    // Save the current session
    function save() {
        if ( mSession != null ) {
            mSession.save();
        }
    }

    // Discard the current session
    function discard() {
        if ( mSession != null ) {
            mSession.discard();
        }
    }

    // Return the splat points
    function getSplats() {
        return mSplats;
    }

    // Return the current calories burned
    function getCalories() {
        var activity = Activity.getActivityInfo();
        if (activity.calories != null){
            return activity.calories;
        } else {
            return 0;
        }
    }
    
    function isGpsActivityType() {
    	return Prefs.getActivityType() == 2;
    }
    
    //Return the current distance
    function getDistance(activity) {
    	if (!isGpsEnabled()) {
    		return "";
    	}
    		
        var distance = activity.elapsedDistance;
    	var distanceStr = ZERO_DISTANCE;
    	
    	if (distance != null && distance > 0) {
            var distanceKmOrMiles = distance / kmOrMileInMeters;
            distanceStr = distanceKmOrMiles.format("%.1f");
        }
        
        //return distanceStr + kmOrMileStr;
        return distanceStr;
    }
    
    //Return the current distance
    function getSpeed(activity) {
    	if (!isGpsEnabled()) {
    		return "";
    	}
    		
        var speedMetersPerSecond = activity.currentSpeed;
    	var speedStr = ZERO_SPEED;
    	
    	if (speedMetersPerSecond != null && speedMetersPerSecond > 0.2) {
            var kmOrMilesPerHourDecimal = (speedMetersPerSecond * 60.0 * 60.0) / kmOrMileInMeters;
            speedStr = kmOrMilesPerHourDecimal.format("%.1f");
        }
        
        //return speedStr + kmOrMileStr + "/hr";
        return speedStr;
    }
    
    //Return the current pace
    function getAvgPace(activity) {
    	if (!isGpsEnabled()) {
    		return "";
    	}
    		
        var speedMetersPerSecond = activity.averageSpeed;
        var paceStr = ZERO_TIME;       
        
        if (speedMetersPerSecond != null && speedMetersPerSecond > 0.2) {
            var minutesPerKmOrMilesDecimal = kmOrMileInMeters / (speedMetersPerSecond * 60.0);
            var seconds = (minutesPerKmOrMilesDecimal - minutesPerKmOrMilesDecimal.toNumber()) * 60;
            paceStr = minutesPerKmOrMilesDecimal.format("%d") + ":" + seconds.format("%02d");
        }
        
        //return paceStr + "/" + kmOrMileStr;
        return paceStr;
    }
    
    //Return the current pace
    function getPace(activity) {
    	if (!isGpsEnabled()) {
    		return "";
    	}
    		
        var speedMetersPerSecond = activity.currentSpeed;
        var paceStr = ZERO_TIME;       
        
        if (speedMetersPerSecond != null && speedMetersPerSecond > 0.2) {
            var minutesPerKmOrMilesDecimal = kmOrMileInMeters / (speedMetersPerSecond * 60.0);
            var seconds = (minutesPerKmOrMilesDecimal - minutesPerKmOrMilesDecimal.toNumber()) * 60;
            paceStr = minutesPerKmOrMilesDecimal.format("%d") + ":" + seconds.format("%02d");
        }
        
        //return paceStr + "/" + kmOrMileStr;
        return paceStr;
    }

    // Return the current heart rate in bpm
    function getHRbpm() {
        return mHeartRate;
    }

    // Return the current heart rate in bpm
    function getHRpct() {
        return mHeartRatePct;
    }

    // Return the current heart rate zone number
    function getHRzone() {
        return mHeartRateZone;
    }

    // Return the total elapsed recording time
    function getTimeElapsed() {
        return mSeconds;
    }

    // Handle controller sensor events
    function setSensor(sensor_info) {
        if( sensor_info has :heartRate ) {
            if( sensor_info.heartRate != null ) {
                mHeartRate = sensor_info.heartRate;
                mStabilityTimer = 0;
                mStabilityOn = false;
            } else {
                // if HR stability is off or the timer has expired
                if ( mStability == false || mStabilityTimer > 9 ) {
                    Log.debug("No HR Detected: Stability Off, Stability Timer Expired");
                    mHeartRate = 0;
                } else {
                    mStabilityOn = true;
                }
            }
        }
    }
    
    function checkActivityForGps() {
    //if activity requires GPS, turn on GPS
    	if (isGpsActivityType()) {
    		enableGps();
    	} else {
    		disableGps();
    	}
    }
    
    function enableGps() {
    	mIsGpsEnabled = true;
    	Position.enableLocationEvents(Position.LOCATION_CONTINUOUS, method(:onPosition));
    }
    
    function disableGps() {
    	mIsGpsEnabled = false;
    	Position.enableLocationEvents(Position.LOCATION_DISABLE, method(:onPosition));
    }
    
    //! Handle Position Events
    function onPosition(info) {
    	
    }
    
    function checkGps() {
    	var gpsAccuracy = getGpsAccuracy();
		var gpsIsOkay = ( gpsAccuracy == Pos.QUALITY_GOOD || gpsAccuracy == Pos.QUALITY_USABLE );
    	return gpsIsOkay;
    }
    
    function getGpsAccuracy() {
    	var gpsinfos = Pos.getInfo();
		return gpsinfos.accuracy;
    }
    
    function isGpsEnabled() {
    	return mIsGpsEnabled;
    }

    // HR Stability Setting
    function setStability(option) {
        mStability = option;
    }

    // Max HR Formula
    function setMaxHRFormula(option) {
        mMaxHRFormula = option;
    }

    function setStats() {
        var activity = Activity.getActivityInfo();
        if (activity != null){

            if ( activity.elapsedTime != null ) {
                elapsedTime = activity.elapsedTime;
            } else {
                elapsedTime = 0;
            }

            if ( activity.calories != null ) {
                calories = activity.calories;
            } else {
                calories = 0;
            }

            if ( activity.averageHeartRate != null ) {
                averageHR = activity.averageHeartRate;
                averageHRPct = Math.round(( averageHR.toDouble() / mMaxHR.toDouble() ) * 100).toNumber();
            } else {
                averageHR = 0;
                averageHRPct = 0;
            }

            if ( activity.maxHeartRate != null ) {
                peakHR = activity.maxHeartRate;
                peakHRPct = Math.round(( peakHR.toDouble() / mMaxHR.toDouble() ) * 100).toNumber();
            } else {
                peakHR = 0;
                peakHRPct = 0;
            }

            if ( mSplats != null ) {
                splatPoints = mSplats;
                if ( mSession != null ) {
                    mSplatsField.setData( mSplats );
                }
            } else {
                splatPoints = 0;
            }

            zoneTimes = mZoneTimes;
        }
    }

    // Process splat points
    function splatCallback() {
        if( mHeartRate == null ) {
            return;
        }
        
        mHeartRate = 135;

        // Gray Zone
        if ( mHeartRate < mZones[0] ) {
            tz1++;
            mHeartRateZone = 1;
        // Blue Zone
        } else if ( mHeartRate < mZones[1] ) {
            tz2++;
            mHeartRateZone = 2;
        // Green Zone
        } else if ( mHeartRate < mZones[2] ) {
            tz3++;
            mHeartRateZone = 3;
        // Orange Zone
        } else if ( mHeartRate < mZones[3] ) {
            tz4++;
            mHeartRateZone = 4;
        } else if ( mHeartRate > mZones[3] ) {
            tz5++;
            mHeartRateZone = 5;
        }

        // Round up and then cast to integer
        mHeartRatePct = Math.round(( mHeartRate.toDouble() / mMaxHR.toDouble() ) * 100).toNumber();
        mZoneTimes = [ tz1, tz2, tz3, tz4, tz5 ];

        // Seconds in splat point zone (HR Zone 4 and 5)
        mSecondsSplat = (tz4 + tz5);
        mSplats = Math.round( ( mSecondsSplat ) / 60 );

        // Update the current splats field
        if ( mSession != null ) {
            mSplatsField.setData( mSplats );
        }

        // Increment timer
        mSeconds++;

        // Increment Stability timer if needed
        if ( mStabilityOn == true ) {
            mStabilityTimer++;
            Log.debug("Stability Mode On, Timer: " + mStabilityTimer);
        }
    }

    // Define the HR Zones as per OTF guidelines
    // See dist/OrangeTheoryCalculator.java for official calculations
    hidden function setZones() {

        var birthYear = Profile.getProfile().birthYear;
        var todayYear = Time.Gregorian.info(Time.today(), Time.FORMAT_SHORT).year;
        var gender = Profile.getProfile().gender;

        // SDK 2.3.x Simulator Bug?
        if ( birthYear < 1900 ) {
            birthYear += 1900;
        }

        // Get the users age (will not be exact due to Garmin only providing users birth year)
        // If user has not provided a birth year or the device cannot get the current date
        // default to 183 which is calulation for 35 years old with new OTF formula
        if ( birthYear == null || todayYear == null ) {
            mMaxHR = 183;
        } else {
            var userAge = ( todayYear - birthYear );

            // If the user age is out of bounds set it to an age of 30 just for sanity
            if ( userAge <= 0 || userAge > 120 ) {
                userAge = 35;
            }
			
            /*if ( gender == 0 ) {
                Log.debug("User Gender: Female");
                mMaxHR = ( 230 - userAge );
            } else {
                Log.debug("User Gender: Male");
                mMaxHR = ( 225 - userAge );
            }*/
            mMaxHR = (208 - (0.7 * userAge));

            // If we aren't getting a valid max HR
            if ( mMaxHR <= 0 || mMaxHR == null ) {
                mMaxHR = 183;
            }
            Log.debug("User Age: " + userAge);
            Log.debug("Max HR Set to: " + mMaxHR);
        }
        // define HR for blue/green/orange/red
        mZones = [ (mMaxHR * blueZone).toNumber(), (mMaxHR * greenZone).toNumber(), (mMaxHR * orangeZone).toNumber(), (mMaxHR * redZone).toNumber() ];
    }

    // Set the recording activity type as per user preferences
    function setActivity(type, subType) {
        if(Toybox has :ActivityRecording) {

            // Default and Treadmill Running
            if ( type == 0 ) {
                type = Recording.SPORT_RUNNING;
                subType = Recording.SUB_SPORT_TREADMILL;
            } else if ( type == 2 ) {
                type = Recording.SPORT_RUNNING;
                subType = Recording.SUB_SPORT_ROAD;
            } else if ( type == 1 ) {
                type = Recording.SPORT_TRAINING;
                if ( subType == 0 ) {
                    subType = Recording.SUB_SPORT_CARDIO_TRAINING;
                } else if ( subType == 1 ) {
                    subType = Recording.SUB_SPORT_STRENGTH_TRAINING;
                } else if ( subType == 2 ) {
                    subType = Recording.SUB_SPORT_FLEXIBILITY_TRAINING;
                }
            } else if ( type == 3 ) {
                type = Recording.SPORT_WALKING;
                subType = Recording.SUB_SPORT_TREADMILL;
            } else if ( type == 4 ) {
                type = Recording.SPORT_ROWING;
                subType = Recording.SUB_SPORT_INDOOR_ROWING;
            } else if ( type == 5 ) {
                type = Recording.SPORT_CYCLING;
                subType = Recording.SUB_SPORT_INDOOR_CYCLING;
            }

            // Create a new FIT recording session
            mSession = Recording.createSession({
            	:sport=>type, 
            	:subSport=>subType, 
            	:name => Ui.loadResource(Rez.Strings.hiit_training)
            });
            
            // Create the new FIT fields to record to.
            mSplatsField = mSession.createField("star_points", 0, Fit.DATA_TYPE_UINT16, {:mesgType => Fit.MESG_TYPE_SESSION, :units => Ui.loadResource(Rez.Strings.star_units)});

            Log.debug("Activity Recording Type: " + type + " Sub: " + subType);
        }
    }

}