from django.urls import path
from . import views

urlpatterns = [
    path("inv/<int:pk>/", views.invoice_unscoped),
    path("inv/", views.invoice_query_param),
    path("inv-attacker/", views.invoice_attacker_tenant),
    path("inv2/<int:pk>/", views.invoice_scoped_kw),
    path("inv3/<int:pk>/", views.invoice_scoped_relation),
]
