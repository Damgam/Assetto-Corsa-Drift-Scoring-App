---@ext
ConfigFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/DriftScoring/" .. "settings.ini")
DisplayScale = ConfigFile:get("settings", "displayscale", 1)
BoardScale = ConfigFile:get("settings", "boardscale", 1)
AngleScale = ConfigFile:get("settings", "anglescale", 1)
ShowPraises = ConfigFile:get("settings", "showpraises", true)
LapScoringEnabled = ConfigFile:get("settings", "lapscoring", true)
ConfigFile:set("settings", "displayscale", DisplayScale)
ConfigFile:set("settings", "boardscale", BoardScale)
ConfigFile:set("settings", "anglescale", AngleScale)
ConfigFile:set("settings", "showpraises", ShowPraises)
ConfigFile:set("settings", "lapscoring", LapScoringEnabled)
ConfigFile:save()

CurrentDriftTime = 0
CurrentDriftTimeout = 2
CurrentDriftScore = 0
CurrentDriftCombo = 1
TotalScore = 0
TotalScoreTarget = 0
BestDrift = 0
BestDriftTarget = 0
BestLapScore = 0
BestLapScoreTarget = 0
SecondsTimer = 0
UpdatesTimer = 0
LongDriftTimer = 0
NoDriftTimer = 0
SplineReached = 0
CurrentLapScoreCut = false
CurrentLapScoreCutValue = 0
CurrentLapScore = 0
CurrentLapScoreTarget = 0
SubmittedLapDriftScore = 0

ExtraScore = false
ExtraScoreMultiplier = 1
InitialScoreMultiplier = 0
NearestCarDistance = 1


local TrackHasSpline = ac.hasTrackSpline() and LapScoringEnabled
ac.log("TrackHasSpline", TrackHasSpline)

RecordsFile = ac.INIConfig.load(ac.getFolder(ac.FolderID.ACApps) .. "/lua/DriftScoring/" .. "data.ini")
RecordDrift = 0
RecordDriftTarget = RecordsFile:get(ac.getCarID(0) .. "_" .. ac.getTrackFullID("_"), "recorddrift", 0)
RecordBestLap = 0
RecordBestLapTarget = RecordsFile:get(ac.getCarID(0) .. "_" .. ac.getTrackFullID("_"), "recordlap", 0)

ComboReached = 0

NoWarning = true


Sim = ac.getSim()
Car = ac.getCar(0)

local angle
local dirt

function getNearbyCarDistance()
    PlayerCarPos = ac.getCar(Car.index).position
    local lowestDist = 9999999
    for i = 1,9999 do
        if ac.getCar(i) and i ~= 0 then
            local distance = math.distance(ac.getCar(0).position, ac.getCar(i).position)
            if distance < lowestDist and (not ac.getCar(i).isInPit) and (not ac.getCar(i).isInPitlane) and ac.getCar(i).isConnected then
                lowestDist = distance
            end
        elseif not ac.getCar(i) then
            break
        end
    end
    return lowestDist
end

