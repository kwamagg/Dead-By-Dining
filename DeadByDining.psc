Scriptname DeadByDining extends ReferenceAlias

Actor Property DBD_Player Auto
ObjectReference Property DBD_Container Auto

Keyword Property DBD_Drink Auto
Keyword Property DBD_Poison Auto

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
    PO3_Events_Alias.RegisterForObjectGrab(self)
    DbSkseEvents.RegisterAliasForGlobalEvent("OnContainerChangedGlobal", self)
    DbSkseEvents.RegisterAliasForGlobalEvent("OnObjectEquippedGlobal", self)
    String iniPath = "Data/DeadByDiningSaves/" + DBD_Player.GetDisplayName() + "_DeadByDining.ini"

    If !MiscUtil.FileExists(iniPath)
        MiscUtil.WriteToFile(iniPath, "[BottlePoisons]")
    EndIf

    RegisterForCrosshairRef()
EndFunction


Function DBD_Poison(Actor akActor, Form akBaseObject, ObjectReference akReference)
    String iniPath = "Data/DeadByDiningSaves/" + DBD_Player.GetDisplayName() + "_DeadByDining.ini"
    String poisons = DbIniFunctions.GetIniString(iniPath, "BottlePoisons", akReference.GetFormID(), "")

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

            If (akActor != Game.GetPlayer()) && (poisonForm as Potion).IsPoison()
                If !akActor.IsHostileToActor(DBD_Player)
                    akActor.SendAssaultAlarm()
                EndIf
            EndIf
            index += 1
        EndWhile
    EndIf
EndFunction


Event OnCrosshairRefChange(ObjectReference ref)
    String iniPath = "Data/DeadByDiningSaves/" + DBD_Player.GetDisplayName() + "_DeadByDining.ini"

    ;A workaround for that a bottle ref differs from its actual one upon hovering the crosshair.
    ConsoleUtil.SetSelectedReference(ref)

    If ConsoleUtil.GetSelectedReference().HasKeyword(DBD_Drink)
        observedBottle = ConsoleUtil.GetSelectedReference()

        Float minTime = DBD_minBottleDetectionTime.GetValue()
        Float maxTime = DBD_maxBottleDetectionTime.GetValue()

        If minTime >= maxTime
            maxTime = minTime + 0.5
        EndIf

        Float DBD_BottleDetectionTime = Utility.RandomFloat(minTime, maxTime)
        RegisterForSingleUpdate(DBD_bottleDetectionTime)
    EndIf
EndEvent


Event OnUpdate()
    Actor npc = Game.FindClosestActorFromRef(observedBottle, DBD_maxBottleDetectionRadius.GetValue())
    If npc && (npc != Game.GetPlayer())
        Debug.SendAnimationEvent(npc, "IdleActivatePickUp")
        Utility.Wait(2)
        DBD_Poison(npc, observedBottle.GetBaseObject(), observedBottle)
        npc.EquipItem(observedBottle.GetBaseObject())
        observedBottle.Disable()
        observedBottle.Delete()
        observedBottle = None
    EndIf
EndEvent


Event OnObjectGrab(ObjectReference akObjectRef)
    currentBottle = akObjectRef
    If currentBottle.HasKeyword(DBD_Drink) && DBD_Player.IsSneaking()
        Int buttonIndex = SkyMessage.Show("What would you like to do?", "Spike", "Cancel", getIndex = True) as Int
        If buttonIndex == 0
            currentBottleName = ""
            currentBottleName += currentBottle.GetBaseObject().GetName() + " Spiked With "
            DBD_Container.Activate(DBD_Player)
        EndIf
    EndIf
EndEvent


Event OnContainerChangedGlobal(ObjectReference newContainer, ObjectReference oldContainer, ObjectReference itemReference, Form baseObj, int itemCount)
    If baseObj.HasKeyword(DBD_Poison) && (newContainer == DBD_Container)

        DBD_Container.RemoveItem(baseObj, itemCount, True)

        String iniPath = "Data/DeadByDiningSaves/" + DBD_Player.GetDisplayName() + "_DeadByDining.ini"
        String currentPoisons = DbIniFunctions.GetIniString(iniPath, "BottlePoisons", currentBottle.GetFormID(), "")
        DbIniFunctions.SetIniString(iniPath, "BottlePoisons", currentBottle.GetFormID(), "", True)
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
            DbIniFunctions.SetIniString(iniPath, "BottlePoisons", currentBottle.GetFormID(), currentPoisons, True)
            Debug.Notification("Successfully added.")
        Else
            Debug.Notification("You cannot add more than " + DBD_maxPoisonsAmount.GetValueInt() + " poisons.")
            DBD_Container.RemoveItem(baseObj, itemCount, True)
            DBD_Player.AddItem(baseObj, itemCount, True)
        EndIf

        If currentBottleName != (currentBottle.GetBaseObject().GetName() + " Spiked With ")
            currentBottleName += ", " + baseObj.GetName()
        Else
            currentBottleName += baseObj.GetName()
        EndIf
        currentBottle.SetDisplayName(currentBottleName, True)
    
    ElseIf !baseObj.HasKeyword(DBD_Poison) && (newContainer == DBD_Container)
        Debug.Notification("You cannot add it there.")
        DBD_Container.RemoveItem(baseObj, itemCount, True)
        DBD_Player.AddItem(baseObj, itemCount, True)

    ElseIf baseObj.HasKeyword(DBD_Drink) && (newContainer as Actor) && (newContainer != Game.GetPlayer()) && (oldContainer == Game.GetPlayer())
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
        currentActor = None
        feltBottle = None
    EndIf
EndEvent


Event OnObjectEquippedGlobal(Actor akActor, Form akBaseObject, ObjectReference akReference)
    If akReference.HasKeyword(DBD_Drink)
        DBD_Poison(akActor, akBaseObject, akReference)
    EndIf
EndEvent
