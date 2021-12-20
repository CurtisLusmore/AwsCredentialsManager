<#
.SYNOPSIS

A module for managing AWS CLI configuration and credentials

.DESCRIPTION

AwsCredentialsManager is a PowerShell module for managing AWS CLI configuration
and credentials. It defines a naming convention for related profiles, makes it
easy to add, find and switch between profiles, and greatly simplifies the
process of refreshing temporary MFA credentials.

For example, at work you might have an IAM user and then several roles (one per
environment) which require MFA to use. AwsCredentialsManager makes it easy to
set up and manage the following profiles:

* work:iam to represent your IAM user, defined by your CLI access key/secret,
* work:mfa to represent your temporary MFA credentials, which uses work:iam to
  obtain a session token,
* work:dev to represent your role for the dev account, which uses work:mfa as
  the source profile,
* etc.
#>


<#
.SYNOPSIS

Create a new IAM user profile

.DESCRIPTION

Create a new user profile that authenticates via an access key and secret

.PARAMETER Domain

The domain that the user belongs to, to help group related users, e.g. work

.PARAMETER AccessKeyId

The AWS Access Key ID

.PARAMETER SecretAccessKey

The AWS Secret Access Key

.PARAMETER PathToCsv

A path to a CSV file containing the "Access key ID" and "Secret access key"
#>
Function New-AwsIamUser
{
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='KeySecret')]
    Param(
        [Parameter(Mandatory)]
        [string]
        $Domain,

        [Parameter(Mandatory, ParameterSetName='KeySecret')]
        [SecureString]
        $AccessKeyId,

        [Parameter(Mandatory, ParameterSetName='KeySecret')]
        [SecureString]
        $SecretAccessKey,

        [Parameter(Mandatory, ParameterSetName='CSV')]
        [string]
        $PathToCsv
    )

    If ($PathToCsv)
    {
        $credentials = Import-Csv -Path $PathToCsv
        $AccessKeyIdPlainText = $credentials.'Access key ID'
        $SecretAccessKeyPlainText = $credentials.'Secret access key'
    }
    Else
    {
        $AccessKeyIdPlainText = SecureStringToPlainText $AccessKeyId
        $SecretAccessKeyPlainText = SecureStringToPlainText $SecretAccessKey
    }

    $profileName = "$Domain`:iam"

    If ($PSCmdlet.ShouldProcess(
        "aws configure set aws_access_key_id $(ConvertTo-MaskedString $AccessKeyIdPlainText) --profile $profileName",
        "[profile $profileName]",
        "Set aws_access_key_id to $(ConvertTo-MaskedString $AccessKeyIdPlainText)"))
    {
        aws configure set aws_access_key_id $AccessKeyIdPlainText --profile $profileName
    }

    If ($PSCmdlet.ShouldProcess(
        "aws configure set aws_secret_access_key $(ConvertTo-MaskedString $SecretAccessKeyPlainText) --profile $profileName",
        "[profile $profileName]",
        "Set aws_secret_access_key to $(ConvertTo-MaskedString $SecretAccessKeyPlainText)"))
    {
        aws configure set aws_secret_access_key $SecretAccessKeyPlainText --profile $profileName
    }
}

<#
.SYNOPSIS

Create a new MFA user profile

.DESCRIPTION

Create a new user profile that authenticates via MFA-enabled tempoary session
tokens

.PARAMETER Domain

The domain that the user (and corresponding IAM user) belongs to, to help group
related users, e.g. work

.PARAMETER DeviceArn

The ARN of the user's MFA device
#>
Function New-AwsMfaUser
{
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [Parameter(Mandatory)]
        [ArgumentCompleter({ Get-AwsDomainsCompleter @args })]
        [string]
        $Domain,

        [Parameter(Mandatory)]
        [string]
        $DeviceArn
    )

    $mfaProfileName = "$domain`:mfa"

    If ($PSCmdlet.ShouldProcess(
        "aws configure set mfa_device_arn $DeviceArn --profile $mfaProfileName",
        "[profile $mfaProfileName]",
        "Set mfa_device_arn to $DeviceArn"))
    {
        aws configure set mfa_device_arn $DeviceArn --profile $mfaProfileName
    }
}

