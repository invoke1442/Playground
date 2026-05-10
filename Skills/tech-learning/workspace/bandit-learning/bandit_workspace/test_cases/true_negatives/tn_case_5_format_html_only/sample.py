from django.utils.html import format_html

def render(user_input):
    return format_html("<div>{}</div>", user_input)
