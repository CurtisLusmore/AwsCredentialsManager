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
    }

    It "Should create an IAM User" {
        New-AwsIamUser `
            -Domain work `
            -AccessKeyId (ConvertTo-SecureString -AsPlainText 'AccessKeyId') `
            -SecretAccessKey (ConvertTo-SecureString -AsPlainText 'SecretAccessKey')

        aws configure get aws_access_key_id --profile work:iam | Should -Be AccessKeyId
        aws configure get aws_secret_access_key --profile work:iam | Should -Be SecretAccessKey
    }

    It "Should create an MFA user" {
        New-AwsMfaUser `
            -Domain work `
            -DeviceArn arn:aws:iam::000000000000:mfa/your.name

        aws configure get mfa_device_arn --profile work:mfa | Should -Be 'arn:aws:iam::000000000000:mfa/your.name'
    }

    It "Should create an Assume Role" {
        New-AwsAssumeRole `
            -Mfa work:mfa `
            -RoleName dev `
            -RoleArn arn:aws:iam::000000000000:role/PowerUsers `
            -Region ap-southeast-2

        aws configure get role_arn --profile work:dev | Should -Be 'arn:aws:iam::000000000000:role/PowerUsers'
        aws configure get source_profile --profile work:dev | Should -Be 'work:mfa'
        aws configure get region --profile work:dev | Should -Be 'ap-southeast-2'
    }

    It "Should set the active AWS Profile" {
        Set-AwsProfile `
            -Domain work `
            -AssumeRole dev

        $env:AWS_PROFILE | Should -Be 'work:dev'
    }
}