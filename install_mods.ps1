try {
	$URL = 'https://raw.githubusercontent.com/corey-braun/lethal-company-mods-installer/main/mods.json'
	$gameDir = $PSScriptRoot
	cd $gameDir
	if (-not (Test-Path 'Lethal Company.exe')) {
		throw 'Failed to find "Lethal Company.exe". Make sure the script is located in your Lethal Company game folder.'
	}

	## Get JSON mods list as hashtable
	if (Test-Path mods.json) {
		$mods_json = Get-Content mods.json
	}
	else {
		$mods_json = (Invoke-WebRequest $URL).Content
	}
	$mods = @{}
	(ConvertFrom-Json "$mods_json").psobject.properties | Foreach { $mods[$_.Name] = $_.Value }

	## Download mod files in a temporary directory
	try {
		$tmpDir = New-Item -Type Directory "tmp-$(New-Guid)"
		## If there are existing mod files, back them up before downloading new mods
		$mod_items = 'changelog.txt', 'winhttp.dll', 'doorstop_config.ini', 'BepInEx\'
		if (Test-Path BepInEx\) {
			$modsBackupDir = New-Item -Force -Type Directory $tmpDir\ModsBackup
			Move-Item $mod_items $modsBackupDir -ErrorAction SilentlyContinue
		}
		## Create/set plugins directory
		$pluginsDir = New-Item -Force -Type Directory BepInEx\plugins
		
		cd $tmpDir
		foreach($mod in $mods.Keys) {
			## Download mod
			Invoke-WebRequest -OutFile "$mod.zip" $mods.$mod.URL
			Expand-Archive "$mod.zip"
			
			## Install mod
			if ($mod -eq 'BepInEx') {
				Copy-Item -Force -Recurse $mod\* $gameDir -ErrorAction Stop
			}
			else {
				Copy-Item -Force -Recurse $mod\$($mods.$mod.PluginDir)\* $pluginsDir -ErrorAction Stop
			}
		}
		## Restore existing config files if present
		if (Test-Path variable:modsBackupDir) {
			Copy-Item -Force -Recurse $modsBackupDir\BepInEx\config\ $gameDir\BepInEx\ -ErrorAction SilentlyContinue
		}
		Write-Host 'Finished installing mods'
	}
	catch {
		Write-Host 'Error downloading/installing mods'
		cd $gameDir
		Remove-Item -Recurse $mod_items -ErrorAction SilentlyContinue
		## Restore old mods
		if (Test-Path variable:modsBackupDir) {
			Move-Item $modsBackupDir\* $gameDir
			Write-Host 'Restored old mod files'
		}
	}
	finally {
		cd $gameDir
		Remove-Item -Recurse $tmpDir
	}
}
catch {
	Write-Host Error: $_
}
Read-Host -Prompt 'Press Enter to exit'
exit