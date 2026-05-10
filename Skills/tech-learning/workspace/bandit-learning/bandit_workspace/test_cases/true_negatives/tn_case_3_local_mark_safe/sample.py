def mark_safe(value):
    return value

def render(request):
    return mark_safe(request.POST.get("contents"))
