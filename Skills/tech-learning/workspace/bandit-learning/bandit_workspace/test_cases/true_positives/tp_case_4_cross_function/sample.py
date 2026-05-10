from django.utils.safestring import mark_safe

def get_user_html(request):
    return request.GET.get("html", "")

def render(request):
    html_fragment = get_user_html(request)
    return mark_safe("<section>%s</section>" % html_fragment)