function script.update(dt)
    Sim = ac.getSim()
    Car = ac.getCar(0)
    if not Sim.isPaused then
        SecondsTimer = SecondsTimer + dt
        UpdatesTimer = UpdatesTimer + 1
        angle = math.max(0, ((math.max(math.abs(Car.wheels[2].slipAngle), math.abs(Car.wheels[3].slipAngle)))))
        if (Car.localVelocity.z <= 0 and Car.speedKmh > 1) then
            angle = 180-angle
        end
        dirt = math.min(math.abs(Car.wheels[0].surfaceDirt), math.abs(Car.wheels[1].surfaceDirt), math.abs(Car.wheels[2].surfaceDirt), math.abs(Car.wheels[3].surfaceDirt))
        if angle > 10 and Car.speedKmh > 20 and dirt == 0 and Car.wheelsOutside < 4 and ((not TrackHasSpline) or Car.splinePosition >= SplineReached-0.0001) then
            CurrentDriftTimeout = math.min(1, CurrentDriftTimeout + dt)
            CurrentDriftScore = CurrentDriftScore + (((((angle-10)*10+(Car.speedKmh-20)*10)*0.5)*dt*CurrentDriftCombo))*ExtraScoreMultiplier*InitialScoreMultiplier*0.2
            CurrentDriftCombo = math.min(5, CurrentDriftCombo + (((((angle-10)+(Car.speedKmh-20))*0.5)*dt)/100)*ExtraScoreMultiplier*InitialScoreMultiplier*0.5)
            LongDriftTimer = LongDriftTimer + dt
            NoDriftTimer = 0.5
            InitialScoreMultiplier = math.min(1, LongDriftTimer)
            if ComboReached < CurrentDriftCombo then
                ComboReached = CurrentDriftCombo
            end
        elseif CurrentDriftCombo > 1 then
            CurrentDriftTimeout = math.min(1, CurrentDriftTimeout + dt)
            CurrentDriftCombo = math.max(1, CurrentDriftCombo - 0.1*(NoDriftTimer^2)*dt)
            NoDriftTimer = NoDriftTimer + dt
            LongDriftTimer = 0
        elseif CurrentDriftCombo == 1 and CurrentDriftTimeout > 0 then
            CurrentDriftTimeout = CurrentDriftTimeout - dt
            NoDriftTimer = NoDriftTimer + dt
            LongDriftTimer = 0
        elseif CurrentDriftTimeout <= 0 then
            CurrentDriftTimeout = 0
            LongDriftTimer = 0
            NoDriftTimer = NoDriftTimer + dt
            if NoWarning then
                if CurrentDriftScore > 0 then
                    TotalScoreTarget = TotalScoreTarget + math.floor(CurrentDriftScore)
                    if TrackHasSpline then
                        SubmittedLapDriftScore = SubmittedLapDriftScore + math.max(0, math.floor(CurrentDriftScore))
                    end
                    if math.floor(CurrentDriftScore) > BestDriftTarget then
                        BestDriftTarget = math.floor(CurrentDriftScore)
                    end
                end
            end
            CurrentDriftScore = 0
            CurrentDriftCombo = 1
            ComboReached = 0
        end
        CurrentLapScoreTarget = CurrentLapScoreCutValue + SubmittedLapDriftScore + math.floor(CurrentDriftScore)
        if (not CurrentLapScoreCut) and CurrentLapScoreTarget < 0 then
            repeat
                if CurrentLapScoreTarget > CurrentLapScoreCutValue*0.99 then
                    CurrentLapScoreCutValue = CurrentLapScoreCutValue*0.99
                else
                    CurrentLapScoreCutValue = CurrentLapScoreCutValue + 1
                end
                CurrentLapScoreTarget = CurrentLapScoreCutValue + SubmittedLapDriftScore + math.floor(CurrentDriftScore)
            until CurrentLapScoreTarget >= 0
        end

        if TotalScore ~= TotalScoreTarget then
            TotalScore = TotalScore + math.floor((TotalScoreTarget - TotalScore)/50)
            if math.floor((TotalScoreTarget - TotalScore)/50) == 0 then
                TotalScore = TotalScore + math.floor(TotalScoreTarget - TotalScore)
            end
        end
        if BestDrift ~= BestDriftTarget then
            BestDrift = BestDrift + math.floor((BestDriftTarget - BestDrift)/50)
            if math.floor((BestDriftTarget - BestDrift)/50) == 0 then
                BestDrift = BestDrift + math.floor(BestDriftTarget - BestDrift)
            end
        end
        if CurrentLapScore ~= CurrentLapScoreTarget then
            CurrentLapScore = CurrentLapScore + math.floor((CurrentLapScoreTarget - CurrentLapScore)/50)
            if math.floor((CurrentLapScoreTarget - CurrentLapScore)/50) == 0 then
                CurrentLapScore = CurrentLapScore + math.floor(CurrentLapScoreTarget - CurrentLapScore)
            end
        end
        if BestLapScore ~= BestLapScoreTarget then
            BestLapScore = BestLapScore + math.floor((BestLapScoreTarget - BestLapScore)/50)
            if math.floor((BestLapScoreTarget - BestLapScore)/50) == 0 then
                BestLapScore = BestLapScore + math.floor(BestLapScoreTarget - BestLapScore)
            end
        end
        if RecordDrift ~= RecordDriftTarget then
            RecordDrift = RecordDrift + math.floor((RecordDriftTarget - RecordDrift)/50)
            if math.floor((RecordDriftTarget - RecordDrift)/50) == 0 then
                RecordDrift = RecordDrift + math.floor(RecordDriftTarget - RecordDrift)
            end
        end
        if RecordBestLap ~= RecordBestLapTarget then
            RecordBestLap = RecordBestLap + math.floor((RecordBestLapTarget - RecordBestLap)/50)
            if math.floor((RecordBestLapTarget - RecordBestLap)/50) == 0 then
                RecordBestLap = RecordBestLap + math.floor(RecordBestLapTarget - RecordBestLap)
            end
        end

        NoWarning = true
        if Car.speedKmh <= 20 or (dirt > 0 or Car.wheelsOutside == 4) then
            NoWarning = false
        end

        if TrackHasSpline then
            if Car.lapTimeMs < 3000 or Car.splinePosition < 0.001 then
                SplineReached = 0
            elseif Car.splinePosition > SplineReached then
                SplineReached = Car.splinePosition
            elseif Car.splinePosition < SplineReached-0.0001 then
                NoWarning = false
            end

            if Car.lapTimeMs < 1000 and CurrentLapScoreCut == false then
                CurrentLapScoreCut = true
                if CurrentLapScore > BestLapScore then
                    BestLapScoreTarget = CurrentLapScore
                end
                CurrentLapScoreTarget = 0
                SubmittedLapDriftScore = 0
                CurrentLapScoreCutValue = -math.floor(CurrentDriftScore)
            elseif Car.lapTimeMs >= 1000 then
                CurrentLapScoreCut = false
                if math.floor(CurrentDriftScore) == 0 and CurrentLapScoreTarget < -1 then
                    CurrentLapScoreCutValue = 0
                    CurrentLapScoreTarget = 0
                end
            end
        end

        ExtraScore = false
        ExtraScoreMultiplier = 1
        if NoWarning then
            if angle > 120 then
                ExtraScoreMultiplier = ExtraScoreMultiplier * 0
                ExtraScore = true
                LongDriftTimer = 0
            end
            if Car.brake > 0.05 or Car.handbrake > 0.05 then
                ExtraScoreMultiplier = ExtraScoreMultiplier * 0.5
                ExtraScore = true
            end
            if NearestCarDistance < 7.5 then
                ExtraScoreMultiplier = ExtraScoreMultiplier * 2
                ExtraScore = true
            end
            if angle > 90 and angle <= 120 then
                ExtraScoreMultiplier = ExtraScoreMultiplier * 1.5
                ExtraScore = true
            end
            if LongDriftTimer > 3 then
                LongDriftBonus = math.ceil((LongDriftTimer/9)*10 + 6.666)/10
                ExtraScoreMultiplier = ExtraScoreMultiplier * LongDriftBonus
                ExtraScore = true
            end
            if UpdatesTimer%30 == 15 then
                NearestCarDistance = getNearbyCarDistance()
            end
            ExtraScoreMultiplier = math.ceil(ExtraScoreMultiplier*20)/20
        end

        if NoWarning == false and CurrentDriftCombo > 1 then
            ComboReached = 0
            CurrentDriftScore = CurrentDriftScore - (CurrentDriftScore*dt)
            if CurrentDriftScore > 0 then
                CurrentDriftCombo = math.max(1, CurrentDriftCombo - dt)
            else
                CurrentDriftCombo = 1
            end
        elseif NoWarning == false and CurrentDriftCombo == 1 then
            ComboReached = 0
            CurrentDriftScore = CurrentDriftScore - (CurrentDriftScore*2*dt)
        end

        if SettingsShowScoreDisplay and SettingsShowScoreDisplay > 0 then
            SettingsShowScoreDisplay = SettingsShowScoreDisplay - 1
        end

        if BestDriftTarget > RecordDriftTarget then
            RecordDriftTarget = BestDriftTarget
            RecordsFile:set(ac.getCarID(0) .. "_" .. ac.getTrackFullID("_"), "recorddrift", BestDriftTarget)
            RecordsFile:save()
        end

        if TrackHasSpline and BestLapScoreTarget > RecordBestLapTarget then
            RecordBestLapTarget = BestLapScoreTarget
            RecordsFile:set(ac.getCarID(0) .. "_" .. ac.getTrackFullID("_"), "recordlap", BestLapScoreTarget)
            RecordsFile:save()
        end
    end
