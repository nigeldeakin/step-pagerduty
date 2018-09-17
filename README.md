# step-pagerduty

A pagerduty notifier written in `bash` and `curl`.
It is intended to be used in an `after-step` and sends a notification of whether the pipeline failed or (optionally) succeeded.

# Options

- `service_key` (required) Service key (see https://v2.developer.pagerduty.com/docs/trigger-events).
- `url` (optional) URL to which notifications will be sent. The default value is `https://events.pagerduty.com/generic/2010-04-15/create_event.json`
- `notify_on` (optional) If set to `failed` (which is the default) then a notification is sent only if the pipeline has failed.
              If set to `all` (or any other value) then a notification is sent both when the pipeline succeeds and fails.
- `branch` (optional) If set then a notification will only be sent for runs on the given branch
- `client` (optional) Specifies the `client` field of the notification. This is defined as the name of the monitoring client that is triggering this event. 
- `client_url` (optional) Specifies the `client_url` field of the notification. This is defined as the URL of the monitoring client that is triggering this event. 

Note that the `description` field of the notification is set automatically (see example below).

# Example

```yaml
build:
  ...
  after-steps:
    - nigeldeakin/pagerduty-notifier@1.0.18:
        service_key: $PAGERDUTY_SERVICE_KEY 
        branch: master   
```

Typical failure message:
```
Pipeline 'deploy' for myapp by nigeldeakin has failed on branch master at step: 'Do something'. See https://app.wercker.com/nigeldeakin/myapp/deploy/5b9fab2bc81a8a00066d8c1b.
```

# Changelog

## 1.0.19

- Initial release

