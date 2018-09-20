#!/bin/bash
#   Copyright (c) 2018, Oracle and/or its affiliates.  All rights reserved.
#
#   Licensed under the Apache License, Version 2.0 (the "License");
#   you may not use this file except in compliance with the License.
#   You may obtain a copy of the License at
#
#       http://www.apache.org/licenses/LICENSE-2.0
#
#   Unless required by applicable law or agreed to in writing, software
#   distributed under the License is distributed on an "AS IS" BASIS,
#   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
#   See the License for the specific language governing permissions and
#   limitations under the License.

function fail() {
    echo "failed: ${1}" 
    if [ -n "$WERCKER_REPORT_MESSAGE_FILE" ]; then
      echo "${1}" > "$WERCKER_REPORT_MESSAGE_FILE"
    fi
    exit 1
}

# check that curl is installed
if ! type "curl" > /dev/null; then
  fail "curl is not installed"
fi

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
  export ACTION="Pipeline '$WERCKER_DEPLOYTARGET_NAME'"
else
  # its a build!
  export ACTION="Build" # we can't find the actual pipeline name 
fi

export MESSAGE="$ACTION for $WERCKER_APPLICATION_NAME by $WERCKER_STARTED_BY has $WERCKER_RESULT on branch $WERCKER_GIT_BRANCH"

if [ "$WERCKER_RESULT" = "failed" ]; then
  export MESSAGE="$MESSAGE at step: '$WERCKER_FAILED_STEP_DISPLAY_NAME'"
fi

export MESSAGE="$MESSAGE. See $WERCKER_RUN_URL."

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
#json=$json"\"details\": {},"

# client_url
json=$json"\"client_url\": \"$WERCKER_PAGERDUTY_NOTIFIER_CLIENT_URL\""

# contexts (TODO)
#json=$json"\"contexts\":[]"

json=$json"}"

# skip if the pipeline succeeded and we are only interested in failures
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

# post the event to pagerduty
echo "Sending event to pagerduty: $MESSAGE"
STATUS=$(curl -d "$json" -s --output "$WERCKER_STEP_TEMP"/result.txt -w "%{http_code}" $WERCKER_PAGERDUTY_NOTIFIER_URL)

if [ "$STATUS" = "400" ]; then
  cat "$WERCKER_STEP_TEMP/result.txt"
  fail "Sending event to PagerDuty FAILED: Invalid event"
fi

if [ "$STATUS" = "403" ]; then
  cat "$WERCKER_STEP_TEMP/result.txt"
  fail "Sending event to PagerDuty FAILED: Rate limited."
fi

if [ "$STATUS" != "200" ]; then
  cat "$WERCKER_STEP_TEMP/result.txt"
  fail "Sending event to PagerDuty FAILED: Status returned is $STATUS"
fi
