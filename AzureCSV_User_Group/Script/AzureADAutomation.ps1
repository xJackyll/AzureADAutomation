# Connecting to AZ AD
Connect-AzureAD -TenantId "dce2317a-3c7a-47bd-9bfc-460ef7e7ff3d" | Out-Null

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Defining variables

# You can Enable/Disable the log level with this variable
$Enable_Debug = $true

$index = 1

# Setting the object "password"
$PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile

# Importo il csv
$CsvFile = "$PSScriptRoot\..\Excel\CSVxScript.csv"
$table = Import-Csv $CsvFile -Delimiter "," | Sort-Object -Property isGroup -Descending

# This is the dictionary containing the mapping of attributes and groups
# CHANGE THIS DICT AS NEEDED (ALSO CHECK THE ATTRIBUTES IN THE EXCEL FILE)
$dict = @{
    "Amministrazione" = "amm"
    "Magazzino" = "mag"
    "HR_Group" = "hr"
    "Marketing" = "mar"
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Log Function Variables. You can ignore this 

$Color1 = "Green"
$Color2 = "yellow"
$Color3 = "Red"
$Color4 = "Cyan"

$Err = "Error"
$Warning = "Warning"
$Information = "Info"
$Debug = "Debug"

# Log Variables
$LogName ="_AzAD.txt"
$Today = (Get-Date).ToString("yyyy_MM_dd")
$LogPathFolder = "$PSScriptRoot\..\Logs\"
$LogPath = "${LogPathFolder}${Today}${LogName}"

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Log Function.  You can ignore this 

Function Logging {
    param(
    [string]$Log,
    [string]$MessageType
    )

    # Get the time
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

    # Color the message
    $TextColor = switch ($MessageType) {
        'Info' { $Color1 }
        'Warning' { $Color2 }
        'Error' { $Color3 }
        'Debug' { $Color4 }
    }

    # Create the formatted string
    if ($Enable_debug -eq $true)
    {
        $logEntry = "$timestamp`t|`t$MessageType`t|`t$Log`t|`t(Line $($MyInvocation.ScriptLineNumber))"
        
    }
    else 
    {
       $logEntry = "$timestamp`t|`t$MessageType`t|`t$Log"
    }

    # Save the log string to the log file
    if (!($Enable_Debug -eq $false -and $MessageType -eq $Debug )) 
    {
        Write-Host $logEntry -ForegroundColor $TextColor
        Add-Content -Path $LogPath -Value $logEntry   
    }

}


# ------------------------------------------------------------------------------------------------------------------------------------------------
# Group Function

Function Group_Check_and_Creation ($riga){
    # ---------------------------
    # We are dealing with a group
    # ---------------------------

    # Check if the Group exist
    $GroupExist = (Get-AzureADGroup -Filter "DisplayName eq '$($riga.DisplayName)'" -ErrorAction SilentlyContinue).count

    if ($GroupExist -ge 1){
        
        # Skipping creation of the group
        Logging -Log "The group $($riga.DisplayName) already exist" -MessageType $Warning
    }
    else {
        
        # Creating the group
        Logging -Log "Creating the group $($riga.DisplayName) ..." -MessageType $Debug
        New-AzureADGroup -DisplayName $riga.DisplayName -MailEnabled $false -SecurityEnabled $true -MailNickName $riga.MailNickName | Out-Null
        Logging -Log "Group $($riga.DisplayName) created successfully" -MessageType $Debug
    }
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# User Function

Function User_Check_and_Creation ($riga, $mapping){
    # ---------------------------
    # We are dealing with a user
    # ---------------------------

    # Check if the User exist
    $User = Get-AzureADUser -Filter "userPrincipalName eq '$($riga.UserPrincipalName)'" -ErrorAction SilentlyContinue

    if ($User.count -eq 1){
        
        # Skipping creation of the user
        Logging -Log "The user $($riga.DisplayName) already exist" -MessageType $Warning

    }
    else {
        Logging -Log "Creating the user $($riga.DisplayName) ..." -MessageType $Debug

        # Creating a secure string 
        $PasswordProfile.Password = $riga.PasswordProfile

        # Creating the user
        New-AzureADUser -AccountEnabled $True -DisplayName $riga.DisplayName -PasswordProfile $PasswordProfile -MailNickName $riga.MailNickName -UserPrincipalName $riga.UserPrincipalName | Out-Null
        
        # We do this to get the user ID (which did not yet exist) and also to doublecheck the creation of the user
        $User = Get-AzureADUser -Filter "userPrincipalName eq '$($riga.UserPrincipalName)'" -ErrorAction Stop
        Logging -Log "Account $($riga.DisplayName) created successfully" -MessageType $Debug
        }
    

# ------------------------------------------------------------------------------------------------------------------------------------------------
# We now check deal with the groups the user is in   

    # We remove all the spaces and split every attribute into an array
    $attributes = $riga.Attributes -replace '\s','' -split ","

    # This list will contain all the groups the user have to be in
    $attributesgroups = New-Object System.Collections.ArrayList

    # Iterating for each attribute
    ForEach($attribute in $attributes){
        
        # Getting the corrisponding group name
        $mappedgroup = $mapping.GetEnumerator() | Where-Object { $_.Value -eq $attribute } | Select-Object -ExpandProperty Key
        
        # Add attribute group to the list
        $attributesgroups.Add($mappedgroup) | Out-Null

        # Check if the dictionary truly have matched a value-key pair
        if ($mappedgroup) {

            # Getting all the groups and choosing the only one that matches the group name
            $UserGroup = Get-AzureADUserMembership -ObjectId $User.ObjectId  | Where-Object DisplayName -EQ $mappedgroup

            # Check if the user is in the group
            if ($UserGroup.count -ge 1) {
                Logging -Log "The user is already in the group $mappedgroup" -MessageType $Debug
            }
            else {
                # We add the user into the group (We do the Get-AzADGroup cause we need the ID of the group, not just the name)
                $GroupProp =  Get-AzADGroup -DisplayName $mappedgroup
                Add-AzureADGroupMember -ObjectId $GroupProp.Id -RefObjectId $User.ObjectId | Out-Null
                Logging -Log "User added to $mappedgroup" -MessageType $Debug
        } 
        }
        else {
            Logging -Log "Attribute $attribute is not paired with a group! / Attribute Field empty " -MessageType $Warning
        }
       
    }
    
    # Iterate each group in which the user is present and exit those without attribute
    $Groups = Get-AzureADUserMembership -ObjectId $User.ObjectId
    ForEach($Group in $Groups){  
        if ($Group.DisplayName -notin $attributesgroups) {
            Remove-AzureADGroupMember -ObjectId $Group.ObjectId -MemberId $User.ObjectId | Out-Null 
            Logging -Log "User removed from $($Group.DisplayName)" -MessageType $Debug
        }
    }
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
# Iterating each line of the CSV

ForEach($row in $table){

    $index ++
    try {
        
        if ($row.isGroup -eq "True"){
            Group_Check_and_Creation($row)
        }

        else{
            User_Check_and_Creation $row $dict
        }
        
        Logging -Log "${index}° line: OK" -MessageType $Information
    }

    catch {
        Logging -Log "An ERROR occurred. The ${index}° line of the csv file will be skipped." -MessageType $Err
        Logging -Log  $_.Exception.Message -MessageType $Err
    }
}

# ------------------------------------------------------------------------------------------------------------------------------------------------
