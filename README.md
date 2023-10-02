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

This module will help you to build and manage your AWS CLI `credentials` and
`config` files to look something like the below:

```
# ~/.aws/credentials
[work:iam]
aws_access_key_id = <REDACTED>
aws_secret_access_key = <REDACTED>
[work:mfa]
aws_access_key_id = <REDACTED>
aws_secret_access_key = <REDACTED>
aws_session_token = <REDACTED>
[home:iam]
aws_access_key_id = <REDACTED>
aws_secret_access_key = <REDACTED>

# ~/.aws/config
[profile work:mfa]
mfa_device_arn = arn:aws:iam::000000000000:mfa/your.name
[profile work:dev]
role_arn = arn:aws:iam::000000000000:role/PowerUsers
source_profile = work:mfa
region = ap-southeast-2
[profile work:test]
role_arn = arn:aws:iam::111111111111:role/PowerUsers
source_profile = work:mfa
region = ap-southeast-2
[profile work:staging]
role_arn = arn:aws:iam::222222222222:role/PowerUsers
source_profile = work:mfa
region = ap-southeast-2
[profile home:project1]
role_arn = arn:aws:iam::999999999999:role/PowerUsers
source_profile = home:iam
region = ap-southeast-2
```

It will also allow you to easily discover and switch between profiles, and
manage temporary MFA session tokens which last up to 36 hours.


## Why This Module?

The major benefit of this module is the management of temporary MFA session
tokens. The AWS CLI provides two ways of dealing with profiles which require
MFA:

### mfa_serial

The [`mfa_serial`][1] configuration setting allows you to specify an MFA device
ARN to use to generate temporary session tokens for a given role. Below is an
example of such a configuration setup:

```
~/.aws/credentials
[iam]
aws_access_key_id = <REDACTED>
aws_secret_access_key = <REDACTED>

~/.aws/config
[profile myrole]
role_arn = arn:aws:iam::000000000000:role/PowerUsers
source_profile = iam
mfa_serial = arn:aws:iam::000000000000:mfa/your.name
duration_seconds = 3600
```

When performing CLI actions from the `myrole` profile, you will be prompted for
your MFA code and a temporary session token will be generated and cached for
subsequent CLI actions.

```
> aws sts get-caller-identity
Enter MFA code for arn:aws:iam::000000000000:mfa/your.name:
{
    "UserId": "...",
    "Account": "...",
    "Arn": "..."
}
```

However, these session tokens will only be cached for [`duration_seconds`][2]
seconds, which is typically capped to a maximum of 3600 (1 hour). This means
that a typical workday could involve 8 or more MFA code prompts.


### sts get-session-token

An alternative is to use [`aws sts get-session-token`][3] to generate a
temporary session token, which is typically capped to a much more generous
maximum of 36 hours, meaning you will only be prompted for an MFA code once per
day.

The issue with this method is that persisting the session token into your
credentials file or environment variables is left as an
[exercise for the reader][4], which means that most users eventually end up
implementing a variation of this PowerShell module themselves.


## How to Use

Everything you need to know to install, configure and use this module is
described below.


### Installation

This module can be installed from [PSGallery][5] with the following:

```
> Install-Module -Name AwsCredentialsManager
```

### IAM Profiles

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


### MFA Profiles

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


### Assume-role Profiles

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
`-Iam` and `-Mfa` parameters as alternatives which will provide tab-completion
values based on only IAM or MFA profiles respectively to make it even easier to
find the correct profile. For example, you can type `New-AwsAssumeRole -Mfa`
and then press `Tab` and it will automatically suggest `work:mfa` as a possible
source profile.

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


### Setting the AWS Profile

The AWS Profile used by the CLI (when not specified explicitly via the
`--profile` parameter) is specified by the `AWS_PROFILE` environment variable.
The module allows you to set this easily, by switching between available profiles, for example:

```
> Set-AwsProfile -Domain work -All dev
```

Tab completion is available when selecting the domain.
`-All` refers to all available profiles belonging to the selected domain.
There are also `-Iam`, `-Mfa` and `-AssumeRole` parameters as alternatives, to
allow selection of a profile via a related Iam or Mfa configuration, or a role assumed by the profile.
For example, you can type `Set-AwsProfile -Domain work -AssumeRole` and then press
`Tab` and it will automatically suggest `dev` as a possible profile.

You can confirm that the profile has been set by viewing the `AWS_PROFILE`
environment variable.

```
> $env:AWS_PROFILE
work:dev
```


### Updating Temporary Session Token via MFA

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
[1]: https://docs.aws.amazon.com/sdkref/latest/guide/setting-global-mfa_serial.html
[2]: https://docs.aws.amazon.com/sdkref/latest/guide/setting-global-duration_seconds.html
[3]: https://awscli.amazonaws.com/v2/documentation/api/latest/reference/sts/get-session-token.html
[4]: https://aws.amazon.com/premiumsupport/knowledge-center/authenticate-mfa-cli/
[5]: https://www.powershellgallery.com/packages/AwsCredentialsManager