end

function script.windowDisplay()
    ui.beginOutline()
    ui.pushDWriteFont('OPTIEdgarBold:\\Fonts;Weight=Medium')
    local color = rgbm(1, 1, 1, math.min(1, CurrentDriftTimeout*5))
    local colorRed = rgbm(1, 0, 0, math.min(1, CurrentDriftTimeout*5))
    local colorGreen = rgbm(0, 1, 0.1, math.min(1, CurrentDriftTimeout*5))
    local colorGreenBland = rgbm(0.65, 1, 0.65, math.min(1, CurrentDriftTimeout*5))
    local colorYellow = rgbm(1, 1, 0, math.min(1, CurrentDriftTimeout*5))
    local colorYellowBland = rgbm(1, 1, 0.5, math.min(1, CurrentDriftTimeout*5))
    if Car.speedKmh <= 20 or dirt > 0 or Car.wheelsOutside == 4 or (TrackHasSpline and Car.splinePosition < SplineReached-0.0001) then
        color = rgbm(1, 0.5, 0, math.min(1, CurrentDriftTimeout*5))
    elseif ExtraScore and ExtraScoreMultiplier ~= 1 then
        if ExtraScoreMultiplier >= 2 then
            color = colorGreen
        elseif ExtraScoreMultiplier > 1 then
            color = colorGreenBland
        elseif ExtraScoreMultiplier == 0 then
            color = colorYellow
        elseif ExtraScoreMultiplier < 1 then
            color = colorYellowBland
        end
    end

    if (SettingsShowScoreDisplay and SettingsShowScoreDisplay > 0) then
        color = rgbm(1, 0.5, 0, 1)
        colorRed = rgbm(1, 0, 0, 1)
        colorGreen = rgbm(0, 1, 0.1, 1)
    end

    if math.min(1, CurrentDriftTimeout*5) > 0 or (SettingsShowScoreDisplay and SettingsShowScoreDisplay > 0) then
        local ExtraMultiplierDisplay = ""
        if ExtraScore then
            ExtraMultiplierDisplay = " x" .. ExtraScoreMultiplier
            if ExtraScoreMultiplier%1 == 0 then
                ExtraMultiplierDisplay = ExtraMultiplierDisplay .. ".0"
            end
        end
        if math.ceil(CurrentDriftCombo*10)/10 % 1 ~= 0 then
            ui.dwriteText("x" .. math.ceil(CurrentDriftCombo*10)/10 .. ExtraMultiplierDisplay, 30*DisplayScale, color)
        else
            if math.ceil(CurrentDriftCombo*10) == 50 and ExtraScoreMultiplier >= 1 then
                ui.dwriteText("x" .. math.ceil(CurrentDriftCombo*10)/10 .. ".0" .. ExtraMultiplierDisplay, 30*DisplayScale, colorGreen)
            else
                ui.dwriteText("x" .. math.ceil(CurrentDriftCombo*10)/10 .. ".0" .. ExtraMultiplierDisplay, 30*DisplayScale, color)
            end
        end
        ui.dwriteText(math.floor(CurrentDriftScore), 40*DisplayScale, color)

        if Car.speedKmh <= 20 then
            ui.dwriteText("TOO SLOW!", 20*DisplayScale, colorRed)
        end
    
        if (TrackHasSpline and Car.splinePosition < SplineReached-0.0001) then
            ui.dwriteText("DRIVING BACKWARDS!", 20*DisplayScale, colorRed)
        end
    
        if dirt > 0 or Car.wheelsOutside == 4 then
            ui.dwriteText("OFF-TRACK!", 20*DisplayScale, colorRed)
        end
    
    
    
        if NoWarning and ShowPraises then
            if CurrentDriftScore > 64000 then
                ui.dwriteText("Impossible Drift!", 20*DisplayScale, colorGreen)
            elseif ComboReached >= 5 or CurrentDriftScore > 32000 then
                ui.dwriteText("Incredible Drift!", 20*DisplayScale, colorGreen)
            elseif ComboReached >= 4.5 or CurrentDriftScore > 16000 then
                ui.dwriteText("Insane Drift!", 20*DisplayScale, colorGreen)
            elseif ComboReached >= 4 or CurrentDriftScore > 8000 then
                ui.dwriteText("Amazing Drift!", 20*DisplayScale, colorGreen)
            elseif ComboReached >= 3.5 or CurrentDriftScore > 4000 then
                ui.dwriteText("Great Drift!", 20*DisplayScale, colorGreen)
            elseif ComboReached >= 3 or CurrentDriftScore > 2000 then
                ui.dwriteText("Good Drift!", 20*DisplayScale, colorGreen)
            elseif ComboReached >= 2 or CurrentDriftScore > 1000 then
                ui.dwriteText("Nice Drift!", 20*DisplayScale, colorGreen)
            else
                ui.dwriteText("Drift!", 20*DisplayScale, colorGreen)
            end
        end

        if NoWarning then
            if NearestCarDistance < 7.5 then
                ui.dwriteText("Tandem! x2", 20*DisplayScale, colorGreen)
            end

            if LongDriftTimer > 3 then
                if LongDriftBonus%1 == 0 then
                    LongDriftBonus = LongDriftBonus .. ".0"
                end
                ui.dwriteText("Long Drift! x" .. LongDriftBonus, 20*DisplayScale, colorGreen)
            end
            

            if angle > 90 and angle <= 120 then
                ui.dwriteText("Reverse Drift! x1.5", 20*DisplayScale, colorGreen)
            end

            if Car.brake > 0.05 or Car.handbrake > 0.05 then
                ui.dwriteText("Braking! x0.5", 20*DisplayScale, colorYellow)
            end

            if angle > 120 then
                ui.dwriteText("Too much angle! x0", 20*DisplayScale, colorYellow)
            end
        end
    end
    
    

    ui.endOutline(0, 1.5)
    ui.popDWriteFont()