<#
.SYNOPSIS

Create a new assume-role profile

.DESCRIPTION

Create a new user profile for assuming roles, which authenticates via a source
profile of either an IAM or MFA user

.PARAMETER RoleName

A short name to describe the role

.PARAMETER RoleArn

The ARN of the role to assume

.PARAMETER Region

The default AWS region for the role

.PARAMETER User

The source profile to use for authentication. Tab-completion will list all
available IAM and MFA users

.PARAMETER Iam

The source profile to use for authentication. Tab-completion will list all
available IAM users

.PARAMETER Mfa

The source profile to use for authentication. Tab-completion will list all
available MFA users
#>
Function New-AwsAssumeRole
{
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='User')]
    Param(
        [Parameter(Mandatory)]
        [string]
        $RoleName,

        [Parameter(Mandatory)]
        [string]
        $RoleArn,

        [Parameter(Mandatory)]
        [string]
        $Region,

        [Parameter(Mandatory, ParameterSetName='User')]
        [ArgumentCompleter({ Get-AwsProfilesCompleter @args })]
        [string]
        $User,

        [Parameter(Mandatory, ParameterSetName='IamUser')]
        [ArgumentCompleter({ Get-AwsProfilesCompleter @args })]
        [string]
        $Iam,

        [Parameter(Mandatory, ParameterSetName='MfaUser')]
        [ArgumentCompleter({ Get-AwsProfilesCompleter @args })]
        [string]
        $Mfa
    )

    $SourceProfile = If ($User) { $User } `
        ElseIf ($Iam) { $Iam } `
        Else { $Mfa }

    $domain = Get-AwsDomain $SourceProfile

    $profileName = "$domain`:$RoleName"

    If ($PSCmdlet.ShouldProcess(
        "aws configure set role_arn $RoleArn --profile $profileName",
        "[profile $profileName]",
        "Set role_arn to $RoleArn"))
    {
        aws configure set role_arn $RoleArn --profile $profileName
    }

    If ($PSCmdlet.ShouldProcess(
        "aws configure set source_profile $SourceProfile --profile $profileName",
        "[profile $profileName]",
        "Set source_profile to $SourceProfile"))
    {
        aws configure set source_profile $SourceProfile --profile $profileName
    }

    If ($PSCmdlet.ShouldProcess(
        "aws configure set region $Region --profile $profileName",
        "[profile $profileName]",
        "Set region to $Region"))
    {
        aws configure set region $Region --profile $profileName
    }
}

<#
.SYNOPSIS

Set the active AWS profile

.DESCRIPTION

Set the active AWS profile by setting the AWS_PROFILE environment variable

.PARAMETER Domain

The domain that the user belongs to

.PARAMETER All

The profile within the given domain to use. Tab-completion will list all
available IAM, MFA and assume-role profiles

.PARAMETER AssumeRole

The profile within the given domain to use. Tab-completion will list all
available assume-role profiles

.PARAMETER Iam

The profile within the given domain to use. Tab-completion will list all
available IAM profiles

.PARAMETER Mfa

