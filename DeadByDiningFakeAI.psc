Scriptname DeadByDiningFakeAI extends ActiveMagicEffect


Actor Property DBD_Player Auto
Keyword Property DBD_Drink Auto
Keyword Property DBD_Poison Auto
Keyword Property DBD_Humanoid Auto
Keyword Property DBD_Disallowed Auto

GlobalVariable Property DBD_falsePoisonerEnabled Auto
GlobalVariable Property DBD_maxBottleDetectionRadius Auto
GlobalVariable Property DBD_minBottleDetectionTime Auto
GlobalVariable Property DBD_maxBottleDetectionTime Auto

Actor potentialPoisoner


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


Function DBD_CleanupPickedUpBottle(ObjectReference akBottle)
    String allPickedUpBottleIDs = StorageUtil.GetStringValue(None, "DBD_PickedUpBottle")
    If allPickedUpBottleIDs == ""
        Return
    EndIf

    Int formID = akBottle.GetFormID()
    String strFormID = formID
    String[] splitted = StringUtil.Split(allPickedUpBottleIDs, ",")

    splitted = PapyrusUtil.RemoveString(splitted, strFormID)

    String newAllPickedUpBottleIDs = PapyrusUtil.StringJoin(splitted, ",")
    StorageUtil.SetStringValue(None, "DBD_PickedUpBottle", newAllPickedUpBottleIDs)
EndFunction


Function DBD_CleanupVictim(Actor akVictim, ObjectReference akBottle)
    String victimKey = "DBD_AssignedBottle" + akBottle.GetFormID()
    StorageUtil.UnsetStringValue(akVictim, victimKey)
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


Actor Function DBD_SearchVictim(ObjectReference akReference, Int akDistance)
	Cell kCell = Game.GetPlayer().GetParentCell()
	Int i = kCell.GetNumRefs(43) - 1
    Actor detectionActor = None

	While i >= 0
        detectionActor = kCell.GetNthRef(i, 43) as Actor
        Float distance = DBD_Player.GetDistance(detectionActor)
        If detectionActor && (distance < akDistance) && (detectionActor != Game.GetPlayer()) && detectionActor.HasKeyword(DBD_Humanoid) && !detectionActor.HasKeyword(DBD_Disallowed)
            If !DBD_IsWitness(detectionActor, akReference) && !detectionActor.IsCommandedActor() && !detectionActor.IsPlayerTeammate() && !detectionActor.IsDead() && !detectionActor.IsGhost() && !detectionActor.IsUnconscious()
                Return detectionActor
            EndIf
        EndIf
        i -= 1
	EndWhile
EndFunction


Function DBD_Poison(Actor akActor, ObjectReference akReference)
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


; ------------------------------------
; 3) Events
; ------------------------------------


Event OnEffectStart(Actor akTarget, Actor akCaster)
    Actor npc = akTarget
    Int bottleID = StorageUtil.GetIntValue(npc, "DBD_AssignedBottle")
    ObjectReference observedBottle = Game.GetFormEx(bottleID) as ObjectReference
    
    If !observedBottle
        DBD_CleanupVictim(npc, observedBottle)
        Dispel()
        Return
    EndIf
    

    ; Humanoid NPC
    If npc.HasKeyword(DBD_Humanoid)

        If npc.IsOnMount()
            npc.Dismount()
        EndIf

        Float minTime = DBD_minBottleDetectionTime.GetValue()
        Float maxTime = DBD_maxBottleDetectionTime.GetValue()

        If maxTime < minTime
            Float temp = minTime
            minTime = maxTime
            maxTime = temp
        EndIf

        Float DBD_bottleDetectionTime = Utility.RandomFloat(minTime, maxTime)

        Utility.Wait(DBD_bottleDetectionTime)


        ; Non-Hostile NPC Handling
        If !npc.IsInCombat()

            If npc.GetSleepState() == 3
                Debug.SendAnimationEvent(npc, "IdleBedGetUp")
                Utility.Wait(2)
            ElseIf npc.GetSitState() == 3
                Debug.SendAnimationEvent(npc, "IdleChairGetUp")
                Utility.Wait(2)
            EndIf

            npc.SetExpressionOverride(12, 65) 
            npc.SetLookAt(observedBottle, True)
            Utility.Wait(2)

            Debug.SendAnimationEvent(npc, "IdleActivatePickUp")

            Utility.Wait(2)
            npc.ClearExpressionOverride()
            npc.ClearLookAt()
            npc.EquipItem(observedBottle.GetBaseObject())


            ; Non-Friendly NPC Poisoned
            If !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && (npc.GetRelationshipRank(DBD_Player) <= 0)
                npc.SendAssaultAlarm()


            ; Friendly NPC Poisoned -- they will consider this an unpleasant accident, but the bad feeling will remain.
            ElseIf !npc.IsHostileToActor(DBD_Player) && Game.GetPlayer().IsDetectedBy(npc) && (npc.GetRelationshipRank(DBD_Player) >= 1)
                Int prevRelRank = npc.GetRelationshipRank(DBD_Player)
                npc.SetRelationshipRank(DBD_Player, (prevRelRank - 1))


            ; Potential Poisoner Search
            ElseIf (DBD_falsePoisonerEnabled.GetValue() == 1.0) && !Game.GetPlayer().IsDetectedBy(npc)
                Actor candidate = DBD_SearchVictim(observedBottle, (DBD_maxBottleDetectionRadius.GetValueInt() * 3))
                If candidate
                    potentialPoisoner = candidate
                    npc.SetRelationshipRank(potentialPoisoner, -4)
                    potentialPoisoner.SetRelationshipRank(npc, -4)
                    npc.SetAlert()
                    potentialPoisoner.SetAlert()
                    npc.StartCombat(potentialPoisoner)
                    potentialPoisoner.StartCombat(npc)
                    potentialPoisoner = None
                EndIf
            EndIf
        
        
        ; Hostile NPC Handling -- If they need to heal/get some strength during combat and didn't see your manipulations with an item.
        Else
            If (npc.GetBaseActorValue("health") > npc.GetActorValue("health")) && !DBD_IsWitness(npc, observedBottle)
                npc.SetLookAt(observedBottle, True)
                Utility.Wait(2)

                Debug.SendAnimationEvent(npc, "IdleActivatePickUp")

                Utility.Wait(2)
                npc.EquipItem(observedBottle.GetBaseObject())
                npc.ClearLookAt()
            EndIf
        EndIf
    

    ; Creature NPC -- they don't need a complex behavior.
    Else
        npc.EquipItem(observedBottle.GetBaseObject())
    EndIf

    DBD_Poison(npc, observedBottle)
    DBD_CleanupPickedUpBottle(observedBottle)
    DBD_CleanupBottle(observedBottle)
    DBD_CleanupVictim(npc, observedBottle)
    observedBottle.Disable()
    observedBottle.Delete()
    observedBottle = None
    npc = None
    Dispel()
EndEvent
