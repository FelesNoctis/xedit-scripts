{
	Persistentify Those Plugins
	v0.9.06
	
	This script targets all relevant reference types that may need to be updated
	(currently ACHR/REFR/PHZD), but also uses a number of filters to cut out every
	false positive it can concievably target without live human intervention. This
	list of filters continues to grow as we discover more edge cases in the various
	mods we test.

	See "USER SETTINGS" section below for configuration options.


	 -= CREDITS =-

	FelesNoctis---- https://www.nexusmods.com/users/336042
					Framework, basic implementation of ACHR handling, logging and
					cleanup

	Eddoursul------ https://eddoursul.win/
					Overhaul of functionality to include all important reference
					types, CK behavior research, and filter implementation

	Robertgk2017, JonathanOstrus, Zilav
					Critique of filters and optimization suggestions, extensive
					testing and suggestions, general moral boosting
}

unit Persistentify_Those_Plugins;

// ---------------------------
// ------ USER SETTINGS ------
// ---------------------------
const
	esmify = false;
	
	// CAUTION: Developer toggle
	// This disables all changes and enables debug messages
	devTest = true;
	devTestPrintAllCounted = false;





// ---------------------------
// DO NOT EDIT BELOW THIS LINE
// ---------------------------
const
	// Global Const Strings
	sLineBreak = #13#10;
	// Global Const Markers
	beth_PrisonMarker = $4;
	beth_DivineMarker = $5;
	beth_TempleMarker = $6;
	beth_MapMarker = $10;
	beth_HorseMarker = $12;
	beth_MultiBoundMarker = $15;
	beth_RoomMarker = $1F;
	beth_XMarkerHeading = $34;
	beth_XMarker = $3B;
	beth_DragonMarker = $138C0;
	beth_DragonMarkerCrashStrip = $3DF55;

var
	// Global Booleans
	announcedPlugin, hasTrappedNPC : boolean;
	// Global Integers
	recordsCounted, trappedCount : integer;
	
function Initialize: integer;
begin
	// Global Booleans
	announcedPlugin := false;
	// Global Integers
	recordsCounted := 0;
	trappedCount := 0;
	// Exit safety
	Result := 0;
end;

function IsReferencedByNonLocation(plugin_currentRef: IwbMainRecord): boolean;
var
	// Forms
	plugin_masterRecord, plugin_reference : IwbMainRecord;
	// Integers
	i : integer;
	// Strings
	plugin_nonLocRefSignature, beth_invalidSignatures : string;
begin
	Result := False;
	plugin_masterRecord := MasterOrSelf(plugin_currentRef);
	beth_invalidSignatures := 'LCTN,WRLD,TES4';

	for i := 0 to Pred(ReferencedByCount(plugin_masterRecord)) do begin
		plugin_reference := ReferencedByIndex(plugin_masterRecord, i);
		plugin_nonLocRefSignature := Signature(plugin_reference);
		
		// Locational links are bi-directional, this script does not process them. To fix them, resave plugin in CK.
		// WRLD records may refer to REFRs if they are large references. This does not imply necessity of the persistence flag.
		// TES4 may refer to REFRs if they are listed in ONAM. To keep ONAM up to date, enable "Always save ONAM" in xEdit.

		// if ((Signature(plugin_reference) <> 'LCTN') and (Signature(plugin_reference) <> 'WRLD') and (Signature(plugin_reference) <> 'TES4')) then begin
		if (Pos(plugin_nonLocRefSignature, beth_invalidSignatures) = 0)
		then begin
		
			// Do not consider unused formlist a reference
			if	(plugin_nonLocRefSignature = 'FLST')
				and (ReferencedByCount(plugin_reference) = 0)
			then
				Continue;
			
			// Only check plugins higher in the load order. Other possible options: a) check all remaining plugins too, b) check only masters
			// FELIS:	Per Jonathan, this may be flawed processing logic due to more *very* broken edge cases that we could potentially fix just by accident without this check
			//			This will probably be given it's own toggle to allow for scanning all plugins regardless of masters.
			if GetLoadOrder(GetFile(plugin_reference)) <= GetLoadOrder(GetFile(plugin_currentRef)) then begin			
				// Refs referencing themselves do not require the flag
				if not (Equals(plugin_currentRef, plugin_reference))
				then begin
					Result := True;
					Exit;
				end;
			end;
		end;	 
	end;
end;

// This is the old function, replaced by the one above written by Eddoursul
// function IsReferencedByQuest(plugin_currentBase: IwbMainRecord): boolean;
// var
// 	// Forms
// 	plugin_masterRecord : IwbMainRecord;
// 	plugin_reference	: IwbMainRecord;
// 	// Integers
// 	i : integer;

// begin
// 	Result := False;
// 	plugin_masterRecord := MasterOrSelf(plugin_currentBase);

