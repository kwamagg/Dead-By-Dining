Scriptname DeadByDining extends ReferenceAlias


Actor Property DBD_Player Auto
ObjectReference Property DBD_Container Auto
Faction Property Bandit Auto

Keyword Property DBD_Drink Auto
Keyword Property DBD_Poison Auto
Keyword Property DBD_Humanoid Auto
Keyword Property DBD_Disallowed Auto

GlobalVariable Property DBD_Hotkey Auto
GlobalVariable Property DBD_fakeAIEnabled Auto
GlobalVariable Property DBD_falsePoisonerEnabled Auto
GlobalVariable Property DBD_maxPoisonsAmount Auto
GlobalVariable Property DBD_maxBottleDetectionRadius Auto
GlobalVariable Property DBD_minBottleDetectionTime Auto
GlobalVariable Property DBD_maxBottleDetectionTime Auto

Actor currentActor
Actor potentialPoisoner
ObjectReference currentBottle
ObjectReference observedBottle
ObjectReference feltBottle
String currentBottleName



; System Functions

Function DBD_SetUp()
    RegisterForKey(DBD_Hotkey.GetValueInt())
    DbSkseEvents.RegisterAliasForGlobalEvent("OnContainerChangedGlobal", self)
    If (DBD_fakeAIEnabled.GetValue() == 1.0)
        RegisterForCrosshairRef()
    Else
        UnregisterForCrosshairRef()
    EndIf
EndFunction


; List Functions

Function AddBottleToGlobalList(ObjectReference akBottle)
    String allBottleIDs = StorageUtil.GetStringValue(None, "DBD_PoisonedBottleIDs")
    Int formID = akBottle.GetFormID()

    If allBottleIDs == ""
        allBottleIDs = formID
    ElseIf StringUtil.Find(allBottleIDs, formID) == -1
        allBottleIDs += "," + formID
    EndIf

    StorageUtil.SetStringValue(None, "DBD_PoisonedBottleIDs", allBottleIDs)
EndFunction


Function RestoreBottleNames()
    String allBottleIDs = StorageUtil.GetStringValue(None, "DBD_PoisonedBottleIDs")
    If allBottleIDs == ""
        Return
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
        String strFormID = akBottle.GetFormID()
        String[] splitted = StringUtil.Split(allBottleIDs, ",")

        splitted = PapyrusUtil.RemoveString(splitted, strFormID)
        String newBottleIDs = PapyrusUtil.StringJoin(splitted, ",")
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


Function DBD_WitnessRemovesThreat(Actor akWitness)
    akWitness.SetExpressionOverride(14, 65) ;Mood - disgusted
    akWitness.SetLookAt(currentBottle, True)
    Utility.Wait(2)
    Debug.SendAnimationEvent(akWitness, "IdleActivatePickUp")
    Utility.Wait(2)
    akWitness.ClearExpressionOverride()
    akWitness.ClearLookAt()
    DBD_CleanupBottle(currentBottle)
    currentBottle.Disable()
    currentBottle.Delete()
    observedBottle = None
    currentBottle = None
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
    If DBD_fakeAIEnabled.GetValue() == 0.0
        UnregisterForCrosshairRef()
        UnregisterForUpdate()
        observedBottle = None
    Else
        If ref && ref.HasKeyword(DBD_Drink)
            ConsoleUtil.SetSelectedReference(ref)
            If StorageUtil.GetStringValue(None, "BottlePoisons_" + ConsoleUtil.GetSelectedReference().GetFormID()) != ""
                observedBottle = ConsoleUtil.GetSelectedReference()

                Float minTime = DBD_minBottleDetectionTime.GetValue()
                Float maxTime = DBD_maxBottleDetectionTime.GetValue()

                If minTime >= maxTime
                    maxTime = minTime + 0.5
                EndIf

                Float DBD_BottleDetectionTime = Utility.RandomFloat(minTime, maxTime)
                UnregisterForUpdate()
                RegisterForUpdate(DBD_BottleDetectionTime)
            EndIf
        EndIf
    EndIf
EndEvent


