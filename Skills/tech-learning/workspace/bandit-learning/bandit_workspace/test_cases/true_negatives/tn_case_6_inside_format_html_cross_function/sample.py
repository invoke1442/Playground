from django.utils.html import format_html
from django.utils.safestring import mark_safe

def build_name(request):
    return request.GET.get("name", "")

def render(request):
    value = build_name(request)
    return format_html("<p>{}</p>", mark_safe("<i>%s</i>" % value))