// 	for i := 0 to Pred(ReferencedByCount(plugin_masterRecord))
// 	do begin
// 		plugin_reference := ReferencedByIndex(plugin_masterRecord, i);
// 		if Signature(plugin_reference) = 'QUST'
// 		then begin
// 			Result := True;
// 			Exit;
// 		end;	 
// 	end;
// end;

function IsWater(plugin_currentBase: IwbMainRecord): boolean;
begin
	Result := (Signature(plugin_currentBase) = 'ACTI') and ElementExists(plugin_currentBase, 'WNAM');
end;

function Process(e: IInterface): integer;
var
	// Files
	plugin_currentPlugin : IwbFile;
	// Forms
	plugin_baseRecord, plugin_currentRecord, plugin_package, plugin_packageCell : IwbMainRecord;
	// Integers
	i, shared_baseID, plugin_packageCount : integer;
	// Strings
	plugin_refSignature, beth_validSignatures, plugin_packageLoc : string;

begin
	// What plugin are we working on?
	plugin_currentPlugin := getFile(e);
	
	if (not announcedPlugin)
	then begin
		AddMessage(sLineBreak + '* Plugin: ' + Name(plugin_currentPlugin));
		announcedPlugin := true;
	end;

	//
	// SECTION 1
	// This section checks record data other than the FormID and makes the changes
	//
	if (GetLoadOrderFormID(e) > 0)
	then begin
		// Human-readable variable names are good
		plugin_currentRecord := e;
		plugin_baseRecord := BaseRecord(plugin_currentRecord);
		plugin_refSignature := Signature(plugin_currentRecord);
		beth_validSignatures := 'REFR,ACHR,PHZD';

		// Is this record a reference? If not, move on.
		// if	(Signature(plugin_currentRecord) <> 'REFR')
		// 	and (Signature(plugin_currentRecord) <> 'ACHR')
		// 	and (Signature(plugin_currentRecord) <> 'PHZD')
		// then
		if (Pos(plugin_refSignature, beth_validSignatures) = 0) then
			Exit;

		// Does this have a base record? It better have a base record. Otherwise WTH?		
		if (not Assigned(plugin_baseRecord))
		then begin
			// Placeholder: Explicit log warning here
			// This warning has no toggle, as it's a NULL Base CTD
			// ** Implement counter specifically for critical errors? **
			Exit;
		end;

		// Already persistent? Nothing to do here. Move along.
		if (GetIsPersistent(plugin_currentRecord)) then
			Exit;

		// This is indeed a record we wish to check for processing, so +1
		Inc(recordsCounted);

		// Depending on settings, we may want to log all records counted regardless of processing
		if	(devTest)
			and (devTestPrintAllCounted)
		then begin
			AddMessage(Format(
				'(DEV MODE) !  GetLoadOrderFormID(e) = %s', [ShortName(plugin_currentRecord)]));
		end;

		// Special handling for what we believe to be references that the CK will always flag
		shared_baseID := FormID(plugin_baseRecord);
		if	(IsWater(plugin_baseRecord))
			or (Signature(plugin_baseRecord) = 'TXST')
			or (shared_baseID = beth_PrisonMarker)
			or (shared_baseID = beth_DivineMarker)
			or (shared_baseID = beth_TempleMarker)
			or (shared_baseID = beth_MapMarker)
			or (shared_baseID = beth_HorseMarker)
			or (shared_baseID = beth_MultiBoundMarker)
			or (shared_baseID = beth_RoomMarker)
			or (shared_baseID = beth_XMarkerHeading)
			or (shared_baseID = beth_XMarker)
			or (shared_baseID = beth_DragonMarker)
			or (shared_baseID = beth_DragonMarkerCrashStrip)
		then begin
			// Print the information of the record being processed
			AddMessage('   Processing: ' + GetElementEditValues(plugin_currentRecord, 'NAME') + ' - (' + Name(plugin_currentRecord) + ')');
			// This is a record we're actually processing, so +1
			Inc(trappedCount);
			// Is the "dry run" flag on or off?
			if (not devTest) then
				SetIsPersistent(plugin_currentRecord, True);
			Exit;
		end;

		// This is the edge cases block, clearing out the occasional odd actor that doesn't need to be flagged, but will otherwise still trip the primary filter
		// if	(ReferencedByCount(plugin_currentRecord) = 0)
		// 	or not (IsReferencedByNonLocation(plugin_currentRecord))
		// then begin
		if not (IsReferencedByNonLocation(plugin_currentRecord))
		then begin
			// REFR and PHZD don't need anything below this point
            if (Signature(e) <> 'ACHR') then
                Exit;

            // Some modders did not use any sort of persistence for their NPCs, breaking their packages.
			// Let's try to detect them. All of these cases target actors without any non-locational references.

            // This NPC uses Persistent Location, should work fine if the location was assigned correctly. Can be flagged explicitly with an option (many false positives!)
            if (Assigned(ElementByPath(plugin_currentRecord, 'XLCN'))) then
                Exit;

			// Skip "Starts Dead"-flagged refs
			if (GetElementNativeValues(plugin_currentRecord, 'Record Header\Record Flags\Starts Dead') <> 0) then
    			Exit;

            // Skip chicken and such
            if (GetElementNativeValues(plugin_baseRecord, 'ACBS\Flags\Simple Actor') <> 0) then
                Exit;
            
            // Skip non-persistent, non-unique actors
            if (GetElementNativeValues(plugin_baseRecord, 'ACBS\Flags\Unique') = 0) then
                Exit;
            
			// Skip unique actors without/having extremely simple behavior packages (probably, flagged erroneously)
			plugin_packageCount := ElementCount(ElementByPath(plugin_baseRecord, 'Packages'));
			if (plugin_packageCount = 0)
			then begin
				Exit;
			end
			else if (plugin_packageCount = 1)
			then begin
				// Skip actors, having a single package revolving around their editor location or themselves
				plugin_package := LinksTo(ElementByIndex(ElementByPath(plugin_baseRecord, 'Packages'), 0));
				
				if not Assigned(plugin_package) then
					Exit;
					
				plugin_packageLoc := GetElementEditValues(ElementByIndex(ElementByPath(plugin_package, 'Package Data\Data Input Values'), 0), 'PLDT\Type');
				
				if (Pos(plugin_packageLoc, 'Near editor location|Near self') <> 0) then begin
					AddMessage('   Skipping editor location actor: ' + GetElementEditValues(plugin_currentRecord, 'NAME') + ' - (' + Name(plugin_currentRecord) + ')');
					Exit;
				end;
				
				if (plugin_packageLoc = 'In cell') then begin
					plugin_packageCell := LinksTo(ElementByPath(ElementByIndex(ElementByPath(plugin_package, 'Package Data\Data Input Values'), 0), 'PLDT\Cell'));
					if Assigned(plugin_packageCell) then begin
						if Equals(plugin_packageCell, LinksTo(ElementByPath(plugin_currentRecord, 'Cell'))) then begin
							AddMessage('   Skipping actor, staying in one cell: ' + GetElementEditValues(plugin_currentRecord, 'NAME') + ' - (' + Name(plugin_currentRecord) + ')');
							Exit;
						end;
					end;
				end;
			end;
		end;
		
		// Print the information of the record being processed
		AddMessage('   Processing: ' + GetElementEditValues(plugin_currentRecord, 'NAME') + ' - (' + Name(plugin_currentRecord) + ')');
		// This is a record we're actually processing, so +1
		Inc(trappedCount);
		// Is the "dry run" flag on or off?
		if (not devTest) then
			SetIsPersistent(plugin_currentRecord, True);
	end

	//
	// SECTION 2
	// If processed record's FormID isn't greater than 0 then we're at the end of the file, so print reports and check for ESM flagging
	//
	else begin
		// Check if there were any countable records in this plugin at all
		if (RecordCount(plugin_currentPlugin) = 0)
		then begin
			AddMessage('* Plugin is Empty, skipping.');
		end

		// Print this log summary if records were counted but none processed by SECTION 1
		else if	(recordsCounted > 0)
				and (trappedCount = 0)
		then begin
			AddMessage('   ' + IntToStr(recordsCounted) + ' records scanned. Nobody needs rescuing.');
		end

		// Report back on what needed to be processed in SECTION 1
		else begin
			if (devTest)
			then begin
				AddMessage('(DEV MODE)    ' + IntToStr(recordsCounted) + ' records scanned. Would have freed ' + IntToStr(trappedCount) + ' trapped NPC(s).');
			end
			else begin
				AddMessage('   ' + IntToStr(recordsCounted) + ' records scanned. Freed ' + IntToStr(trappedCount) + ' trapped NPC(s).');
			end;
		end;

		// Do we want to flag the plugin as ESM?
		if not (getIsESM(plugin_currentPlugin))
		then begin
			if (devTest) or (not esmify)
			then begin
				AddMessage(Format(
					'!  %s would be flagged as an ESM.', [Name(plugin_currentPlugin)]));
			end
			else begin
				AddMessage(Format(
					'!  %s is being flagged as an ESM.', [Name(plugin_currentPlugin)]));
				setIsESM(plugin_currentPlugin, true);
			end;
		end;
		
		// Reset counters and flags
		recordsCounted := 0;
		trappedCount := 0;
		announcedPlugin := false;
	end;
end;

function Finalize: integer;
begin
	AddMessage(' ');
	Result := 0;
end;

end.
