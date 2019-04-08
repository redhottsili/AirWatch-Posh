$API_Url = ""   # Your AirWatch API URL e.g. https://as9999.awmdm.com/API
$API_Key = ""   #Your API key

function CreateParams {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateSet("mdm","system")]
        [string]$API_Sub,
        [Parameter(Mandatory = $true)]
        [ValidateSet("DEFAULT","DELETE","GET","HEAD","MERGE","OPTIONS","PATCH","POST","PUT","TRACE")]
        [string]$Method,
        [Parameter(Mandatory = $true)]
        [string]$uri_additions,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AWCredentials.Password)
    $Pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
    
    $parameters = @{
        uri     = "$API_Url/$API_Sub/$uri_additions";
        Method  = "$Method";
        Headers = @{
            Authorization = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("$($AWCredentials.UserName)`:$Pass"))
            "aw-tenant-code" = "$API_Key"
            "Accept" = 'application/json'
            "Content-Type" = 'application/json'
        }
    }

    return $parameters
}

function Get-AWUser {
    <#
    .SYNOPSIS
    Fetches AirWatch users
    
    .PARAMETER SearchParameter
    Seatch by this parameter
    
    .PARAMETER SearchValue
    The actual value to search for
    
    .PARAMETER All
    Fetch all AirWatch users instead of doing a search
    
    .PARAMETER OrderParameter
    Order results by this parameter
    
    .PARAMETER Descending
    Order results in descending order

    .PARAMETER AWCredentials
    The, authorized to conduct the API search, AirWatch Account's credentials
    
    .EXAMPLE
    Get-AWUser -All -OrderParameter username -Descending -AWUsername sampleaccount -AWSecurePassword *************

    This will return all AirWatch users, ordered by their username, in descending order

    .EXAMPLE
    Get-AWUser -SearchParameter firstname -SearchValue Bob -AWUsername sampleaccount -AWSecurePassword *************
    
    This will return all AirWatch users named Bob

    .NOTES
    Searching by uuid will utilize version 2 of the API call
    #>
    
    param(
        [Parameter(Mandatory = $true,ParameterSetName="IndividualUser")]
        [ValidateSet("uuid","id","firstname", "lastname", "email","locationgroupId","role","username")]
        [string]$SearchParameter,

        [Parameter(Mandatory = $true,ParameterSetName="IndividualUser")]
        [string]$SearchValue,

        [Parameter(Mandatory = $true,ParameterSetName="AllUsers")]
        [switch]$All,

        [Parameter(Mandatory = $false,ParameterSetName="AllUsers")]
        [ValidateSet("firstname", "lastname", "email","locationgroupId","role","username")]
        [string]$OrderParameter,

        [Parameter(Mandatory = $false,ParameterSetName="AllUsers")]
        [switch]$Descending,

        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials      
    )

    $params = CreateParams -API_Sub system -Method GET -uri_additions "users/search?$SearchParameter=$SearchValue" -AWCredentials $AWCredentials
    
    switch ($SearchParameter) {
        'uuid' {
            $params['uri'] = "$API_Url/system/users/$SearchValue"
            $params.Headers['Accept'] += ';version=2'
        }
        'id'{
            $params['uri'] = "$API_Url/system/users/$SearchValue"
        }
    }

    if ($All) {
        $params['uri'] = "$API_Url/system/users/search"
    }
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    if (($SearchParameter -ne "uuid") -and ($SearchParameter -ne "id")) {
        $results = $results.users #A hastable of the results is returned. This extracts the results from it.

        if ($SearchParameter -ne "uuid") {
            foreach ($entity in $results){
                $entity.id = $entity.id.Value #ID normally returns as a dictionary with 1 key-value pair. This converts it to a simple value.
            }
        }
    }

    if ($OrderParameter) {
        if (!$Descending) {
            $results = $results | Sort-Object -Property $OrderParameter
        } else {
            $results = $results | Sort-Object -Property $OrderParameter -Descending
        }        
    }
    
    Return $results
}

