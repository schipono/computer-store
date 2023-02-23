from django.http.response import HttpResponse
from django.shortcuts import render


def serve_react_build(request):
    """Serves the index.html from the current React Build."""
    return render(request, "index.html")

def alb_healthcheck(request):
    """Basic health check for the Application Load Balancer"""
    return HttpResponse('OK', status=200)