# Firebase Remote Config recipe

After core setup, add `firebase_remote_config` behind `FeatureFlagService`.
Keep compiled defaults, typed keys, fetch timeouts, and last-known safe values;
flags are not authorization. Register the adapter in DI per environment. Test
fetch/activation with a fake client and verify debug fetch intervals. Document
analytics coupling/consent. Remove the adapter/package/native files to roll back.
