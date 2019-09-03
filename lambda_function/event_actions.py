"""
Actions the skill will take based on event information, including the
request and the session dicts.
"""
import behaviors

def on_session_started(session_started_request, session):
    """
    Called when a user starts a session. Implement accordingly.
    Args:
        session_started_request: Python dict of request
        session: Python dict of session
    """
    print("on_session_started requestId=" + session_started_request['requestId']
          + ", sessionId=" + session['sessionId'])
    # Update code to handle session information

def on_launch(launch_request, session):
    """
    Called when the user launches the skill without specifying what they
    want.
    Args:
        launch_request: Python dict of request
        session: Python dict of session
    Returns:
        Python dict of response message
    """
    print("on_launch requestId=" + launch_request['requestId'] +
          ", sessionId=" + session['sessionId'])
    return behaviors.get_help_response()

def on_intent(intent_request, session):
    """
    Called when the user specifies an intent for this skill. Calls a behavior
    method based on the intent type.
    Args:
        intent_request: Python dict of request
        session: Python dict of session
    Returns:
        Python dict of response message
    """
    print("on_intent requestId=" + intent_request['requestId'] +
          ", sessionId=" + session['sessionId'])

    intent = intent_request['intent']
    intent_name = intent['name']

    if intent_name == "ToggleIntent":
        return behaviors.update_toggle(intent)
    elif intent_name == "OpenIntent":
        return behaviors.open_garage(intent)
    elif intent_name == "CloseIntent":
        return behaviors.close_garage(intent)
    elif intent_name == "StatusIntent":
        return behaviors.get_status(intent)
    elif intent_name == "AMAZON.HelpIntent":
        return behaviors.get_help_response()
    elif intent_name == "AMAZON.CancelIntent" or \
        intent_name == "AMAZON.StopIntent":
        return behaviors.handle_session_end_request()

def on_session_ended(session_ended_request, session):
    """
    Called when the user ends the session.
    Is not called when the skill returns should_end_session=true
    """
    print("on_session_ended requestId=" + session_ended_request['requestId'] +
          ", sessionId=" + session['sessionId'])
    # Update code to handle session information