#!/bin/bash

function fail() {
    echo "failed: ${1}" 
    if [ -n "$WERCKER_REPORT_MESSAGE_FILE" ]; then
      echo "${1}" > "$WERCKER_REPORT_MESSAGE_FILE"
    fi
    exit 1
}

# If url is not specified then use the default
if [ -z "$WERCKER_PAGERDUTY_NOTIFIER_URL" ]; then
  export WERCKER_PAGERDUTY_NOTIFIER_URL="https://events.pagerduty.com/generic/2010-04-15/create_event.json"
  echo Using url $WERCKER_PAGERDUTY_NOTIFIER_URL
fi

# service_key is required
if [ -z "$WERCKER_PAGERDUTY_NOTIFIER_SERVICE_KEY" ]; then
  fail "service_key is not set"
fi
echo Using service_key $WERCKER_PAGERDUTY_NOTIFIER_SERVICE_KEY

# event_type
export WERCKER_PAGERDUTY_NOTIFIER_EVENT_TYPE="trigger"
echo Using event_type $WERCKER_PAGERDUTY_NOTIFIER_EVENT_TYPE

# client_url
if [ -z "$WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL" ]; then
  if [ -n "$DEPLOY" ]; then
    export WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL=$WERCKER_DEPLOY_URL
  else
    export WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL=$WERCKER_BUILD_URL
  fi
fi

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

export MESSAGE="<$ACTION_URL|$ACTION> for $WERCKER_APPLICATION_NAME by $WERCKER_STARTED_BY has $WERCKER_RESULT on branch $WERCKER_GIT_BRANCH"
export FALLBACK="$ACTION for $WERCKER_APPLICATION_NAME by $WERCKER_STARTED_BY has $WERCKER_RESULT on branch $WERCKER_GIT_BRANCH"

if [ "$WERCKER_RESULT" = "failed" ]; then
  export MESSAGE="$MESSAGE at step: $WERCKER_FAILED_STEP_DISPLAY_NAME"
  export FALLBACK="$FALLBACK at step: $WERCKER_FAILED_STEP_DISPLAY_NAME"
fi

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

json=$json"\"client_url\": \"$WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL\","

# TODO details
# TODO contexts
# skip if not interested in passed builds or deploys
if [ "$WERCKER_PAGERDUTY_NOTIFIER_NOTIFY_ON" = "failed" ]; then
	if [ "$WERCKER_RESULT" = "passed" ]; then
		return 0
	fi
fi

# skip if not on the right branch
if [ -n "$WERCKER_PAGERDUTY_NOTIFIER_BRANCH" ]; then
    if [ "$WERCKER_PAGERDUTY_NOTIFIER_BRANCH" != "$WERCKER_GIT_BRANCH" ]; then
        return 0
    fi
fi
# Just for now, dump the JSON
echo $json

# Just for now, return
return 0

# post the event to pagerduty
RESULT=$(curl -d "payload=$json" -s "$WERCKER_PAGERDUTY_NOTIFIER_URL" --output "$WERCKER_STEP_TEMP"/result.txt -w "%{http_code}")
cat "$WERCKER_STEP_TEMP/result.txt"

if [ "$RESULT" = "500" ]; then
  if grep -Fqx "No token" "$WERCKER_STEP_TEMP/result.txt"; then
    fail "No token is specified."
  fi

  if grep -Fqx "No hooks" "$WERCKER_STEP_TEMP/result.txt"; then
    fail "No hook can be found for specified subdomain/token"
  fi

  if grep -Fqx "Invalid channel specified" "$WERCKER_STEP_TEMP/result.txt"; then
    fail "Could not find specified channel for subdomain/token."
  fi

  if grep -Fqx "No text specified" "$WERCKER_STEP_TEMP/result.txt"; then
    fail "No text specified."
  fi
fi

if [ "$RESULT" = "404" ]; then
  fail "Subdomain or token not found."
fi