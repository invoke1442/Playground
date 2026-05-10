from django.utils.safestring import mark_safe

def render(request):
    data = request.POST.get("contents")
    return mark_safe("<div>%s</div>" % data)