Event OnUpdate()
    If (observedBottle == None) || (DBD_fakeAIEnabled.GetValue() == 0.0)
        UnregisterForUpdate()
    Else
        UnregisterForUpdate()
        RegisterForUpdate(5)
        Actor npc = Game.FindClosestActorFromRef(observedBottle, DBD_maxBottleDetectionRadius.GetValue())
        If (DBD_falsePoisonerEnabled.GetValue() == 1.0)
            potentialPoisoner = Game.FindClosestActorFromRef(npc, (DBD_maxBottleDetectionRadius.GetValue() * 3))
        EndIf

        If npc && (npc != Game.GetPlayer()) && !npc.IsCommandedActor() && !npc.IsPlayerTeammate() && !npc.IsBeingRidden() && !npc.IsDead() && !npc.IsGhost() && !npc.IsUnconscious() && !npc.HasKeyword(DBD_Disallowed) && !DBD_IsWitness(npc, observedBottle)
            
            If npc.IsOnMount()
                npc.Dismount()
            EndIf
            
            If npc.HasKeyword(DBD_Humanoid)

                If !npc.IsInCombat()
                    If npc.GetSleepState() == 3
                        Debug.SendAnimationEvent(npc, "IdleBedGetUp")
                    ElseIf npc.GetSitState() == 3
                        Debug.SendAnimationEvent(npc, "IdleChairGetUp")
                    EndIf

                    npc.SetExpressionOverride(12, 65) ;Mood - surprized
                    npc.SetLookAt(observedBottle, True)
                    Utility.Wait(2)

                    Debug.SendAnimationEvent(npc, "IdleActivatePickUp")

                    Utility.Wait(2)
                    npc.EquipItem(observedBottle.GetBaseObject())
                    npc.ClearExpressionOverride()
                    npc.ClearLookAt()

                    If !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && (npc.GetRelationshipRank(DBD_Player) <= 0)
                        npc.SendAssaultAlarm()
                    ElseIf !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && (npc.GetRelationshipRank(DBD_Player) >= 1)
                        Int prevRelRank = npc.GetRelationshipRank(DBD_Player)
                        ;The NPC will consider this an unpleasant accident, but the bad feeling will remain.
                        npc.SetRelationshipRank(DBD_Player, (prevRelRank - 1))
                    ElseIf (DBD_falsePoisonerEnabled.GetValue() == 1.0) && !Game.GetPlayer().IsDetectedBy(npc) && potentialPoisoner && (potentialPoisoner != Game.GetPlayer()) && potentialPoisoner.HasKeyword(DBD_Humanoid) && !potentialPoisoner.IsDead() && !potentialPoisoner.IsGhost() && !potentialPoisoner.IsUnconscious() && !potentialPoisoner.HasKeyword(DBD_Disallowed) && !potentialPoisoner.IsBeingRidden()
                        npc.SetRelationshipRank(potentialPoisoner, -4)
                        potentialPoisoner.SetRelationshipRank(npc, -4)
                        npc.SetAlert()
                        potentialPoisoner.SetAlert()
                        npc.StartCombat(potentialPoisoner)
                        potentialPoisoner.StartCombat(npc)
                        potentialPoisoner = None
                    EndIf
                
                Else
                    ;The NPC needs to heal/get some strength and didn't see your manipulations with an item.
                    If (npc.GetBaseActorValue("health") > npc.GetActorValue("health")) && !DBD_IsWitness(npc, observedBottle)
                        npc.SetLookAt(observedBottle, True)
                        Utility.Wait(2)

                        Debug.SendAnimationEvent(npc, "IdleActivatePickUp")

                        Utility.Wait(2)
                        npc.EquipItem(observedBottle.GetBaseObject())
                        npc.ClearLookAt()
                    EndIf
                EndIf
            Else
                ;Creature NPCs don't need a complex behavior.
                npc.EquipItem(observedBottle.GetBaseObject())
            EndIf

            DBD_Poison(npc, observedBottle.GetBaseObject(), observedBottle)
            DBD_CleanupBottle(observedBottle)
            observedBottle.Disable()
            observedBottle.Delete()
            observedBottle = None
            UnregisterForUpdate()
        EndIf
    EndIf
