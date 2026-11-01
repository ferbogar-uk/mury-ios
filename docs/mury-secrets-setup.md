# MURY — GitHub Actions secrets setup

This checklist contains no credentials. Do not enter passwords, private keys or encoded credential files in this document or commit them to Git.

## Destination

Open [MURY repository secrets](https://github.com/ferbogar-uk/mury-ios/settings/secrets/actions), select **New repository secret**, and create each name below. Use repository secrets, not variables.

GitHub does not reveal stored secret values. The secrets in larping cannot be downloaded or copied from its Settings page; use your original Apple credentials or secure backups.

## Required credentials

Checked against the existing MURY TestFlight workflow on 1 November 2026.

| Secret name | Value to enter privately in GitHub |
| --- | --- |
| APP_STORE_CONNECT_API_KEY | Complete original .p8 PEM text, including BEGIN/END PRIVATE KEY lines. Do not base64 encode. |
| APP_STORE_CONNECT_KEY_ID | Apple Key ID matching that .p8 file. |
| APP_STORE_CONNECT_ISSUER_ID | App Store Connect team Issuer ID. |
| IOS_DISTRIBUTION_P12 | Base64 encoding of the distribution .p12 file, including its private key. |
| IOS_DISTRIBUTION_PASSWORD | Password used to protect that .p12; this is not your Apple account password. |
| IOS_PROVISIONING_PROFILE | Base64 encoding of the App Store distribution .mobileprovision file. |

The existing workflow expects bundle ID **rdyy.larping**, team **Z6HU7P866U**, and profile name **Larping App Store Distribution**. Credentials must match these settings. Do not change them to make unrelated credentials fit.

## Prepare values locally

Run one command at a time in PowerShell on your own PC, replacing the example path. Paste the clipboard directly into the matching GitHub Secret field; do not paste values into chat or this document.

For APP_STORE_CONNECT_API_KEY:

~~~powershell
Get-Content -LiteralPath 'C:\path\AuthKey_YOURKEYID.p8' -Raw | Set-Clipboard
~~~

For IOS_DISTRIBUTION_P12:

~~~powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\distribution.p12')) | Set-Clipboard
~~~

For IOS_PROVISIONING_PROFILE:

~~~powershell
[Convert]::ToBase64String([IO.File]::ReadAllBytes('C:\path\profile.mobileprovision')) | Set-Clipboard
~~~

Enter the two IDs and the .p12 password directly in GitHub. Clear the clipboard afterward:

~~~powershell
Set-Clipboard -Value ''
~~~

If clipboard history or device sync is enabled, remove sensitive clipboard entries there too.

## If the original files are missing

The earlier search checked the project and the non-redirected Downloads path. A later check of the Windows Downloads known-folder setting found that Downloads is redirected into OneDrive, where Apple private keys and provisioning profiles do exist.

Valid Apple credentials cannot be invented in a local file. First locate your original files or secure backups. An existing .p8 private key cannot be downloaded again from Apple. Creating a replacement Apple API key, distribution certificate or provisioning profile requires a separate decision; do not revoke working LARPING credentials.

## Verification and release boundary

- Confirm all six names appear in MURY Settings after saving them; the list proves presence, not credential validity.
- The simulator workflow needs no signing secrets. The last native CI run still had three UI test failures; this checklist does not resolve those failures.
- Credential validity is established only by an authorized signing/upload check. No signed build or TestFlight upload is authorized by creating this document.
- Keep the existing workflow, signing configuration, bundle ID and LARPING secrets unchanged.

References: [GitHub Actions secrets](https://docs.github.com/en/actions/how-tos/write-workflows/choose-what-workflows-do/use-secrets), [Apple App Store Connect API](https://developer.apple.com/help/app-store-connect/get-started/app-store-connect-api).

## Setup progress — 1 November 2026

- Owner explicitly approved creating MURY-GitHub-CI with Developer access and acknowledged that Apple team keys apply across all apps in the team. Apple UI confirms the new key is active. Existing keys were preserved.
- Downloaded the private key into the Windows redirected Downloads folder, outside this repository. This folder is under OneDrive; keep the downloaded key private and retain a secure backup. No private key value is included here.
- GitHub CLI confirmed all six required MURY repository secrets were saved: APP_STORE_CONNECT_API_KEY, APP_STORE_CONNECT_KEY_ID, APP_STORE_CONNECT_ISSUER_ID, IOS_DISTRIBUTION_P12, IOS_DISTRIBUTION_PASSWORD and IOS_PROVISIONING_PROFILE.
- Reused an existing profile whose name, team and bundle ID match the workflow, with HealthKit enabled and expiration 30 October 2027. The original unnumbered profile lacks HealthKit; the numbered (1) and (2) copies match each other and include it.
- Located the original distribution.p12 and its existing password file in the older local LARPING project, under privado/assinatura/ficheiros. Imported the certificate using ephemeral key storage: the password was accepted, its private key is present, it matches the selected provisioning profile, and it expires on 30 October 2027. Reused these originals without modifying them. No signing certificate or provisioning profile was issued or revoked. No workflow or signing configuration was changed.
- Verification: GitHub listed all six exact names after successful secret-set commands; a read-only Apple API request authenticated with the new key returned HTTP 200 and matched rdyy.larping. Certificate/password/profile checks passed locally. A signed archive/export and upload have not been tested. No TestFlight upload was performed.