end

function script.windowBoard()
    ui.beginOutline()
    ui.pushDWriteFont('OPTIEdgarBold:\\Fonts;Weight=Medium')
    local colorNoFade = rgbm(1, 1, 1, 1)
    ui.dwriteText("—————————————————", 18*BoardScale, colorNoFade)
    ui.dwriteText("Total Score:                         " .. TotalScore, 18*BoardScale, colorNoFade)
    ui.dwriteText("—————————————————", 18*BoardScale, colorNoFade)
    ui.dwriteText("Best Drift:                             " .. BestDrift, 18*BoardScale, colorNoFade)
    ui.dwriteText("Record Drift:                     " .. RecordDrift, 18*BoardScale, colorNoFade)
    ui.dwriteText("—————————————————", 18*BoardScale, colorNoFade)
    if TrackHasSpline then
    ui.dwriteText("Current Lap Score:  " .. CurrentLapScore, 18*BoardScale, colorNoFade)
    ui.dwriteText("Best Lap Score:            " .. BestLapScore, 18*BoardScale, colorNoFade)
    ui.dwriteText("Record Lap Score:    " .. RecordBestLap, 18*BoardScale, colorNoFade)
    ui.dwriteText("—————————————————", 18*BoardScale, colorNoFade)
    end

    ui.endOutline(0, 1.5)
    ui.popDWriteFont()
