Scriptname DeadByDiningMCM extends MCM_ConfigBase

Quest Property DeadByDiningQuest Auto
GlobalVariable Property DBD_Hotkey Auto
GlobalVariable Property DBD_maxPoisonsAmount Auto
GlobalVariable Property DBD_fakeAIEnabled Auto
GlobalVariable Property DBD_falsePoisonerEnabled Auto
GlobalVariable Property DBD_maxBottleDetectionRadius Auto
GlobalVariable Property DBD_minBottleDetectionTime Auto
GlobalVariable Property DBD_maxBottleDetectionTime Auto


Bool migrated = False

Int Function GetVersion()
    return 1
EndFunction

Event OnUpdate()
    parent.OnUpdate()
    If !migrated
        MigrateToMCMHelper()
        migrated = True
    EndIf
EndEvent

Event OnGameReload()
    parent.OnGameReload()
    If !migrated
        MigrateToMCMHelper()
        migrated = True
    EndIf
    If GetModSettingBool("bLoadSettingsonReload:Maintenance")
        LoadSettings()
    EndIf
EndEvent

Event OnConfigOpen()
    parent.OnConfigOpen()
    If !migrated
        MigrateToMCMHelper()
        migrated = True
    EndIf
EndEvent

Event OnConfigInit()
    parent.OnConfigInit()
    migrated = True
    LoadSettings()
EndEvent

Event OnSettingChange(String a_ID)
    parent.OnSettingChange(a_ID)
    If a_ID == "iHotkey:General"
        DBD_Hotkey.SetValue(GetModSettingInt("iHotkey:General") as Float)
        (DeadByDiningQuest.GetAlias(0) as ReferenceAlias).OnPlayerLoadGame()
        RefreshMenu()
    ElseIf a_ID == "imaxPoisonsAmount:General"
        DBD_maxPoisonsAmount.SetValue(GetModSettingInt("imaxPoisonsAmount:General") as Float)
        (DeadByDiningQuest.GetAlias(0) as ReferenceAlias).OnPlayerLoadGame()
        RefreshMenu()
    ElseIf a_ID == "bfakeAIEnabled:General"
        DBD_fakeAIEnabled.SetValue(GetModSettingBool("bfakeAIEnabled:General") as Float)
        (DeadByDiningQuest.GetAlias(0) as ReferenceAlias).OnPlayerLoadGame()
        RefreshMenu()
    ElseIf a_ID == "bfalsePoisonerEnabled:General"
        DBD_falsePoisonerEnabled.SetValue(GetModSettingBool("bfalsePoisonerEnabled:General") as Float)
        (DeadByDiningQuest.GetAlias(0) as ReferenceAlias).OnPlayerLoadGame()
        RefreshMenu()
    ElseIf a_ID == "imaxBottleDetectionRadius:General"
        DBD_maxBottleDetectionRadius.SetValue(GetModSettingInt("imaxBottleDetectionRadius:General") as Float)
        (DeadByDiningQuest.GetAlias(0) as ReferenceAlias).OnPlayerLoadGame()
        RefreshMenu()
    ElseIf a_ID == "fminBottleDetectionTime:General"
        DBD_minBottleDetectionTime.SetValue(GetModSettingFloat("fminBottleDetectionTime:General") as Float)
        (DeadByDiningQuest.GetAlias(0) as ReferenceAlias).OnPlayerLoadGame()
        RefreshMenu()
    ElseIf a_ID == "fmaxBottleDetectionTime:General"
        DBD_maxBottleDetectionTime.SetValue(GetModSettingFloat("fmaxBottleDetectionTime:General") as Float)
        (DeadByDiningQuest.GetAlias(0) as ReferenceAlias).OnPlayerLoadGame()
        RefreshMenu()
    EndIf
EndEvent

Event OnPageSelect(String a_page)
    parent.OnPageSelect(a_page)
EndEvent

Function Default()
    SetModSettingInt("iHotkey:General", 35)
    SetModSettingInt("imaxPoisonsAmount:General", 5)
    SetModSettingBool("bfakeAIEnabled:General", True)
    SetModSettingBool("bfalsePoisonerEnabled:General", True)
    SetModSettingInt("imaxBottleDetectionRadius:General", 1250)
    SetModSettingFloat("fminBottleDetectionTime:General", 2.0)
    SetModSettingFloat("fmaxBottleDetectionTime:General", 20.0)
    SetModSettingBool("bEnabled:Maintenance", True)
    SetModSettingInt("iLoadingDelay:Maintenance", 0)
    SetModSettingBool("bLoadSettingsonReload:Maintenance", False)
    Load()
EndFunction

Function Load()
    DBD_Hotkey.SetValue(GetModSettingInt("iHotkey:General") as Float)
    DBD_maxPoisonsAmount.SetValue(GetModSettingInt("imaxPoisonsAmount:General") as Float)
    DBD_fakeAIEnabled.SetValue(GetModSettingBool("bfakeAIEnabled:General") as Float)
    DBD_falsePoisonerEnabled.SetValue(GetModSettingBool("bfalsePoisonerEnabled:General") as Float)
    DBD_maxBottleDetectionRadius.SetValue(GetModSettingInt("imaxBottleDetectionRadius:General") as Float)
    DBD_minBottleDetectionTime.SetValue(GetModSettingFloat("fminBottleDetectionTime:General") as Float)
    DBD_maxBottleDetectionTime.SetValue(GetModSettingFloat("fmaxBottleDetectionTime:General") as Float)
    (DeadByDiningQuest.GetAlias(0) as ReferenceAlias).OnPlayerLoadGame()
EndFunction

Function LoadSettings()
    If GetModSettingBool("bEnabled:Maintenance") == False
        Return
    EndIf
    Utility.Wait(GetModSettingInt("iLoadingDelay:Maintenance"))
    Load()
EndFunction

Function MigrateToMCMHelper()
    SetModSettingInt("iHotkey:General", DBD_Hotkey.GetValue() as Int)
    SetModSettingInt("imaxPoisonsAmount:General", DBD_maxPoisonsAmount.GetValue() as Int)
    SetModSettingBool("bfakeAIEnabled:General", DBD_fakeAIEnabled.GetValue() as Bool)
    SetModSettingBool("bfalsePoisonerEnabled:General", DBD_falsePoisonerEnabled.GetValue() as Bool)
    SetModSettingInt("imaxBottleDetectionRadius:General", DBD_maxBottleDetectionRadius.GetValue() as Int)
    SetModSettingFloat("fminBottleDetectionTime:General", DBD_minBottleDetectionTime.GetValue() as Float)
    SetModSettingFloat("fmaxBottleDetectionTime:General", DBD_maxBottleDetectionTime.GetValue() as Float)
EndFunction
