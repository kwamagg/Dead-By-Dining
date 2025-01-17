Scriptname DeadByDiningActors extends ReferenceAlias


Actor Property DBD_Player Auto
Spell Property DBD_StartDetection Auto

Keyword Property DBD_Drink Auto
Keyword Property DBD_Blood Auto
Keyword Property DBD_Meat Auto
Keyword Property DBD_Vampire Auto
Keyword Property DBD_Beast Auto
Keyword Property DBD_Humanoid Auto
Keyword Property DBD_Disallowed Auto

GlobalVariable Property DBD_fakeAIEnabled Auto
GlobalVariable Property DBD_maxBottleDetectionRadius Auto
GlobalVariable Property DBD_minBottleDetectionTime Auto
GlobalVariable Property DBD_maxBottleDetectionTime Auto

ObjectReference observedBottle
Float minTime
Float maxTime


; ------------------------------------
; 1) List Functions
; ------------------------------------


Function DBD_CleanupBottle(ObjectReference akBottle)
    String poisonKey = "BottlePoisons_" + akBottle.GetFormID()
    String witnessesKey = "BottlePoisonsWitnesses_" + akBottle.GetFormID()
    String namesKey = "BottlePoisonsNames_" + akBottle.GetFormID()

    StorageUtil.UnsetStringValue(None, poisonKey)
    StorageUtil.UnsetStringValue(None, witnessesKey)
    StorageUtil.UnsetStringValue(None, namesKey)

    String allBottleIDs = StorageUtil.GetStringValue(None, "DBD_PoisonedBottleIDs")
    If allBottleIDs != ""
        String strFormID = akBottle.GetFormID()
        String[] splitted = StringUtil.Split(allBottleIDs, ",")

        splitted = PapyrusUtil.RemoveString(splitted, strFormID)
        String newBottleIDs = PapyrusUtil.StringJoin(splitted, ",")
        StorageUtil.SetStringValue(None, "DBD_PoisonedBottleIDs", newBottleIDs)
    EndIf
EndFunction


; ------------------------------------
; 2) Gameplay Functions
; ------------------------------------


Bool Function DBD_IsWitness(Actor akActor, ObjectReference akBottle)  
    String witnessKey  = "BottlePoisonsWitnesses_" + akBottle.GetFormID()
    String currentList = StorageUtil.GetStringValue(None, witnessKey)
    
    If currentList == ""
        Return False
    EndIf
    
    Int witnessFormID = akActor.GetFormID()
    If StringUtil.Find(currentList, witnessFormID) != -1
        Return True
    EndIf
    
    Return False
EndFunction


Function DBD_AssignVictim(Actor akVictim, ObjectReference akBottle)
    StorageUtil.SetIntValue(akVictim, "DBD_AssignedBottle", akBottle.GetFormID())
EndFunction


; ------------------------------------
; 3) Events
; ------------------------------------


Event OnInit()
    If DBD_fakeAIEnabled.GetValue() == 1.0
        PO3_Events_Alias.RegisterForObjectGrab(self)
    Else
        PO3_Events_Alias.UnregisterForObjectGrab(self)
    EndIf
EndEvent


Event OnPlayerLoadGame()
    If DBD_fakeAIEnabled.GetValue() == 1.0
        PO3_Events_Alias.RegisterForObjectGrab(self)
    Else
        PO3_Events_Alias.UnregisterForObjectGrab(self)
    EndIf
EndEvent


Event OnObjectRelease(ObjectReference akObjectRef)
    UnregisterForUpdate()
    
    If DBD_fakeAIEnabled.GetValue() != 1.0
        PO3_Events_Alias.UnregisterForObjectGrab(self)
        Return
    EndIf

    ; Poisoned Item Detection
    If (DBD_fakeAIEnabled.GetValue() == 1.0) && akObjectRef.HasKeyword(DBD_Drink) && (StorageUtil.GetStringValue(None, "BottlePoisons_" + akObjectRef.GetFormID()) != "")
        observedBottle = akObjectRef
        minTime = DBD_minBottleDetectionTime.GetValue()
        maxTime = DBD_maxBottleDetectionTime.GetValue()

        If maxTime < minTime
            Float temp = minTime
            minTime = maxTime
            maxTime = temp
        EndIf

        RegisterForSingleUpdate(Utility.RandomFloat(minTime, maxTime))
    EndIf
EndEvent


Event OnUpdate()
    Actor victim = Game.FindClosestActorFromRef(observedBottle, DBD_maxBottleDetectionRadius.GetValueInt())

    String allPickedUpBottleIDs = StorageUtil.GetStringValue(None, "DBD_PickedUpBottle")
    Int bottleFormID = observedBottle.GetFormID()

    ; The item was picked up
    If StringUtil.Find(allPickedUpBottleIDs, bottleFormID) != -1
        UnregisterForUpdate()
        Return

    ; Victim was found
    ElseIf victim && (victim != Game.GetPlayer()) && !victim.HasKeyword(DBD_Disallowed)
        If (!victim.HasKeyword(DBD_Beast) && !victim.HasKeyword(DBD_Vampire) && !observedBottle.HasKeyword(DBD_Blood)) || (victim.HasKeyword(DBD_Beast) && observedBottle.HasKeyword(DBD_Meat) && !observedBottle.HasKeyword(DBD_Blood)) || (victim.HasKeyword(DBD_Vampire) && observedBottle.HasKeyword(DBD_Blood))
            DBD_AssignVictim(victim, observedBottle)
            victim.AddSpell(DBD_StartDetection)
            UnregisterForUpdate()
            Return
        EndIf

    ; No victim -- new search loop
    Else
        RegisterForSingleUpdate(5)
    EndIf
EndEvent
