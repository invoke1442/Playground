from django.utils.html import format_html
from django.utils.safestring import mark_safe

def render(user_input):
    return format_html("<div>{}</div>", mark_safe("<b>%s</b>" % user_input))
