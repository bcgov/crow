from django.http import JsonResponse
from .models import Invoice


def invoice_unscoped(request, pk):
    inv = Invoice.objects.get(pk=pk)  # EXPECT: unscoped-tenant-lookup
    return JsonResponse({"total": inv.total})


def invoice_query_param(request):
    inv = Invoice.objects.filter(id=request.GET["id"]).first()  # EXPECT: unscoped-tenant-lookup
    return JsonResponse({"total": inv.total})


def invoice_attacker_tenant(request):
    # Tenant keyword is present, but value is attacker-controlled!
    inv = Invoice.objects.get(
        pk=request.GET["id"],
        tenant_id=request.GET["tenant_id"],  # EXPECT: unscoped-tenant-lookup
    )
    return JsonResponse({"total": inv.total})


def invoice_scoped_kw(request, pk):
    inv = Invoice.objects.get(pk=pk, tenant_id=request.user.tenant_id)  # OK
    return JsonResponse({"total": inv.total})


def invoice_scoped_relation(request, pk):
    inv = request.user.tenant.invoices.get(pk=pk)  # OK
    return JsonResponse({"total": inv.total})
