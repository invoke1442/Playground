from django.utils.safestring import mark_safe
from helper import build_fragment

def render(request):
    fragment = build_fragment(request)
    return mark_safe("<p>%s</p>" % fragment)
