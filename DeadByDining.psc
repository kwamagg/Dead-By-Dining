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


Event OnInit()
    DBD_SetUp()
EndEvent


Event OnPlayerLoadGame()
    DBD_SetUp()
EndEvent


Function DBD_SetUp()
    RegisterForKey(DBD_Hotkey.GetValueInt())
    DbSkseEvents.RegisterAliasForGlobalEvent("OnContainerChangedGlobal", self)
    DbSkseEvents.RegisterAliasForGlobalEvent("OnObjectEquippedGlobal", self)
    RegisterForCrosshairRef()
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


Event OnCrosshairRefChange(ObjectReference ref)
    ;A workaround for that a bottle ref differs from its actual one upon hovering the crosshair.
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
    If npc && (npc != Game.GetPlayer())
        If npc.GetSleepState() == 3
            Debug.SendAnimationEvent(npc, "IdleBedGetUp")
        ElseIf npc.GetSitState() == 3
            Debug.SendAnimationEvent(npc, "IdleChairGetUp")
        EndIf

        Debug.SendAnimationEvent(npc, "IdleActivatePickUp")
        Utility.Wait(2)

        DBD_Poison(npc, observedBottle.GetBaseObject(), observedBottle)
        npc.EquipItem(observedBottle.GetBaseObject())
        observedBottle.Disable()
        observedBottle.Delete()
        observedBottle = None

        If !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc)
            npc.SendAssaultAlarm()
        EndIf

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
                    currentBottleName += currentBottle.GetBaseObject().GetName() + " Poisoned With "
                Else
                    currentBottleName = currentBottle.GetDisplayName()
                EndIf

                Actor npc = Game.FindClosestActorFromRef(currentBottle, DBD_maxBottleDetectionRadius.GetValue())
                If npc && !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc)
                    npc.SendAssaultAlarm()
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

            If currentBottleName != (currentBottle.GetBaseObject().GetName() + " Poisoned With ")
                currentBottleName += ", " + baseObj.GetName()
            Else
                currentBottleName += baseObj.GetName()
            EndIf

            currentBottle.SetDisplayName(currentBottleName, True)
            currentBottle.SendStealAlarm(DBD_Player)
        Else
            Debug.Notification("You cannot add more than " + DBD_maxPoisonsAmount.GetValueInt() + " poisons.")
            DBD_Container.RemoveItem(baseObj, itemCount, True)
            DBD_Player.AddItem(baseObj, itemCount, True)
            currentBottle.SendStealAlarm(DBD_Player)
        EndIf

    ElseIf !baseObj.HasKeyword(DBD_Poison) && (newContainer == DBD_Container)
        Debug.Notification("You cannot add it there.")
        DBD_Container.RemoveItem(baseObj, itemCount, True)
        DBD_Player.AddItem(baseObj, itemCount, True)

    ElseIf baseObj.HasKeyword(DBD_Drink) && (newContainer as Actor) && (newContainer != Game.GetPlayer()) && (oldContainer == Game.GetPlayer()) && (StorageUtil.GetStringValue(None, "BottlePoisons_" + itemReference.GetFormID()) != "")
        currentActor = newContainer as Actor
        feltBottle = itemReference
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
        DBD_Poison(currentActor, feltBottle.GetBaseObject(), feltBottle)
        currentActor.EquipItem(feltBottle.GetBaseObject())
        feltBottle.Disable()
        feltBottle.Delete()

        If !currentActor.IsHostileToActor(DBD_Player)
            currentActor.SendAssaultAlarm()
        EndIf

        currentActor = None
        feltBottle = None
    EndIf
EndEvent


Event OnObjectEquippedGlobal(Actor akActor, Form akBaseObject, ObjectReference akReference)
    If akReference.HasKeyword(DBD_Drink)
        DBD_Poison(akActor, akBaseObject, akReference)
    EndIf
EndEvent
