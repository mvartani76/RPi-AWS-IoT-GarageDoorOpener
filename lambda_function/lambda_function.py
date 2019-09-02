"""
Main lambda function handler. The AWS Lambda function should point here to
lambda_function.lambda_handler. Acts on request and session information
through event_actions. Code for sessions is left for reference.
"""
import os
import event_actions

alexa_id = os.environ.get('AWS_ALEXA_SKILLS_KIT_ID')

def lambda_handler(event, context):
    """
    Handles event and request from Alexa Skill by using methods form
    the event_actions module.
    Args:
        event: Python dict of event, request, and session data
        context: LambdaContext containing runtime data
    Returns:
        Python dict of response message
    Rasies:
        ValueError
    """
    print("event.session.application.applicationId=" +
          event['session']['application']['applicationId'])

    # Ensure that request is from our skill
    if (event['session']['application']['applicationId'] !=
            alexa_id):
        print(alexa_id)
        raise ValueError("Invalid Application ID")

    # Uncomment if storing information in sessions
    # if event['session']['new']:
    #     event_actions.on_session_started({'requestId': event['request']['requestId']},
    #                        event['session'])

    request_type = event['request']['type']

    if request_type == "LaunchRequest":
        return event_actions.on_launch(event['request'], event['session'])
    elif request_type == "IntentRequest":
        return event_actions.on_intent(event['request'], event['session'])
    # Uncomment if storing information in sessions
    # elif request_type == "SessionEndedRequest":
    #     return event_actions.on_session_ended(event['request'], event['session'])