end

function script.windowAngle()
    ui.beginOutline()
    ui.pushDWriteFont('OPTIEdgarBold:\\Fonts;Weight=Medium')


    if (SettingsShowScoreDisplay and SettingsShowScoreDisplay > 0) then
        color = rgbm(1, 1, 1, 1)
    end
    
    if angle then
        if (SettingsShowScoreDisplay and SettingsShowScoreDisplay > 0) then
            color = rgbm(1, 1, 1, 1)
        elseif angle < 10 or angle > 120 then
            color = rgbm(1, 0, 0, math.min(1, CurrentDriftTimeout*5)) -- red
        elseif angle < 15 or angle > 115 then
            color = rgbm(1, 1, 0, math.min(1, CurrentDriftTimeout*5)) -- yellow
        elseif angle < 20 or angle > 110 then
            color = rgbm(1, 1, 0.5, math.min(1, CurrentDriftTimeout*5)) -- yellowBland
        elseif angle < 35 or angle > 100 then
            color = rgbm(1, 1, 1, math.min(1, CurrentDriftTimeout*5)) -- white
        elseif angle < 50 or angle > 95 then
            color = rgbm(0, 1, 0.65, math.min(1, CurrentDriftTimeout*5)) -- greenBland
        else
            color = rgbm(0, 1, 0.1, math.min(1, CurrentDriftTimeout*5))-- green
        end
        if math.floor(angle) >= 10 then
            ui.dwriteText("∠" .. math.floor(angle) .. "°", 40*AngleScale, color)
        else
            ui.dwriteText("∠0" .. math.floor(angle) .. "°", 40*AngleScale, color)
        end
    end


    ui.endOutline(0, 1.5)
    ui.popDWriteFont()
