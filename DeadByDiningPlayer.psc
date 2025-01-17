Scriptname DeadByDiningPlayer extends ReferenceAlias


Actor Property DBD_Player Auto

Keyword Property DBD_Drink Auto
Keyword Property DBD_Humanoid Auto
Keyword Property DBD_Disallowed Auto

GlobalVariable Property DBD_falsePoisonerEnabled Auto
GlobalVariable Property DBD_maxBottleDetectionRadius Auto
GlobalVariable Property DBD_minBottleDetectionTime Auto
GlobalVariable Property DBD_maxBottleDetectionTime Auto

Actor currentActor
Actor potentialPoisoner
ObjectReference currentBottle
ObjectReference feltBottle

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


Function DBD_AddPickedUpBottle(ObjectReference akBottle)
    String allPickedUpBottleIDs = StorageUtil.GetStringValue(None, "DBD_PickedUpBottle")
    Int formID = akBottle.GetFormID()

    If allPickedUpBottleIDs == ""
        allPickedUpBottleIDs = formID
    Else
        If StringUtil.Find(allPickedUpBottleIDs, formID) == -1
            allPickedUpBottleIDs += "," + formID
        EndIf
    EndIf

    StorageUtil.SetStringValue(None, "DBD_PickedUpBottle", allPickedUpBottleIDs)
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
; 2) Events
; ------------------------------------


Event OnObjectEquipped(Form akBaseObject, ObjectReference akReference)

    ; Self-Poisoning 
    If akBaseObject.HasKeyword(DBD_Drink) && (StorageUtil.GetStringValue(None, "BottlePoisons_" + akReference.GetFormID()) != "")
        DBD_Poison(Game.GetPlayer(), akReference)
        DBD_CleanupPickedUpBottle(akReference)
        DBD_CleanupBottle(akReference)
    EndIf

EndEvent


Event OnItemAdded(Form akBaseItem, int aiItemCount, ObjectReference akItemRef, ObjectReference akSourceContainer)

    ; Fake AI Helper -- NPC will stop searching for the item that was picked up.
    If akBaseItem.HasKeyword(DBD_Drink) && (StorageUtil.GetStringValue(None, "BottlePoisons_" + akItemRef.GetFormID()) != "")
        DBD_AddPickedUpBottle(akItemRef)
    EndIf
EndEvent


Event OnItemRemoved(Form akBaseItem, int aiItemCount, ObjectReference akItemReference, ObjectReference akDestContainer)

    ; Item Planting
    If akBaseItem.HasKeyword(DBD_Drink) && (akDestContainer as Actor) && akDestContainer.HasKeyword(DBD_Humanoid) && !akDestContainer.HasKeyword(DBD_Disallowed) && !(akDestContainer as Actor).IsDead() && !(akDestContainer as Actor).IsGhost()
        currentActor = akDestContainer as Actor
        feltBottle = akItemReference

        Float minTime = DBD_minBottleDetectionTime.GetValue()
        Float maxTime = DBD_maxBottleDetectionTime.GetValue()

        If maxTime < minTime
            Float temp = minTime
            minTime = maxTime
            maxTime = temp
        EndIf

        Float DBD_inventoryBottleDetectionTime = Utility.RandomFloat(minTime, maxTime)
        akDestContainer.RemoveItem(akBaseItem, aiItemCount, True)
        DBD_CleanupPickedUpBottle(feltBottle)
        RegisterForSingleUpdate(DBD_inventoryBottleDetectionTime)
        Return


    ; Fake AI Helper -- NPC can search for the item again.
    ElseIf akBaseItem.HasKeyword(DBD_Drink) && (StorageUtil.GetStringValue(None, "BottlePoisons_" + akItemReference.GetFormID()) != "")
        DBD_CleanupPickedUpBottle(akItemReference)
        Return
    EndIf
EndEvent


Event OnUpdate()
    currentActor.EquipItem(feltBottle.GetBaseObject())
    
    ; To allow non-poisoned food to be shared without consequences.
    If (StorageUtil.GetStringValue(None, "BottlePoisons_" + feltBottle.GetFormID()) != "")


        ; Non-Friendly NPC Poisoned
        If Game.GetPlayer().IsDetectedBy(currentActor) && !currentActor.IsHostileToActor(DBD_Player) && !currentActor.IsCommandedActor() && ((!currentActor.IsPlayerTeammate() && (currentActor.GetRelationshipRank(DBD_Player) <= 0)) || DBD_IsWitness(currentActor, feltBottle)) && !currentActor.IsUnconscious()
            currentActor.SendAssaultAlarm()


        ; Friendly NPC Poisoned -- they may see this as an unpleasant accident, but will still be suspicious of you.
        ElseIf Game.GetPlayer().IsDetectedBy(currentActor) && !currentActor.IsHostileToActor(DBD_Player) && (currentActor.IsCommandedActor() || currentActor.IsPlayerTeammate() || (currentActor.GetRelationshipRank(DBD_Player) >= 1)) && !DBD_IsWitness(currentActor, feltBottle) && !currentActor.IsUnconscious()
            Int prevRelRank = currentActor.GetRelationshipRank(DBD_Player)
            currentActor.SetRelationshipRank(DBD_Player, (prevRelRank - 3))
        EndIf


        ; Potential Poisoner Search
        If (DBD_falsePoisonerEnabled.GetValue() == 1.0) && !Game.GetPlayer().IsDetectedBy(currentActor)
            Actor candidate = DBD_SearchVictim(feltBottle, (DBD_maxBottleDetectionRadius.GetValueInt() * 3))
            If candidate
                potentialPoisoner = candidate
                currentActor.SetRelationshipRank(potentialPoisoner, -4)
                potentialPoisoner.SetRelationshipRank(currentActor, -4)
                currentActor.SetAlert()
                potentialPoisoner.SetAlert()
                currentActor.StartCombat(potentialPoisoner)
                potentialPoisoner.StartCombat(currentActor)
                potentialPoisoner = None
            EndIf
        EndIf
    EndIf

    DBD_Poison(currentActor, feltBottle)
    DBD_CleanupBottle(feltBottle)
    feltBottle.Disable()
    feltBottle.Delete()
    currentActor = None
    feltBottle = None
EndEvent