EndEvent


Event OnKeyDown(int keyCode)
    If (keyCode == DBD_Hotkey.GetValueInt()) && !Utility.IsInMenuMode() && !UI.IsMenuOpen("Crafting Menu") && !UI.IsMenuOpen("ContainerMenu") && !UI.IsMenuOpen("MessageBoxMenu") && !UI.IsMenuOpen("Console") && !UI.IsMenuOpen("BarterMenu") && !UI.IsTextInputEnabled() && !UI.IsMenuOpen("InventoryMenu")
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
                currentBottleName += ", Poisoned With " + baseObj.GetName()
            EndIf

            currentBottle.SetDisplayName(currentBottleName, True)
            StorageUtil.SetStringValue(None, "BottlePoisonsNames_" + currentBottle.GetFormID(), currentBottleName)
            AddBottleToGlobalList(currentBottle)

            Actor npc = Game.FindClosestActorFromRef(currentBottle, DBD_maxBottleDetectionRadius.GetValue())
            If npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && (npc.IsPlayerTeammate() || (npc.GetRelationshipRank(DBD_Player) >= 1)) && npc.HasKeyword(DBD_Humanoid) && !npc.IsDead() && !npc.IsGhost() && !npc.IsUnconscious() && !npc.IsBeingRidden() && !npc.HasKeyword(DBD_Disallowed)
                DBD_AddWitness(npc, currentBottle)

            ElseIf npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && !npc.IsPlayerTeammate() && (npc.GetRelationshipRank(DBD_Player) <= 0) && npc.HasKeyword(DBD_Humanoid) && !npc.IsDead() && !npc.IsGhost() && !npc.IsUnconscious() && !npc.IsBeingRidden() && !npc.HasKeyword(DBD_Disallowed)
                npc.SendAssaultAlarm()
                DBD_AddWitness(npc, currentBottle)
                Actor witness = Game.FindClosestActorFromRef(Game.GetPlayer(), DBD_maxBottleDetectionRadius.GetValue())
                DBD_WitnessRemovesThreat(witness)

            ElseIf npc && Game.GetPlayer().IsDetectedBy(npc) && npc.HasKeyword(DBD_Humanoid) && !npc.IsDead() && !npc.IsGhost() && !npc.IsUnconscious() && !npc.IsBeingRidden() && !npc.HasKeyword(DBD_Disallowed) && npc.IsInCombat()
                ;The NPC sees that you're poisoning something during the battle.
                DBD_AddWitness(npc, currentBottle)
            EndIf
        Else
            Debug.Notification("You cannot add more than " + DBD_maxPoisonsAmount.GetValueInt() + " poisons.")
            DBD_Container.RemoveItem(baseObj, itemCount, True)
            DBD_Player.AddItem(baseObj, itemCount, True)

            Actor npc = Game.FindClosestActorFromRef(currentBottle, DBD_maxBottleDetectionRadius.GetValue())
            If npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && (npc.IsPlayerTeammate() || (npc.GetRelationshipRank(DBD_Player) >= 1)) && npc.HasKeyword(DBD_Humanoid) && !npc.IsDead() && !npc.IsGhost() && !npc.IsUnconscious() && !npc.IsBeingRidden() && !npc.HasKeyword(DBD_Disallowed)
                DBD_AddWitness(npc, currentBottle)

            ElseIf npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && !npc.IsCommandedActor() && !npc.IsPlayerTeammate() && (npc.GetRelationshipRank(DBD_Player) <= 0) && npc.HasKeyword(DBD_Humanoid) && !npc.IsDead() && !npc.IsGhost() && !npc.IsUnconscious() && !npc.IsBeingRidden() && !npc.HasKeyword(DBD_Disallowed)
                npc.SendAssaultAlarm()
                DBD_AddWitness(npc, currentBottle)
                Actor witness = Game.FindClosestActorFromRef(Game.GetPlayer(), DBD_maxBottleDetectionRadius.GetValue())
                DBD_WitnessRemovesThreat(witness)
            
            ElseIf npc && Game.GetPlayer().IsDetectedBy(npc) && npc.HasKeyword(DBD_Humanoid) && !npc.IsDead() && !npc.IsGhost() && !npc.IsUnconscious() && !npc.IsBeingRidden() && !npc.HasKeyword(DBD_Disallowed) && npc.IsInCombat()
                DBD_AddWitness(npc, currentBottle)
            EndIf
        EndIf

    ElseIf !baseObj.HasKeyword(DBD_Poison) && (newContainer == DBD_Container)
        Debug.Notification("You cannot add it there.")
        DBD_Container.RemoveItem(baseObj, itemCount, True)
        DBD_Player.AddItem(baseObj, itemCount, True)

    ElseIf (newContainer != None) && baseObj.HasKeyword(DBD_Drink) && (newContainer as Actor) && (newContainer != Game.GetPlayer()) && (oldContainer == Game.GetPlayer()) && (StorageUtil.GetStringValue(None, "BottlePoisons_" + currentBottle.GetFormID()) != "") && !(newContainer as Actor).IsDead() && !(newContainer as Actor).IsGhost()
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
    If currentActor && (currentActor != Game.GetPlayer())
        If (DBD_falsePoisonerEnabled.GetValue() == 1.0)
            potentialPoisoner = Game.FindClosestActorFromRef(currentActor, (DBD_maxBottleDetectionRadius.GetValue() * 3))
        EndIf
        currentActor.EquipItem(feltBottle.GetBaseObject())
        
        If !currentActor.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(currentActor) && !currentActor.IsCommandedActor() && ((!currentActor.IsPlayerTeammate() && (currentActor.GetRelationshipRank(DBD_Player) <= 0)) || DBD_IsWitness(currentActor, feltBottle)) && !currentActor.IsUnconscious() && currentActor.HasKeyword(DBD_Humanoid) && !currentActor.HasKeyword(DBD_Disallowed)
            currentActor.SendAssaultAlarm()
        ElseIf !currentActor.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(currentActor) && (currentActor.IsCommandedActor() || currentActor.IsPlayerTeammate() || (currentActor.GetRelationshipRank(DBD_Player) >= 1)) && !DBD_IsWitness(currentActor, feltBottle) && !currentActor.IsUnconscious() && currentActor.HasKeyword(DBD_Humanoid) && !currentActor.HasKeyword(DBD_Disallowed)
            ;The NPC may see this as an unpleasant accident, but will still be suspicious of you.
            Int prevRelRank = currentActor.GetRelationshipRank(DBD_Player)
            currentActor.SetRelationshipRank(DBD_Player, (prevRelRank - 3))
        ElseIf (DBD_falsePoisonerEnabled.GetValue() == 1.0) && !Game.GetPlayer().IsDetectedBy(currentActor) && potentialPoisoner && (potentialPoisoner != Game.GetPlayer()) && potentialPoisoner.HasKeyword(DBD_Humanoid) && !potentialPoisoner.IsDead() && !potentialPoisoner.IsGhost() && !potentialPoisoner.IsUnconscious() && !potentialPoisoner.HasKeyword(DBD_Disallowed) && !potentialPoisoner.IsBeingRidden()
            currentActor.SetRelationshipRank(potentialPoisoner, -4)
            potentialPoisoner.SetRelationshipRank(currentActor, -4)
            currentActor.SetAlert()
            potentialPoisoner.SetAlert()
            currentActor.StartCombat(potentialPoisoner)
            potentialPoisoner.StartCombat(currentActor)
            potentialPoisoner = None
        EndIf

        DBD_Poison(currentActor, feltBottle.GetBaseObject(), feltBottle)
        DBD_CleanupBottle(feltBottle)
        feltBottle.Disable()
        feltBottle.Delete()
        currentActor = None
        feltBottle = None
    EndIf
EndEvent


Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)
    If akReference.HasKeyword(DBD_Drink) && (StorageUtil.GetStringValue(None, "BottlePoisons_" + akReference.GetFormID()) != "")
        DBD_Poison(Game.GetPlayer(), akBaseObject, akReference)
        DBD_CleanupBottle(akReference)
    EndIf
EndEvent
