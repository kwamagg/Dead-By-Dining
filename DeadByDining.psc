Scriptname DeadByDining extends ReferenceAlias


Actor Property DBD_Player Auto
ObjectReference Property DBD_Container Auto

Keyword Property DBD_Drink Auto
Keyword Property DBD_Poison Auto

GlobalVariable Property DBD_Hotkey Auto
GlobalVariable Property DBD_maxPoisonsAmount Auto
GlobalVariable Property DBD_maxBottleDetectionRadius Auto
GlobalVariable Property DBD_minBottleDetectionTime Auto
GlobalVariable Property DBD_maxBottleDetectionTime Auto

Actor currentActor
ObjectReference currentBottle
ObjectReference observedBottle
ObjectReference feltBottle
String currentBottleName



; System Functions

String[] Function RemoveStringAt(String[] akArray, Int aiIndex)
    Int arrayLength = akArray.Length
    If aiIndex < 0 || aiIndex >= arrayLength
        Return akArray
    EndIf

    String[] newArray = Utility.CreateStringArray((arrayLength - 1), "")

    Int newIndex = 0
    Int i = 0

    While i < arrayLength
        If i != aiIndex
            newArray[newIndex] = akArray[i]
            newIndex += 1
        EndIf
        i += 1
    EndWhile

    Return newArray
EndFunction


String Function JoinStringArrayWithDelimiter(String[] akArray, String asDelimiter)
    String result = ""
    Int arrayLength = akArray.Length
    Int i = 0

    While i < arrayLength
        result += akArray[i]
        If i < arrayLength - 1
            result += asDelimiter
        EndIf
        i += 1
    EndWhile

    Return result
EndFunction


Function DBD_SetUp()
    RegisterForKey(DBD_Hotkey.GetValueInt())
    DbSkseEvents.RegisterAliasForGlobalEvent("OnContainerChangedGlobal", self)
    DbSkseEvents.RegisterAliasForGlobalEvent("OnObjectEquippedGlobal", self)
    RegisterForCrosshairRef()
EndFunction


; List Functions

Function AddBottleToGlobalList(ObjectReference akBottle)
    int formID = akBottle.GetFormID()

    String allBottleIDs = StorageUtil.GetStringValue(None, "DBD_PoisonedBottleIDs")

    If allBottleIDs == ""
        allBottleIDs = formID
    Else
        If StringUtil.Find(allBottleIDs, formID) == -1
            allBottleIDs += "," + formID
        EndIf
    EndIf

    StorageUtil.SetStringValue(None, "DBD_PoisonedBottleIDs", allBottleIDs)
EndFunction


Function RestoreBottleNames()
    String allBottleIDs = StorageUtil.GetStringValue(None, "DBD_PoisonedBottleIDs")
    If allBottleIDs == ""
        return
    EndIf

    String[] splittedIDs = StringUtil.Split(allBottleIDs, ",")
    int idx = 0
    While idx < splittedIDs.Length
        int formID = splittedIDs[idx] as Int
        ObjectReference possiblyBottle = Game.GetFormEx(formID) as ObjectReference
        If possiblyBottle
            String storedName = StorageUtil.GetStringValue(None, "BottlePoisonsNames_" + formID)
            If storedName != ""
                possiblyBottle.SetDisplayName(storedName, true)
            EndIf
        EndIf
        idx += 1
    EndWhile
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
        String strFormID = akBottle.GetFormID() as String
        String[] splitted = StringUtil.Split(allBottleIDs, ",")

        Int idx = 0
        While idx < splitted.Length
            If splitted[idx] == strFormID
                splitted = RemoveStringAt(splitted, idx)
                idx = splitted.Length
            EndIf
            idx += 1
        EndWhile
        
        String newBottleIDs = JoinStringArrayWithDelimiter(splitted, ",")
        StorageUtil.SetStringValue(None, "DBD_PoisonedBottleIDs", newBottleIDs)
    EndIf
EndFunction


; Gameplay Functions

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


