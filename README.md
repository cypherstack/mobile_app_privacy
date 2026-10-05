# mobile_app_privacy

Android 14+ startup: `com.cypherstack.mobile_app_privacy.ACCESSIBILITY_DATA_SENSITIVE=true` (application metadata).

Restore policy: `com.cypherstack.mobile_app_privacy.ACCESSIBILITY_DATA_SENSITIVE_RESTORE_MODE` accepts `auto` (default), `yes`, or `no`; activity metadata overrides application metadata.
Declare the host's actual policy; keep it unchanged while enabled.

When plugin instances share a host view, protection stays enabled while any
attached instance requests it. Disabling releases only that instance's request;
the returned effective state can remain `true` because another instance needs protection.

An optional Android <14 semantics fallback lives in the [example app](example/README.md),
not in the package API. It excludes screen readers as well as other accessibility services.

See the [testing guide](example/README.md#testing) for host requirements and Android/iOS tests.
