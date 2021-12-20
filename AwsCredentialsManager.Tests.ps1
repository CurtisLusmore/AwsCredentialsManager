Describe "AwsCredentialsManager Tests" {
    BeforeAll {
        Import-Module -Force .\AwsCredentialsManager.psm1

        Move-Item -Force ~/.aws/credentials ~/.aws/credentials.test.backup
        Move-Item -Force ~/.aws/config ~/.aws/config.test.backup

        $env:AWS_PROFILE = $null
    }

    AfterAll {
        Move-Item -Force ~/.aws/credentials.test.backup ~/.aws/credentials
        Move-Item -Force ~/.aws/config.test.backup ~/.aws/config

        $env:AWS_PROFILE = $null
    }

    It "Should create an IAM User" {
        New-AwsIamUser `
            -Domain work `
            -AccessKeyId (ConvertTo-SecureString -String '01000000d08c9ddf0115d1118c7a00c04fc297eb0100000064e873435b193b47969a2a89b4a1b994000000000200000000001066000000010000200000009c05e1e06c3f89f4804824e02fe7284c4f33bde0f4041e2f2541c1a06483a15b000000000e8000000002000020000000c845cf701cdf88c3600e3281c02fbd2f3d2bb3da999ae9ca882065175ff7f596200000007e241803f238536ff5628df3640845b2054b7e26ffeeceb3e505059c2430522340000000299a77ad73c09598e842a971029eb1a7c7dd163ab4a31f956eefe9667ea6ce62a43e20ec3c5f1f52c3d105053b85d03a2b50384250f4a542e27dd2e1f90a25c0') `
            -SecretAccessKey (ConvertTo-SecureString -String '01000000d08c9ddf0115d1118c7a00c04fc297eb0100000064e873435b193b47969a2a89b4a1b994000000000200000000001066000000010000200000003eabc54d783cbefe23c601b00cea818bb932a36f20a3efd7fac94dbd48cd0388000000000e8000000002000020000000f3bf88a47fe9670b388a1712f30e6a0b2bcbc691d9ced8923ff4041b7b0e585120000000b6982d0939c4b90a8aea5372a7692ffb7fd372ec6dc97172ac04125b1fd3bb674000000041741a79e6482851b0db2f3aa65bc8c6a289a2323a1c141d0f540110dcae0d44ccde56529877f4e0f6f303a13137a1a25fc6c1cc67a54ece57c66d3ff5dcc8f9')

        aws configure get aws_access_key_id --profile work:iam | Should -Be AccessKeyId
        aws configure get aws_secret_access_key --profile work:iam | Should -Be SecretAccessKey
    }

    It "Should create an MFA user" {
        New-AwsMfaUser `
            -Domain work `
            -DeviceArn arn:aws:iam::000000000000:mfa/your.name

        aws configure get mfa_device_arn --profile work:mfa | Should -Be arn:aws:iam::000000000000:mfa/your.name
    }

    It "Should create an Assume Role" {
        New-AwsAssumeRole `
            -Mfa work:mfa `
            -RoleName dev `
            -RoleArn arn:aws:iam::000000000000:role/PowerUsers `
            -Region ap-southeast-2

        aws configure get role_arn --profile work:dev | Should -Be arn:aws:iam::000000000000:role/PowerUsers
        aws configure get source_profile --profile work:dev | Should -Be work:mfa
        aws configure get region --profile work:dev | Should -Be ap-southeast-2
    }

    It "Should set the active AWS Profile" {
        Set-AwsProfile `
            -Domain work `
            -AssumeRole dev

        $env:AWS_PROFILE | Should -Be work:dev
    }

    It "Should support argument completion for New-AwsMfauser" {
        $domains = Get-AwsDomainsCompleter $null $null '' $null $null

        $domains | Should -Be work
    }

    It "Should support argument completion for New-AwsAssumeRole -User" {
        $profiles = Get-AwsProfilesCompleter $null User '' $null $null

        $profiles | Should -Be work:iam,work:mfa
    }

    It "Should support argument completion for New-AwsAssumeRole -Iam" {
        $profiles = Get-AwsProfilesCompleter $null Iam '' $null $null

        $profiles | Should -Be work:iam
    }

    It "Should support argument completion for New-AwsAssumeRole -Mfa" {
        $profiles = Get-AwsProfilesCompleter $null Mfa '' $null $null

        $profiles | Should -Be work:mfa
    }

    It "Should support argument completion for Set-AwsProfile -Domain" {
        $profiles = Get-AwsDomainsCompleter $null $null '' $null $null

        $profiles | Should -Be work
    }

    It "Should support argument completion for Set-AwsProfile -All" {
        $profiles = Get-AwsProfilesCompleter $null All '' $null @{ Domain = 'work' }

        $profiles | Should -Be dev,iam,mfa
    }

    It "Should support argument completion for Set-AwsProfile -AssumeRole" {
        $profiles = Get-AwsProfilesCompleter $null AssumeRole '' $null @{ Domain = 'work' }

        $profiles | Should -Be dev
    }

    It "Should support argument completion for Set-AwsProfile -Iam" {
        $profiles = Get-AwsProfilesCompleter $null Iam '' $null @{ Domain = 'work' }

        $profiles | Should -Be iam
    }

    It "Should support argument completion for Set-AwsProfile -Mfa" {
        $profiles = Get-AwsProfilesCompleter $null Mfa '' $null @{ Domain = 'work' }

        $profiles | Should -Be mfa
    }

    It "Should support argument completion for Get-AwsProfiles -Domain" {
        $profiles = Get-AwsDomainsCompleter $null $null '' $null $null

        $profiles | Should -Be work
    }
}