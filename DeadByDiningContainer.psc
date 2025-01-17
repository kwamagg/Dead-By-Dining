Scriptname DeadByDiningContainer extends ObjectReference


Keyword Property DBD_Poison Auto
Keyword Property DBD_Humanoid Auto
Keyword Property DBD_Disallowed Auto

GlobalVariable Property DBD_maxPoisonsAmount Auto
GlobalVariable Property DBD_maxBottleDetectionRadius Auto


; ------------------------------------
; 1) List Functions
; ------------------------------------


Function DBD_AddBottleToGlobalList(ObjectReference akBottle)
    String allBottleIDs = StorageUtil.GetStringValue(None, "DBD_PoisonedBottleIDs")
    Int formID = akBottle.GetFormID()

    If allBottleIDs == ""
        allBottleIDs = formID
    ElseIf StringUtil.Find(allBottleIDs, formID) == -1
        allBottleIDs += "," + formID
    EndIf

    StorageUtil.SetStringValue(None, "DBD_PoisonedBottleIDs", allBottleIDs)
EndFunction


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


Function DBD_AddWitness(Actor akWitness, ObjectReference akBottle)
    String witnessKey  = "BottlePoisonsWitnesses_" + akBottle.GetFormID()
    String currentList = StorageUtil.GetStringValue(None, witnessKey)
    Int witnessFormID = akWitness.GetFormID()

    If currentList != ""
        If StringUtil.Find(currentList, witnessFormID) == -1
            currentList = currentList + "," + witnessFormID
        EndIf
    Else
        currentList = witnessFormID
    EndIf

    StorageUtil.SetStringValue(None, witnessKey, currentList)
EndFunction


Function DBD_WitnessRemovesThreat(Actor akWitness, ObjectReference akBottle)
    akWitness.SetExpressionOverride(14, 65)
    akWitness.SetLookAt(akBottle, True)
    Utility.Wait(2)
    Debug.SendAnimationEvent(akWitness, "IdleActivatePickUp")
    Utility.Wait(2)
    akWitness.ClearExpressionOverride()
    akWitness.ClearLookAt()
    DBD_CleanupBottle(akBottle)
    akBottle.Disable()
    akBottle.Delete()
    akBottle = None
EndFunction


; ------------------------------------
; 3) Events
; ------------------------------------


Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemRef, ObjectReference akSourceContainer)
     
    ; Poison Adding
    If akBaseItem.HasKeyword(DBD_Poison)
        self.RemoveItem(akBaseItem, aiItemCount, True)

        Int tmpBottleID = StorageUtil.GetIntValue(None, "DBD_TempSelectedBottle")
        ObjectReference akBottle = Game.GetFormEx(tmpBottleID) as ObjectReference
        String currentBottleName = akBottle.GetDisplayName()
        String currentPoisons = StorageUtil.GetStringValue(None, "BottlePoisons_" + akBottle.GetFormID())
        StorageUtil.SetStringValue(None, "BottlePoisons_" + akBottle.GetFormID(), "")
        String[] poisonArray = StringUtil.Split(currentPoisons, ",")
        Int currentPoisonCount = poisonArray.Length
        
        If (currentPoisonCount + aiItemCount) <= DBD_maxPoisonsAmount.GetValueInt()

            While aiItemCount > 0
                If currentPoisons != ""
                    currentPoisons += "," + akBaseItem.GetFormID()
                Else
                    currentPoisons = akBaseItem.GetFormID()
                EndIf
                aiItemCount -= 1
            EndWhile

            StorageUtil.SetStringValue(None, "BottlePoisons_" + akBottle.GetFormID(), currentPoisons)
            Debug.Notification("Successfully added.")

            If currentBottleName != (akBottle.GetBaseObject().GetName())
                currentBottleName += ", " + akBaseItem.GetName()
            Else
                currentBottleName += ", Poisoned With " + akBaseItem.GetName()
            EndIf

            akBottle.SetDisplayName(currentBottleName, True)
            StorageUtil.SetStringValue(None, "BottlePoisonsNames_" + akBottle.GetFormID(), currentBottleName)
            DBD_AddBottleToGlobalList(akBottle)
        Else
            Debug.Notification("You cannot add more than " + DBD_maxPoisonsAmount.GetValueInt() + " poisons.")
            self.RemoveItem(akBaseItem, aiItemCount, True)
            Game.GetPlayer().AddItem(akBaseItem, aiItemCount, True)
        EndIf

        Actor npc = Game.FindClosestActorFromRef(akBottle, DBD_maxBottleDetectionRadius.GetValue())

        If npc
            If npc.HasKeyword(DBD_Humanoid) && !npc.HasKeyword(DBD_Disallowed) && !npc.IsDead() && !npc.IsGhost() && !npc.IsUnconscious() && !npc.IsBeingRidden()
                

                ; Friendly NPC as a Witness
                If !npc.IsHostileToActor(Game.GetPlayer()) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && (npc.IsPlayerTeammate() || (npc.GetRelationshipRank(Game.GetPlayer()) >= 1)) 
                    DBD_AddWitness(npc, akBottle)
                

                ; Non-Friendly NPC as a Witness
                ElseIf !npc.IsHostileToActor(Game.GetPlayer()) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && !npc.IsPlayerTeammate() && (npc.GetRelationshipRank(Game.GetPlayer()) <= 0)
                    npc.SendAssaultAlarm()
                    DBD_WitnessRemovesThreat(npc, akBottle)
                

                ; Hostile NPC Sees Poisoning During Combat
                ElseIf npc && Game.GetPlayer().IsDetectedBy(npc) && npc.IsInCombat()
                    DBD_AddWitness(npc, akBottle)
                EndIf

            EndIf
            npc = None

        EndIf
        StorageUtil.UnsetIntValue(None, "DBD_TempSelectedBottle")
        Return
    

    ; Non-Poison Adding
    ElseIf !akBaseItem.HasKeyword(DBD_Poison)
        Debug.Notification("You cannot add it there.")
        self.RemoveItem(akBaseItem, aiItemCount, True)
        Game.GetPlayer().AddItem(akBaseItem, aiItemCount, True)
        StorageUtil.UnsetIntValue(None, "DBD_TempSelectedBottle")
        Return
    EndIf
EndEvent