Function DBD_WitnessRemoves(Actor akWitness)
    If akWitness && !currentActor.IsBeingRidden() && (akWitness != Game.GetPlayer())
        akWitness.SetLookAt(currentBottle, True)
        Utility.Wait(2)
        Debug.SendAnimationEvent(akWitness, "IdleActivatePickUp")
        Utility.Wait(2)
        akWitness.ClearLookAt()
        DBD_CleanupBottle(currentBottle)
        currentBottle.Disable()
        currentBottle.Delete()
        observedBottle = None
        currentBottle = None
    EndIf
EndFunction


Function DBD_Poison(Actor akActor, Form akBaseObject, ObjectReference akReference)
    String poisons = StorageUtil.GetStringValue(None, "BottlePoisons_" + akReference.GetFormID())
    
    If poisons != ""
        String[] poisonRefs = StringUtil.Split(poisons, ",")
        Int index = 0

        While index < poisonRefs.Length
            Form poisonForm = Game.GetFormEx(poisonRefs[index] as Int) as Form

            If ANDR_PapyrusFunctions.GetAndrealphusExtenderVersion() != 0
                ANDR_PapyrusFunctions.CastPotion(DBD_Player, poisonForm as Potion, akActor)
            Else
                akActor.EquipItem(poisonForm, False, True)
            EndIf

            index += 1
        EndWhile
    EndIf
EndFunction


; Events

Event OnInit()
    DBD_SetUp()
EndEvent


Event OnPlayerLoadGame()
    DBD_SetUp()
    RestoreBottleNames()
EndEvent


Event OnCrosshairRefChange(ObjectReference ref)
    ConsoleUtil.SetSelectedReference(ref)
    
    If ConsoleUtil.GetSelectedReference().HasKeyword(DBD_Drink)
        If StorageUtil.GetStringValue(None, "BottlePoisons_" + ConsoleUtil.GetSelectedReference().GetFormID()) != ""
            observedBottle = ConsoleUtil.GetSelectedReference()

            Float minTime = DBD_minBottleDetectionTime.GetValue()
            Float maxTime = DBD_maxBottleDetectionTime.GetValue()

            If minTime >= maxTime
                maxTime = minTime + 0.5
            EndIf

            Float DBD_BottleDetectionTime = Utility.RandomFloat(minTime, maxTime)
            RegisterForUpdate(DBD_BottleDetectionTime)
        EndIf
    EndIf
EndEvent


Event OnUpdate()
    RegisterForUpdate(5)
    Actor npc = Game.FindClosestActorFromRef(observedBottle, DBD_maxBottleDetectionRadius.GetValue())
    Actor potentialPoisoner = Game.FindClosestActorFromRef(npc, DBD_maxBottleDetectionRadius.GetValue())

    If npc && (npc != Game.GetPlayer()) && !npc.IsCommandedActor() && !npc.IsPlayerTeammate() && !npc.IsOnMount() && !npc.IsBeingRidden()
        If npc.GetSleepState() == 3
            Debug.SendAnimationEvent(npc, "IdleBedGetUp")
        ElseIf npc.GetSitState() == 3
            Debug.SendAnimationEvent(npc, "IdleChairGetUp")
        EndIf

        npc.SetLookAt(observedBottle, True)
        Utility.Wait(2)

        Debug.SendAnimationEvent(npc, "IdleActivatePickUp")

        Utility.Wait(2)
        npc.EquipItem(observedBottle.GetBaseObject())
        npc.ClearLookAt()

        If !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && (npc.GetRelationshipRank(DBD_Player) <= 0 || DBD_IsWitness(npc, observedBottle))
            npc.SendAssaultAlarm()
        ElseIf !Game.GetPlayer().IsDetectedBy(npc) && !npc.IsHostileToActor(potentialPoisoner) && Game.GetPlayer().IsDetectedBy(potentialPoisoner)
            npc.StartCombat(potentialPoisoner)
        ElseIf !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && (npc.GetRelationshipRank(DBD_Player) >= 1) && !DBD_IsWitness(npc, observedBottle)
            Int prevRelRank = npc.GetRelationshipRank(DBD_Player)
            ;The NPC will consider it an unpleasant accident, but the bad feeling will remain.
            npc.SetRelationshipRank(DBD_Player, (prevRelRank - 1))
        EndIf

        DBD_Poison(npc, observedBottle.GetBaseObject(), observedBottle)
        DBD_CleanupBottle(observedBottle)
        observedBottle.Disable()
        observedBottle.Delete()
        observedBottle = None
        UnregisterForUpdate()
    EndIf
