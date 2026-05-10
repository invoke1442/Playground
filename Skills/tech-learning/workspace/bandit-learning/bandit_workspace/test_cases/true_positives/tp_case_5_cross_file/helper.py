def build_fragment(request):
    return request.GET.get("name", "")
