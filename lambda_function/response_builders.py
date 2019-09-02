"""
Functions to build Python dicts of a response message.
"""

def build_response(session_attributes, speechlet_response):
    """
    Builds a Python dict of version, session, and speechlet reponse. This is
    the core dict (response message) to be returned by the lamabda function.
    Args:
        session_attributes: Python dict of session
        speechlet_response: Python dict of speechlet response
    Returns:
        Python dict of response message
    """
    return {
        'version': '1.0',
        'sessionAttributes': session_attributes,
        'response': speechlet_response
    }

def build_speechlet_response(title, output, reprompt_text, should_end_session):
    """
    Builds a Python dict of a speechlet response for the response message
    dict. Output speech will be read by Alexa. The card dict will be displayed
    if the Alexa device has a screen and can display cards. The reprompt
    message will be read if session remains open and there is no clear
    intent from the user. Should end session will close the session or
    allow it to remain open.
    Args:
        title: string of card title
        output: string of output text
        reprompt_text: string of reprompt text
        should_end_session: boolean to end session
    Returns:
        Python dict of response speechlet
    """
    return {
        'outputSpeech': {
            'type': 'PlainText',
            'text': output
        },
        'card': {
            'type': 'Simple',
            'title': title,
            'content': output
        },
        'reprompt': {
            'outputSpeech': {
                'type': 'PlainText',
                'text': reprompt_text
            }
        },
        'shouldEndSession': should_end_session
    }