function Add-AWUser {
    param(
        [Parameter(
            Mandatory = $true,
            ParameterSetName="FromActiveDirectory",
            ValueFromPipelineByPropertyName=$true
        )]
        [string]$SamAccountName,
        [Parameter(Mandatory = $true)]
        [string]$Pass,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$userName,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$firstName,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$lastName,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$userPrincipalName,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$phoneNumber,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$mobileNumber,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$messageType,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$enrollmentRoleUuid,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$securityType,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$deviceStagingEnabled,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$deviceStagingType,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$organizationGroupUuid,
        [Parameter(
            Mandatory = $true,
            ParameterSetName="Manual",
			ValueFromPipelineByPropertyName=$true
        )]
        [String]$enrollmentOrganizationGroupUuid,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )

    if ($SamAccountName) {
        $ADUser = Get-ADUser $SamAccountName -Properties *

        if (!$ADUser) {
            Write-Error -Message "User not found"
            Break
        }
        
        $json = [ordered]@{
            "userName"= ("$($ADUser.UserPrincipalName)" -replace '@.*','')
            "password"= "$Pass"
            "firstName"= "$($ADUser.GivenName)"
            "lastName"= "$($ADUser.Surname)"
            "displayName"= "$($ADUser.GivenName) $($ADUser.Surname)"
            "userPrincipalName"= "$($ADUser.UserPrincipalName)"
            "emailAddress"= "$($ADUser.UserPrincipalName)"
            "emailUsername"= "$($ADUser.UserPrincipalName)"
            "phoneNumber"= "$($ADUser.ipPhone)"
            "mobileNumber"= "$($ADUser.OfficePhone)"
            "messageType"= "Email"
            "enrollmentRoleUuid"= "d8929a9f-2afa-4638-b58f-0089d1cc617f"
            "status"= 'true' #Users are created enabled by default
            "securityType"= "Basic"
            "deviceStagingEnabled"= 'false'
            "deviceStagingType"= "StagingDisabled"
            "organizationGroupUuid"= "c20b3f9a-b94f-4b1d-ac87-c02d01010747"
            "enrollmentOrganizationGroupUuid"= "c20b3f9a-b94f-4b1d-ac87-c02d01010747"
        }
    } else {
        $json = [ordered]@{
            "userName"= "$userName"
            "password"= "$Pass"
            "firstName"= "$firstName"
            "lastName"= "$lastName"
            "displayName"= "$firstName $lastName"
            "userPrincipalName"= "$userPrincipalName"
            "emailAddress"= "$userPrincipalName"
            "emailUsername"= "$userPrincipalName"
            "phoneNumber"= "$phoneNumber"
            "mobileNumber"= "$mobileNumber"
            "messageType"= "$messageType"
            "enrollmentRoleUuid"= "$enrollmentRoleUuid"
            "status"= 'true' #Users are created enabled by default
            "securityType"= "$securityType"
            "deviceStagingEnabled"= "$deviceStagingEnabled"
            "deviceStagingType"= "$deviceStagingType"
            "organizationGroupUuid"= "$organizationGroupUuid"
            "enrollmentOrganizationGroupUuid"= "$enrollmentOrganizationGroupUuid"
        }
    }
    
    $params = CreateParams -API_Sub system -Method POST -uri_additions "users/" -AWCredentials $AWCredentials

    $json = ($json | ConvertTo-Json)

    $params.Headers['Accept'] += ';version=2'
    $params.Add('Body',$json)
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    Return $results
}

function Set-AWUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$uuid,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [string]$Pass,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$firstName,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$lastName,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$userPrincipalName,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$phoneNumber,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$mobileNumber,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$messageType,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$enrollmentRoleUuid,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$securityType,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$deviceStagingEnabled,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$deviceStagingType,
        [Parameter(
            Mandatory = $false,
            ValueFromPipelineByPropertyName=$true
        )]
        [String]$enrollmentOrganizationGroupUuid,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )

    $json = [ordered]@{
        "password"= "$Pass"
        "firstName"= "$firstName"
        "lastName"= "$lastName"
        "displayName"= "$firstName $lastName"
        "userPrincipalName"= "$userPrincipalName"
        "emailAddress"= "$userPrincipalName"
        "emailUsername"= "$userPrincipalName"
        "phoneNumber"= "$phoneNumber"
        "mobileNumber"= "$mobileNumber"
        "messageType"= "$messageType"
        "enrollmentRoleUuid"= "$enrollmentRoleUuid"
        "deviceStagingEnabled"= "$deviceStagingEnabled"
        "deviceStagingType"= "$deviceStagingType"
        "enrollmentOrganizationGroupUuid"= "$enrollmentOrganizationGroupUuid"
    }

    #Remove empty attributes
    $newjson = [ordered]@{}
    $json.Keys | ForEach-Object {
        if ($json[$_]) {
            $newjson.Add($_,$json[$_])
        }
    }
    
    $params = CreateParams -API_Sub system -Method PUT -uri_additions "users/$uuid" -AWCredentials $AWCredentials

    $newjson = ($newjson | ConvertTo-Json)

    $params.Headers['Accept'] += ';version=2'
    $params.Add('Body',$newjson)
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    Invoke-RestMethod @params
}

function Remove-AWUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$uuid,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )

    $params = CreateParams -API_Sub system -Method DELETE -uri_additions "users/$uuid" -AWCredentials $AWCredentials

    $params.Headers['Accept'] += ';version=2'
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    Invoke-RestMethod @params
}

function Get-AWUserGroup {
    param(
        [Parameter(Mandatory = $true,ParameterSetName="IndividualUser")]
        [string]$Name,
        [Parameter(Mandatory = $true,ParameterSetName="AllGroups")]
        [switch]$All,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )

    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($AWSecurePassword)
    $Pass = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

    $params = CreateParams -API_Sub system -Method GET -uri_additions "usergroups/custom/search?groupname=$name" -AWCredentials $AWCredentials
    
    if ($All) {
        $params['uri'] = "$API_Url/system/usergroups/custom/search"
    }
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    Return $results.UserGroup
}

