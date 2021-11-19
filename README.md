# AwsCredentialsManager

`AwsCredentialsManager` is a PowerShell module for managing [AWS CLI][0]
configuration and credentials. It defines a naming convention for related
profiles, makes it easy to add, find and switch between profiles, and greatly
simplifies the process of refreshing temporary MFA credentials.

For example, at work you might have an IAM user and then several roles (one per
environment) which require MFA to use. `AwsCredentialsManager` makes it easy to
set up and manage the following profiles:

* `work:iam` to represent your IAM user, defined by your CLI access key/secret,
* `work:mfa` to represent your temporary MFA credentials, which uses `work:iam`
    to obtain a session token,
* `work:dev` to represent your role for the dev account, which uses `work:mfa`
    as the source profile,
* etc.


## IAM Profiles

To get started, let's create a new IAM user for your "work" domain.

```
> New-AwsIamUser -Domain work
Supply values for the following parameters:
AccessKeyId: ********************
SecretAccessKey: ****************************************
```

Alternatively, your administrator may have sent your credentials in a standard
`.csv` file which looks like this.

```csv
Access key ID,Secret access key
<REDACTED>,<REDACTED>
```

In this case you can run the following.

```
> New-AwsIamUser -Domain work -PathToCsv .\your.name_accessKeys.csv
```

After running one of the above, you should now have an AWS profile named
`work:iam`. You can confirm this by viewing the credentials file.

```
> Get-Content ~/.aws/credentials
[work:iam]
aws_access_key_id = <REDACTED>
aws_secret_access_key = <REDACTED>
```


## MFA Profiles

Some AWS environments are configured to require MFA when using the CLI. In
these cases you will need to create a new profile which uses your IAM
credentials and an MFA code to obtain temporary session credentials.

Let's add an MFA profile to our existing "work" domain.

```
> New-AwsMfaUser -Domain work
Supply values for the following parameters:
DeviceArn: arn:aws:iam::000000000000:mfa/your.name
```

Note that the `-Domain` parameter will provide tab-completion values based on
IAM profiles you have already configured. For example, you can type
`New-AwsMfaUser -Domain` and then press `Tab` and it will automatically suggest
`work` as a possible domain.

You should now have another AWS profile named `work:mfa`. You can confirm this
by viewing the config file.

```
> Get-Content ~/.aws/config
[profile work:mfa]
mfa_device_arn = arn:aws:iam::000000000000:mfa/your.name
```

This profile won't exist in the credentials file until we acquire a session
token, which we'll get to a bit later.


## Assume-role Profiles

Most AWS environments are configured such that permissions are granted via
roles which you need to assume. You might have one role per project or per
deployment environment, so you will likely need to manage several such
profiles.

Let's add an assume-role profile for our `dev` environment which requires MFA,
so we can assume it from our `work:mfa` profile.

```
> New-AwsAssumeRole -RoleName dev -User work:mfa
Supply values for the following parameters:
RoleArn: arn:aws:iam::000000000000:role/PowerUsers
Region: ap-southeast-2
```

Note that the `-User` parameter will provide tab-completion values based on
available IAM and MFA profiles you have already configured. There are also
`-IamUser` and `-MfaUser` parameters as alternatives which will provide
tab-completion values based on only IAM or MFA profiles respectively to make it
even easier to find the correct profile. For example, you can type
`New-AwsAssumeRole -MfaUser` and then press `Tab` and it will automatically
suggest `work:mfa` as a possible source profile.

You should now have another AWS profile named `work:dev`. You can confirm this
by viewing the config file.

```
> Get-Content ~/.aws/config
[profile work:mfa]
mfa_device_arn = arn:aws:iam::000000000000:mfa/your.name
[profile work:dev]
role_arn = arn:aws:iam::000000000000:role/PowerUsers
source_profile = work:mfa
region = ap-southeast-2
```

This profile will never appear in the credentials file because the credentials
are provided by the linked source profile.


## Setting the AWS Profile

The AWS Profile used by the CLI (when not specified explicitly via the
`--profile` parameter) is specified by the `AWS_PROFILE` environment variable.
You can easily switch between available profiles with the following command.

```
> Set-AwsProfile -Domain work -All dev
```

Note that the `-Domain` parameter will provide tab-completion values based on
previously configured profiles. The `-All` parameter will also provide
tab-completion values based on available profiles within the specified domain.
There are also `-Iam`, `-Mfa` and `-AssumeRole` parameters as alternatives
which will provide tab-completion values based on only IAM, MFA or assume-role
profiles respectively to make it even easier to find the correct profile. For
example, you can type `Set-AwsProfile -Domain work -AssumeRole` and then press
`Tab` and it will automatically suggest `dev` as a possible profile.

You can confirm that the profile has been set by viewing the `AWS_PROFILE`
environment variable.

```
> $env:AWS_PROFILE
work:dev
```


## Updating Temporary Session Token via MFA

In order to use MFA profiles, or assume-role profiles which are backed by
MFA profiles, you will need to acquire a temporary session token via MFA. Once
you have set the active AWS profile to an MFA or assume-role profile, you can
update your session token with the following.

```
> Update-AwsMfaCredentials
Supply values for the following parameters:
Code: ******
```

This will create (or update) the MFA profile in the credentials file, which you
can confirm with the following.

```
> Get-Content ~/.aws/credentials
[work:iam]
aws_access_key_id = <REDACTED>
aws_secret_access_key = <REDACTED>
[work:mfa]
aws_access_key_id = <REDACTED>
aws_secret_access_key = <REDACTED>
aws_session_token = <REDACTED>
```

You can confirm that the session token provides access with the following.

```
> aws sts get-caller-identity
{
    "UserId": "...",
    "Account": "...",
    "Arn": "..."
}
```


[0]: https://aws.amazon.com/cli/