EndEvent


Event OnKeyDown(int keyCode)
    If (keyCode == DBD_Hotkey.GetValueInt()) && !Utility.IsInMenuMode() && !UI.IsMenuOpen("Crafting Menu") && !UI.IsMenuOpen("ContainerMenu") && !UI.IsMenuOpen("MessageBoxMenu") && !UI.IsMenuOpen("InventoryMenu") && !UI.IsMenuOpen("Console") && !UI.IsMenuOpen("BarterMenu") && !UI.IsTextInputEnabled()
        ConsoleUtil.SetSelectedReference(Game.GetCurrentCrosshairRef())

        If ConsoleUtil.GetSelectedReference().HasKeyword(DBD_Drink)
            currentBottle = ConsoleUtil.GetSelectedReference()
            Int buttonIndex = SkyMessage.Show("What would you like to do?", "Poison", "Cancel", getIndex = True) as Int

            If buttonIndex == 0
                If StorageUtil.GetStringValue(None, "BottlePoisons_" + currentBottle.GetFormID()) == ""
                    currentBottleName = ""
                    currentBottleName += currentBottle.GetBaseObject().GetName()
                Else
                    currentBottleName = currentBottle.GetDisplayName()
                EndIf

                DBD_Container.Activate(DBD_Player)
            EndIf
        EndIf
    EndIf
EndEvent


Event OnContainerChangedGlobal(ObjectReference newContainer, ObjectReference oldContainer, ObjectReference itemReference, Form baseObj, int itemCount)
    If baseObj.HasKeyword(DBD_Poison) && (newContainer == DBD_Container)
        DBD_Container.RemoveItem(baseObj, itemCount, True)
    
        String currentPoisons = StorageUtil.GetStringValue(None, "BottlePoisons_" + currentBottle.GetFormID())
        StorageUtil.SetStringValue(None, "BottlePoisons_" + currentBottle.GetFormID(), "")
        String[] poisonArray = StringUtil.Split(currentPoisons, ",")
        Int currentPoisonCount = poisonArray.Length
        
        If (currentPoisonCount + itemCount) <= DBD_maxPoisonsAmount.GetValueInt()
            While itemCount > 0
                If currentPoisons != ""
                    currentPoisons += "," + baseObj.GetFormID()
                Else
                    currentPoisons = baseObj.GetFormID()
                EndIf
                itemCount -= 1
            EndWhile

            StorageUtil.SetStringValue(None, "BottlePoisons_" + currentBottle.GetFormID(), currentPoisons)
            Debug.Notification("Successfully added.")

            If currentBottleName != (currentBottle.GetBaseObject().GetName())
                currentBottleName += ", " + baseObj.GetName()
            Else
                currentBottleName += " Poisoned With " + baseObj.GetName()
            EndIf

            currentBottle.SetDisplayName(currentBottleName, True)
            StorageUtil.SetStringValue(None, "BottlePoisonsNames_" + currentBottle.GetFormID(), currentBottleName)
            AddBottleToGlobalList(currentBottle)

            Actor npc = Game.FindClosestActorFromRef(currentBottle, DBD_maxBottleDetectionRadius.GetValue())
            If npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && !npc.IsPlayerTeammate() && (npc.GetRelationshipRank(DBD_Player) <= 0)
                npc.SendAssaultAlarm()
                ;NPC removes the poisoned item just in case.
                Actor witness = Game.FindClosestActorFromRef(Game.GetPlayer(), DBD_maxBottleDetectionRadius.GetValue())
                DBD_WitnessRemoves(witness)
            ElseIf npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && (npc.IsPlayerTeammate() || (npc.GetRelationshipRank(DBD_Player) >= 1))
                DBD_AddWitness(npc, currentBottle)
            Else
                currentBottle.SendStealAlarm(DBD_Player)
                Actor witness = Game.FindClosestActorFromRef(Game.GetPlayer(), DBD_maxBottleDetectionRadius.GetValue())
                DBD_WitnessRemoves(witness)
            EndIf
        Else
            Debug.Notification("You cannot add more than " + DBD_maxPoisonsAmount.GetValueInt() + " poisons.")
            DBD_Container.RemoveItem(baseObj, itemCount, True)
            DBD_Player.AddItem(baseObj, itemCount, True)

            Actor npc = Game.FindClosestActorFromRef(currentBottle, DBD_maxBottleDetectionRadius.GetValue())
            If npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && !npc.IsPlayerTeammate() && (npc.GetRelationshipRank(DBD_Player) <= 0)
                npc.SendAssaultAlarm()
                Actor witness = Game.FindClosestActorFromRef(Game.GetPlayer(), DBD_maxBottleDetectionRadius.GetValue())
                DBD_WitnessRemoves(witness)
            ElseIf npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && (npc.IsPlayerTeammate() || (npc.GetRelationshipRank(DBD_Player) >= 1))
                DBD_AddWitness(npc, currentBottle)
            Else
                currentBottle.SendStealAlarm(DBD_Player)
                Actor witness = Game.FindClosestActorFromRef(Game.GetPlayer(), DBD_maxBottleDetectionRadius.GetValue())
                DBD_WitnessRemoves(witness)
            EndIf
        EndIf

    ElseIf !baseObj.HasKeyword(DBD_Poison) && (newContainer == DBD_Container)
        Debug.Notification("You cannot add it there.")
        DBD_Container.RemoveItem(baseObj, itemCount, True)
        DBD_Player.AddItem(baseObj, itemCount, True)

    ElseIf baseObj.HasKeyword(DBD_Drink) && (newContainer as Actor) && (newContainer != Game.GetPlayer()) && (oldContainer == Game.GetPlayer()) && (StorageUtil.GetStringValue(None, "BottlePoisons_" + currentBottle.GetFormID()) != "")
        currentActor = newContainer as Actor
        feltBottle = currentBottle
        Float minTime = DBD_minBottleDetectionTime.GetValue()
        Float maxTime = DBD_maxBottleDetectionTime.GetValue()

        If minTime >= maxTime
            maxTime = minTime + 1.0
        EndIf

        Float minInterval = (minTime * 0.1) / 600
        Float maxInterval = (maxTime * 0.1) / 600

        If minInterval >= maxInterval
            maxInterval = minInterval + 0.0001
        EndIf

        Float DBD_inventoryBottleDetectionTime = Utility.RandomFloat(minInterval, maxInterval)
        newContainer.RemoveItem(baseObj, itemCount, True)
        RegisterForSingleUpdateGameTime(DBD_inventoryBottleDetectionTime)
    EndIf
