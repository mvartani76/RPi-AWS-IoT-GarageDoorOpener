"""
Behaviors the skill will take based on the intent of the request. Calls on
shadow updater to update IoT shadow accordingly and response builders to
build a response message. If using sessions, session data should be
handled here.
"""
import response_builders
import shadow_connection

# Not using session data or reprompt texts, so these are standard defaults.
# These should be set in the behaviors functions as they are based on behavior of intent.
session_attributes = {}
should_end_session = True
reprompt_text = None

def get_help_response():
    """
    Builds a help/welcome response.
    Args:
        None
    Returns:
        Python dict of response message
    """
    card_title = "Welcome"
    speech_output = "Please give a command for the garage door opener."

    response = response_builders.build_response(session_attributes,
        response_builders.build_speechlet_response(card_title,
        speech_output, reprompt_text, should_end_session))
    return response

def update_toggle(intent):
    """
    Toggles the specific garage door. Updates toggle IoT shadow. Builds a
    response confirming the update or requesting the user repeat the query if
    garage < 1 or garage > 2.
    
    Args:
        intent: Python dict of intent
    Returns:
        Python dict of response message
    """
    card_title = "Toggle"

    garage = intent.get('slots',{}).get('Garage',{}).get('value')

    if garage:
        garage = int(garage)
        # check if garage is 1 or 2 (TBD to auto configure # of garage doors)
        if garage > 0 and garage <= 2:
            speech_output = "Toggling garage {}.".format(garage)
            if garage == 1:
                new_value_dict = {"garage":17}
            else:
                new_value_dict = {"garage":27}
            shadow_connection.update_shadow(new_value_dict)
        else:
            speech_output = "I'm sorry that value is not in the proper range. "\
                "Please give me a number 1 or 2."
    else:
        speech_output = "I did not understand that. Please repeat your request."
    
    response = response_builders.build_response(session_attributes,
        response_builders.build_speechlet_response(card_title,
        speech_output, reprompt_text, should_end_session))
    return response

def open_garage(intent):
    """
    Opens the specific garage door. Updates IoT shadow. Builds a
    response confirming the update or requesting the user repeat the query if
    garage < 1 or garage > 2.
    
    Args:
        intent: Python dict of intent
    Returns:
        Python dict of response message
    """
    card_title = "Open"

    garage = intent.get('slots',{}).get('Garage',{}).get('value')

    if garage:
        garage = int(garage)
        # check if garage is 1 or 2 (TBD to auto configure # of garage doors)
        if garage > 0 and garage <= 2:
            speech_output = "Opening garage {}.".format(garage)
            if garage == 1:
                new_value_dict = {"garage1_status": "OPEN"}
            elif garage == 2:
                new_value_dict = {"garage2_status": "OPEN"}
            shadow_connection.update_shadow(new_value_dict)
        else:
            speech_output = "I'm sorry that value is not in the proper range. "\
                "Please give me a number 1 or 2."
    else:
        speech_output = "I did not understand that. Please repeat your request."
    
    response = response_builders.build_response(session_attributes,
        response_builders.build_speechlet_response(card_title,
        speech_output, reprompt_text, should_end_session))
    return response

def close_garage(intent):
    """
    Closes the specific garage door. Updates IoT shadow. Builds a
    response confirming the update or requesting the user repeat the query if
    garage < 1 or garage > 2.
    
    Args:
        intent: Python dict of intent
    Returns:
        Python dict of response message
    """
    card_title = "Close"

    garage = intent.get('slots',{}).get('Garage',{}).get('value')

    if garage:
        garage = int(garage)
        # check if garage is 1 or 2 (TBD to auto configure # of garage doors)
        if garage > 0 and garage <= 2:
            speech_output = "Closing garage {}.".format(garage)
            if garage == 1:
                new_value_dict = {"garage1_status": "CLOSE"}
            elif garage == 2:
                new_value_dict = {"garage2_status": "CLOSE"}
            shadow_connection.update_shadow(new_value_dict)
        else:
            speech_output = "I'm sorry that value is not in the proper range. "\
                "Please give me a number 1 or 2."
    else:
        speech_output = "I did not understand that. Please repeat your request."
    
    response = response_builders.build_response(session_attributes,
        response_builders.build_speechlet_response(card_title,
        speech_output, reprompt_text, should_end_session))
    return response

def get_status(intent):
    """
    Gets the status of the requested garage door.
    
    Args:
        intent: Python dict of intent
    Returns:
        Python dict of response message
    """
    card_title = "Status"

    garage = intent.get('slots',{}).get('Garage',{}).get('value')

    if garage:
        garage = int(garage)
        # check if garage is 1 or 2 (TBD to auto configure # of garage doors)
        if garage > 0 and garage <= 2:
            if garage == 1:
                garage_request = "garage1_status"
            else:
                garage_request = "garage2_status"
            shadow_response = shadow_connection.get_shadow(garage_request)

            speech_output = "Garage door {} ".format(garage) + "is " + shadow_response
        else:
            speech_output = "I'm sorry that value is not in the proper range. "\
                "Please give me a number 1 or 2."
    else:
        speech_output = "I did not understand that. Please repeat your request."

    response = response_builders.build_response(session_attributes,
        response_builders.build_speechlet_response(card_title,
        speech_output, reprompt_text, should_end_session))
    return response



def handle_session_end_request():
    """
    Builds a response with a blank message and no session data. If using
    session data this function would specifically have session_attributes = {}
    and should_end_session = True.
    Args:
        None
    Returns:
        Python dict of response message
    """
    speech_output = None
    response = response_builders.build_response(session_attributes,
        response_builders.build_speechlet_response(card_title,
        speech_output, reprompt_text, should_end_session))
    return response