end

function script.windowSettings()
    ui.text('Drift Score Display Size')
    local sliderValue1 = ConfigFile:get("settings", "displayscale", 1)
    sliderValue1 = ui.slider("(Default 1) ##slider1", sliderValue1, 0.5, 2)
    if DisplayScale ~= sliderValue1 then
        DisplayScale = sliderValue1
        ConfigFile:set("settings", "displayscale", sliderValue1)
        NeedToSaveConfig = true
        SettingsShowScoreDisplay = 300
    end

    ui.text('Drift Score Board Size')
    local sliderValue2 = ConfigFile:get("settings", "boardscale", 1)
    sliderValue2 = ui.slider("(Default 1) ##slider2", sliderValue2, 0.5, 2)
    if BoardScale ~= sliderValue2 then
        BoardScale = sliderValue2
        ConfigFile:set("settings", "boardscale", sliderValue2)
        NeedToSaveConfig = true
        SettingsShowScoreDisplay = 300
    end

    ui.text('Drift Score Angle Size')
    local sliderValue3 = ConfigFile:get("settings", "anglescale", 1)
    sliderValue3 = ui.slider("(Default 1) ##slider3", sliderValue3, 0.5, 2)
    if AngleScale ~= sliderValue3 then
        AngleScale = sliderValue3
        ConfigFile:set("settings", "anglescale", sliderValue3)
        NeedToSaveConfig = true
        SettingsShowScoreDisplay = 300
    end

    local checkbox = ui.checkbox("Enable Praises (Nice Drift!)", ShowPraises)
    if checkbox then
        ShowPraises = not ShowPraises
        ConfigFile:set("settings", "showpraises", ShowPraises)
        NeedToSaveConfig = true
    end

    local checkbox = ui.checkbox("Enable Lap Scoring", LapScoringEnabled)
    if checkbox then
        LapScoringEnabled = not LapScoringEnabled
        ConfigFile:set("settings", "lapscoring", LapScoringEnabled)
        TrackHasSpline = ac.hasTrackSpline() and LapScoringEnabled
        CurrentDriftScore = 0
        CurrentDriftCombo = 1
        NeedToSaveConfig = true
    end
    if ui.itemHovered() then
        ui.setTooltip("By default, the scoring system doesn't allow you to drift the track backwards to prevent cheating on the lap records. With this checkbox, you can turn this functionality off, allowing you to gain points drifting in any direction, but it turns off the lap records. PLEASE NOTE THAT THIS FEATURE IS ALWAYS DISABLED ON TRACKS THAT ARE MISSING AI SPLINE!")
    end

    if NeedToSaveConfig then
        ConfigFile:save()
    end
end
