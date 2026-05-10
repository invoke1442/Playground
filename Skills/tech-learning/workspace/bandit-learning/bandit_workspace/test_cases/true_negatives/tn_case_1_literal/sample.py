from django.utils.safestring import mark_safe

def render():
    return mark_safe("<p>static content only</p>")
