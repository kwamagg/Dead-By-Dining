Scriptname DeadByDining extends ReferenceAlias


Actor Property DBD_Player Auto
ObjectReference Property DBD_Container Auto

Keyword Property DBD_Drink Auto
Keyword Property DBD_Disallowed Auto

GlobalVariable Property DBD_Hotkey Auto
GlobalVariable Property DBD_uninstallEnabled Auto

Actor currentActor
Actor potentialPoisoner
ObjectReference currentBottle
ObjectReference feltBottle


; ------------------------------------
; 1) System Functions
; ------------------------------------


Function DBD_Uninstall()
    String poisonKey = "BottlePoisons_"
    String witnessesKey = "BottlePoisonsWitnesses_"
    String namesKey = "BottlePoisonsNames_"
    String refsKey = "DBD_PoisonedBottleIDs"
    String victimKey = "DBD_AssignedBottle"
    String pickedUpKey = "DBD_PickedUpBottle"
    
    StorageUtil.ClearStringValuePrefix(poisonKey)
    StorageUtil.ClearStringValuePrefix(witnessesKey)
    StorageUtil.ClearStringValuePrefix(namesKey)
    StorageUtil.ClearStringValuePrefix(refsKey)
    StorageUtil.ClearIntValuePrefix(victimKey)
    StorageUtil.ClearStringValuePrefix(pickedUpKey)

    UnregisterForAllKeys()
    UnregisterForUpdate()

    currentActor = None
    potentialPoisoner = None
    currentBottle = None
    feltBottle = None
EndFunction


; ------------------------------------
; 2) List Functions
; ------------------------------------


Function DBD_RestoreBottleNames()
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
; 3) Events
; ------------------------------------


Event OnInit()
    RegisterForKey(DBD_Hotkey.GetValueInt())
EndEvent


Event OnPlayerLoadGame()
    If DBD_uninstallEnabled.GetValue() == 1.0
        DBD_Uninstall()
    EndIf
    RegisterForKey(DBD_Hotkey.GetValueInt())
    DBD_RestoreBottleNames()
EndEvent


Event OnKeyDown(int keyCode)

    ; Poisoning Messagebox
    If (keyCode == DBD_Hotkey.GetValueInt()) && !Utility.IsInMenuMode() && !UI.IsMenuOpen("Crafting Menu") && !UI.IsMenuOpen("ContainerMenu") && !UI.IsMenuOpen("MessageBoxMenu") && !UI.IsMenuOpen("Console") && !UI.IsMenuOpen("BarterMenu") && !UI.IsTextInputEnabled() && !UI.IsMenuOpen("InventoryMenu")
        ConsoleUtil.SetSelectedReference(Game.GetCurrentCrosshairRef())

        If ConsoleUtil.GetSelectedReference().HasKeyword(DBD_Drink)
            currentBottle = ConsoleUtil.GetSelectedReference()
            Int buttonIndex = SkyMessage.Show("What would you like to do?", "Poison", "Cancel", getIndex = True) as Int

            If buttonIndex == 0
                StorageUtil.SetIntValue(None, "DBD_TempSelectedBottle", currentBottle.GetFormID())
                DBD_Container.Activate(DBD_Player)
            EndIf
        EndIf
    EndIf

EndEvent
