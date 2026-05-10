from django.utils.safestring import mark_safe as ms

def render(user_input):
    return ms("<span>%s</span>" % user_input)
