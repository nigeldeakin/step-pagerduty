#!/bin/bash

function fail() {
    echo "failed: ${1}" 
    if [ -n "$WERCKER_REPORT_MESSAGE_FILE" ]; then
      echo "${1}" > "$WERCKER_REPORT_MESSAGE_FILE"
    fi
    exit 1
}

# service_key is required
if [ -z "$WERCKER_PAGERDUTY_NOTIFIER_SERVICE_KEY" ]; then
  fail "service_key is not set"
fi

# client_url
if [ -z "$WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL" ]; then
  if [ -n "$DEPLOY" ]; then
    export WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL=$WERCKER_DEPLOY_URL
  else
    export WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL=$WERCKER_BUILD_URL
  fi
fi

# event_type (always trigger)
export WERCKER_PAGERDUTY_NOTIFIER_EVENT_TYPE="trigger"

# check if this event is a build or deploy
if [ -n "$DEPLOY" ]; then
  # its a deploy!
  export ACTION="pipeline ($WERCKER_DEPLOYTARGET_NAME)"
  export ACTION_URL=$WERCKER_DEPLOY_URL
else
  # its a build!
  export ACTION="build" # we can't find the actual pipeline name 
  export ACTION_URL=$WERCKER_BUILD_URL
fi

export MESSAGE="$ACTION for $WERCKER_APPLICATION_NAME by $WERCKER_STARTED_BY has $WERCKER_RESULT on branch $WERCKER_GIT_BRANCH"

if [ -n "$WERCKER_PAGERDUTY_NOTIFIER_DESCRIPTION" ]; then
  export MESSAGE="$WERCKER_PAGERDUTY_NOTIFIER_DESCRIPTION. $MESSAGE"
fi

if [ "$WERCKER_RESULT" = "failed" ]; then
  export MESSAGE="$MESSAGE at step: $WERCKER_FAILED_STEP_DISPLAY_NAME"
fi

export MESSAGE="$MESSAGE. See $ACTION_URL."

# construct the json
json="{"

# service_key
json=$json"\"service_key\": \"$WERCKER_PAGERDUTY_NOTIFIER_SERVICE_KEY\","

# event_type
json=$json"\"event_type\": \"$WERCKER_PAGERDUTY_NOTIFIER_EVENT_TYPE\","

# description
json=$json"\"description\": \"$MESSAGE\","

if [ -z "$WERCKER_PAGERDUTY_NOTIFIER_CLIENT" ]; then
  json=$json"\"client\": \"$WERCKER_PAGERDUTY_NOTIFIER_CLIENT\","
fi

# details (TODO)
json=$json"\"details\: {},"

# client_url
json=$json"\"client_url\": \"$WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL\","

# contexts (TODO)
json=$json"\"contexts\": []"

json=$json"}"

# skip if not interested in passed builds or deploys
if [ "$WERCKER_PAGERDUTY_NOTIFIER_NOTIFY_ON" = "failed" ]; then
	if [ "$WERCKER_RESULT" != "failed" ]; then
    echo Doing nothing because pipeline has not failed. 
		return 0
	fi
fi

# skip if not on the right branch
if [ -n "$WERCKER_PAGERDUTY_NOTIFIER_BRANCH" ]; then
    if [ "$WERCKER_PAGERDUTY_NOTIFIER_BRANCH" != "$WERCKER_GIT_BRANCH" ]; then
        echo "Doing nothing because run is not on the $WERCKER_PAGERDUTY_NOTIFIER_BRANCH branch." 
        return 0
    fi
fi

# Just for now, dump the JSON
echo $json

# post the event to pagerduty
RESULT=$(curl -d "payload=$json" -s "$WERCKER_PAGERDUTY_NOTIFIER_URL" --output "$WERCKER_STEP_TEMP"/result.txt -w "%{http_code}")
cat "$WERCKER_STEP_TEMP/result.txt"

if [ "$RESULT" != "200" ]; then
  fail "Sending alert to PagerDuty FAILED."
fi