EndEvent


Event OnUpdateGameTime()
    If currentActor && (currentActor != Game.GetPlayer()) && !currentActor.IsOnMount() && !currentActor.IsBeingRidden()
        currentActor.EquipItem(feltBottle.GetBaseObject())
        
        If !currentActor.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(currentActor) && !currentActor.IsCommandedActor() && ((!currentActor.IsPlayerTeammate() && (currentActor.GetRelationshipRank(DBD_Player) <= 0)) || DBD_IsWitness(currentActor, feltBottle))
            currentActor.SendAssaultAlarm()
        ElseIf !currentActor.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(currentActor) && (currentActor.IsCommandedActor() || currentActor.IsPlayerTeammate() || (currentActor.GetRelationshipRank(DBD_Player) >= 1)) && !DBD_IsWitness(currentActor, feltBottle)
            ;The NPC may see it as an unpleasant accident, but will still be suspicious of you.
            Int prevRelRank = currentActor.GetRelationshipRank(DBD_Player)
            currentActor.SetRelationshipRank(DBD_Player, (prevRelRank - 3))
        EndIf

        DBD_Poison(currentActor, feltBottle.GetBaseObject(), feltBottle)
        DBD_CleanupBottle(feltBottle)
        feltBottle.Disable()
        feltBottle.Delete()
        currentActor = None
        feltBottle = None
    EndIf
EndEvent


Event OnObjectEquippedGlobal(Actor akActor, Form akBaseObject, ObjectReference akReference)
    If akReference.HasKeyword(DBD_Drink)
        DBD_Poison(akActor, akBaseObject, akReference)
    EndIf
EndEvent