The profile within the given domain to use. Tab-completion will list all
available MFA profiles
#>
Function Set-AwsProfile
{
    [CmdletBinding(SupportsShouldProcess, DefaultParameterSetName='All')]
    Param(
        [string]
        [ArgumentCompleter({ Get-AwsDomainsCompleter @args })]
        $Domain,

        [Parameter(Mandatory, ParameterSetName='All')]
        [string]
        [ArgumentCompleter({ Get-AwsProfilesCompleter @args })]
        $All,

        [Parameter(Mandatory, ParameterSetName='AssumeRole')]
        [string]
        [ArgumentCompleter({ Get-AwsProfilesCompleter @args })]
        $AssumeRole,

        [Parameter(Mandatory, ParameterSetName='IamUser')]
        [ArgumentCompleter({ Get-AwsProfilesCompleter @args })]
        [string]
        $Iam,

        [Parameter(Mandatory, ParameterSetName='MfaUser')]
        [ArgumentCompleter({ Get-AwsProfilesCompleter @args })]
        [string]
        $Mfa
    )

    $roleName = If ($All) { $All } `
        ElseIf ($AssumeRole) { $AssumeRole} `
        ElseIf ($Iam) { $Iam } `
        Else { $Mfa }

    $profileName = If ($Domain) { "$Domain`:$roleName" } Else { $RoleName }

    If ($PSCmdlet.ShouldProcess(
        "`$env:AWS_PROFILE = '$profileName'",
        "`$env:AWS_PROFILE",
        "Set value to $profileName"))
    {
        $env:AWS_PROFILE = $profileName
    }
}
<#
.SYNOPSIS

Update an MFA-based temporary session token

.DESCRIPTION

Use an MFA code to update the temporary session token for the MFA profile
associated with the currently active profile

.PARAMETER Code

The MFA code
#>
Function Update-AwsMfaCredentials
{
    [CmdletBinding(SupportsShouldProcess)]
    Param(
        [SecureString]
        $Code,

        [Switch]
        $Force
    )

    If (-not (Get-AwsProfile))
    {
        Write-Error "No profile set. Please run Set-AwsProfile"
        Return
    }

    $domain = Get-AwsDomain (Get-AwsProfile)
    $iamProfileName = "$domain`:iam"
    $mfaProfileName = "$domain`:mfa"

    $expiration = [DateTime](aws configure get expiration --profile $mfaProfileName)

    If (-not $Force -and $expiration - [DateTime]::Now -gt [TimeSpan]::FromHours(1))
    {
        Write-Information "Session already valid until $expiration" -InformationAction Continue
        Return
    }

    If (-not $Code)
    {
        $Code = Read-Host -AsSecureString -Prompt "Code"
    }

    $codePlainText = SecureStringToPlainText $Code

    $deviceArn = aws configure get mfa_device_arn --profile $mfaProfileName

    If ($PSCmdlet.ShouldProcess(
        "aws sts get-session-token --serial-number $deviceArn --token-code $(ConvertTo-MaskedString $codePlainText) --duration-seconds 129600 --profile $iamProfileName",
        "[profile $iamProfileName]",
        "Get session token"))
    {
        $resp = aws sts get-session-token `
            --serial-number $deviceArn `
            --token-code $codePlainText `
            --duration-seconds 129600 <# 36hrs #> `
            --profile $iamProfileName

        If (-not $?)
        {
            Write-Error "Failed to acquire new session token"
            Return
        }
    }
    Else
    {
        Write-Error "Failed to acquire new session token"
        Return
    }

    $json = $resp | ConvertFrom-Json | Select-Object -Expand Credentials

    $accessKeyId = $json.AccessKeyId
    $secretAccessKey = $json.SecretAccessKey
    $sessionToken = $json.SessionToken
    $expiration = $json.Expiration.ToString("o")

    If ($PSCmdlet.ShouldProcess(
        "aws configure set aws_access_key_id $(ConvertTo-MaskedString $accessKeyId) --profile $mfaProfileName",
        "[profile $mfaProfileName]",
        "Set aws_access_key_id to $(ConvertTo-MaskedString $accessKeyId)"))
    {
        aws configure set aws_access_key_id $accessKeyId --profile $mfaProfileName
    }

    If ($PSCmdlet.ShouldProcess(
        "aws configure set aws_secret_access_key $(ConvertTo-MaskedString $accessKeyId) --profile $mfaProfileName",
        "[profile $mfaProfileName]",
        "Set aws_secret_access_key to $(ConvertTo-MaskedString $secretAccessKey)"))
    {
        aws configure set aws_secret_access_key $secretAccessKey --profile $mfaProfileName
    }

    If ($PSCmdlet.ShouldProcess(
        "aws configure set aws_secret_access_key $(ConvertTo-MaskedString $accessKeyId) --profile $mfaProfileName",
        "[profile $mfaProfileName]",
        "Set aws_secret_access_key to $(ConvertTo-MaskedString $secretAccessKey)"))
    {
        aws configure set aws_session_token $sessionToken --profile $mfaProfileName
    }

    If ($PSCmdlet.ShouldProcess(
        "aws configure set expiration $expiration --profile $mfaProfileName",
        "[profile $mfaProfileName]",
        "Set expiration to $expiration"))
    {
        aws configure set expiration $expiration --profile $mfaProfileName
    }
}