function Get-AWUserGroupMember {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupID,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )
    
    $params = CreateParams -API_Sub system -Method GET -uri_additions "usergroups/$GroupID/users" -AWCredentials $AWCredentials
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    Return $results
}

function Add-AWUserGroupMember {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupID,
        [Parameter(Mandatory = $true)]
        [string]$MemberID,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )
    
    $params = CreateParams -API_Sub system -Method POST -uri_additions "usergroups/$GroupID/user/$MemberID/addusertogroup" -AWCredentials $AWCredentials
   
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    Return $results
}

function Remove-AWUserGroupMember {
    param(
        [Parameter(Mandatory = $true)]
        [string]$GroupID,
        [Parameter(Mandatory = $true)]
        [string]$MemberID,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )
    
    $params = CreateParams -API_Sub system -Method POST -uri_additions "usergroups/$GroupID/user/$MemberID/removeuserfromgroup" -AWCredentials $AWCredentials
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    Return $results
}

function Get-AWOrganizationGroup {
    param(
        [Parameter(Mandatory = $true,ParameterSetName="IndividualOG")]
        [string]$Name,
        [Parameter(Mandatory = $true,ParameterSetName="AllOGs")]
        [switch]$All,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )
    
    $params = CreateParams -API_Sub system -Method GET -uri_additions "groups/search?name=$Name" -AWCredentials $AWCredentials

    if ($All) {
        $params['uri'] = "$API_Url/groups/search"
    }
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    if ($All) {
        $results = $results.LocationGroups
    }

    Return $results
}

function Get-AWApp {
    param(
        [Parameter(Mandatory = $true,ParameterSetName="IndividualApp")]
        [string]$Name,
        [Parameter(Mandatory = $true,ParameterSetName="AllApps")]
        [switch]$All,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )
    
    $params = CreateParams -API_Sub system -Method GET -uri_additions "productmonitor/apps/search?searchtext=$Name" -AWCredentials $AWCredentials
    
    if ($All) {
        $params['uri'] = "$API_Url/productmonitor/apps/search"
    }
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    Return $results
}

function Get-AWProfile {
    param(
        [Parameter(Mandatory = $true,ParameterSetName="IndividualProfile")]
        [string]$Name,
        [Parameter(Mandatory = $true,ParameterSetName="AllProfiles")]
        [switch]$All,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )
    
    $params = CreateParams -API_Sub system -Method GET -uri_additions "productmonitor/profiles/search?searchtext=$Name" -AWCredentials $AWCredentials

    if ($All) {
        $params['uri'] = "$API_Url/productmonitor/profiles/search"
    }
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    Return $results
}

function Get-AWDevice {
    <#
    .SYNOPSIS
    Formats: Macaddress: 0x848506B900BA, Udid: 6bf0f04c73681fbecfc3eb4f13cbf05b, SerialNumber: LGH871c18f631a, ImeiNumber: 354833052322837, EasId: 1234, DeviceId: 1234
    #>
    param(
        [Parameter(Mandatory = $false)]
        [ValidateSet("Macaddress","Udid","Serialnumber","ImeiNumber","EasId","DeviceId")]
        [string]$SearchParammeter,
        [Parameter(Mandatory = $true)]
        [string]$SearchValue,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )
    
    if (!$SearchParameter) {
        $params = CreateParams -API_Sub mdm -Method GET -uri_additions "devices?searchBy=Serialnumber&id=$SearchValue" -AWCredentials $AWCredentials
    } else {
        $params = CreateParams -API_Sub mdm -Method GET -uri_additions "devices?searchBy=$SearchParammeter&id=$SearchValue" -AWCredentials $AWCredentials
    }

    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    if ($All) {
        $results = $results.users
    }

    foreach ($entity in $results){
        $entity.id = $entity.id.Value #ID normally returns as a dictionary with 1 key-value pair. This converts it to a simple value.
    }

    Return $results
}

function Set-AWDeviceUser {
    param(
        [Parameter(Mandatory = $true)]
        [string]$SerialNumber,
        [Parameter(Mandatory = $true)]
        [string]$EnrollmentUserUsername,
        [Parameter(Mandatory = $true)]
        [PSCredential]$AWCredentials
    )
    
    $DeviceID = (Get-AWDevice -SearchParammeter Serialnumber -SearchValue $SerialNumber -AWCredentials $AWCredentials).id
    $EnrollmentUserID = (Get-AWUser -SearchParameter username -SearchValue $EnrollmentUserUsername -AWCredentials $AWCredentials).id
    
    $params = CreateParams -API_Sub mdm -Method PATCH -uri_additions "devices/$DeviceID/enrollmentuser/$EnrollmentUserID" -AWCredentials $AWCredentials
    
    #Use TLS 1.2, not 1.1
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12    
    
    #Download the report to a CSV file in the $path location
    $results = Invoke-RestMethod @params

    if ($All) {
        $results = $results.users
    }

    Return $results
}