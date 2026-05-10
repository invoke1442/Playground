import django.utils.safestring as safestring

def view(param):
    return safestring.mark_safe("<b>%s</b>" % param)