# Helpers

Function Get-AwsDomain
{
    Param(
        [Parameter(Mandatory)]
        [string]
        $ProfileName
    )

    ($ProfileName -split ':',2)[0]
}

Function Get-AwsDomains
{
    Param(
        [string]
        $Search
    )

    $searchLocal = $Search

    aws configure list-profiles `
        | ForEach-Object { Get-AwsDomain $_ } `
        | Where-Object { $_ -like "$searchLocal*" } `
        | Sort-Object -Unique
}

Function Get-AwsDomainsCompleter
{
    $Search = $args[2]

    Get-AwsDomains -Search $Search
}

Function Get-AwsRoleName
{
    Param(
        [Parameter(Mandatory)]
        [string]
        $ProfileName
    )

    ($ProfileName -split ':',2)[1]
}

Function Get-AwsProfile
{
    $env:AWS_PROFILE
}

Function Get-AwsProfiles
{
    [CmdletBinding()]
    Param(
        [ValidateSet('Iam', 'Mfa', 'User', 'AssumeRole', 'All')]
        [string]
        $Type = 'All',

        [ArgumentCompleter({ Get-AwsDomainsCompleter @args })]
        [string]
        $Domain
    )

    $profiles = aws configure list-profiles

    $profiles = Switch ($Type)
    {
        'Iam' { $profiles | Where-Object { $_ -like '*:iam' } }
        'Mfa' { $profiles | Where-Object { $_ -like '*:mfa' } }
        'User' { $profiles | Where-Object { $_ -like '*:iam' -or $_ -like '*:mfa' } }
        'AssumeRole' { $profiles | Where-Object { -not ($_ -like '*:iam' -or $_ -like '*:mfa') } }
        'All' { $profiles }
    }

    $profiles = Switch ($Domain)
    {
        '' { $profiles }
        Default { $profiles | Where-Object { $_ -like "$domain`:*" } }
    }

    $profiles | Sort-Object
}

Function Get-AwsProfilesCompleter
{
    $Parameter = $args[1]
    $Search = $args[2]
    $FakeBoundParameters = $args[4]

    $domain = $FakeBoundParameters.Domain

    $profiles = Get-AwsProfiles -Type $Parameter -Domain $domain

    $Search = If ($domain) { "*:*$Search*" } Else { "*$Search*" }

    $profiles = $profiles | Where-Object { $_ -like $Search }

    If ($domain) { $profiles = $profiles | ForEach-Object { Get-AwsRoleName $_ } }

    $profiles
}

Function SecureStringToPlainText
{
    Param(
        [Parameter(Mandatory)]
        [SecureString]
        $SecureString
    )

    If ($Host.Version.Major -ge 7)
    {
        ConvertFrom-SecureString -AsPlainText $SecureString
    }
    Else
    {
        [System.Runtime.InteropServices.Marshal]::PtrToStringAuto(
            [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecureString)
        )
    }
}

Function ConvertTo-MaskedString
{
    Param(
        [Parameter(Mandatory)]
        [String]
        $String
    )

    $String -Replace '.','*'
}