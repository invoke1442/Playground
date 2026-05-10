import django.utils.safestring

def render(value):
    return django.utils.safestring.mark_safe("<em>%s</em>" % value)
