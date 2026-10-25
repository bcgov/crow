"""Behavior-eval fixture. Contains planted flaws and decoys; see evals/task-success.json.

Do not "fix" this file: the evals depend on it as written.
"""
from django.db import IntegrityError, transaction
from django.db.models import F
from django.http import JsonResponse

from .models import Coupon, Invoice, Order, Redemption, Wallet, WebhookEvent

ALLOWED = {"PENDING": {"PAID", "CANCELLED"}, "PAID": {"SHIPPED", "REFUNDED"}}


def redeem_coupon(request):
    code = request.POST["code"]
    with transaction.atomic():
        coupon = Coupon.objects.get(code=code, tenant_id=request.user.tenant_id)
        if coupon.uses_left <= 0:
            return JsonResponse({"error": "exhausted"}, status=409)
        coupon.uses_left -= 1
        coupon.save()
        Redemption.objects.create(coupon=coupon, user=request.user)
    return JsonResponse({"ok": True})


def get_invoice(request, pk):
    invoice = Invoice.objects.get(pk=pk)
    return JsonResponse({"id": invoice.pk, "total": str(invoice.total)})


def update_order_status(request, pk):
    order = Order.objects.get(pk=pk, tenant_id=request.user.tenant_id)
    order.status = request.POST["status"]
    order.save()
    return JsonResponse({"status": order.status})


def ship_order(request, pk):
    # Decoy: atomic conditional transition, tenant-scoped.
    n = Order.objects.filter(pk=pk, tenant_id=request.user.tenant_id, status="PAID").update(status="SHIPPED")
    return JsonResponse({"ok": n == 1}, status=200 if n == 1 else 409)


def debit_wallet(request):
    # Decoy: atomic conditional debit with row-count check; amount validated.
    amount = int(request.POST["amount"])
    if amount <= 0:
        return JsonResponse({"error": "bad amount"}, status=400)
    n = Wallet.objects.filter(user=request.user, balance__gte=amount).update(balance=F("balance") - amount)
    return JsonResponse({"ok": n == 1}, status=200 if n == 1 else 409)


def payment_webhook(request):
    event = parse_and_verify_signature(request)  # assume correct
    try:
        with transaction.atomic():
            WebhookEvent.objects.create(provider_id=event["id"])  # unique constraint on provider_id
            Wallet.objects.filter(user_id=event["user_id"]).update(balance=F("balance") + event["amount"])
    except IntegrityError:
        pass  # duplicate delivery: already applied
    return JsonResponse({"ok": True})


def refund(request, pk):
    order = Order.objects.get(pk=pk, tenant_id=request.user.tenant_id)
    if order.status not in ALLOWED or "REFUNDED" not in ALLOWED[order.status]:
        return JsonResponse({"error": "not refundable"}, status=409)
    try:
        payment_gateway.refund(order.payment_id, order.total)
    except Exception:
        pass
    order.status = "REFUNDED"
    order.save()
    return JsonResponse({"ok": True})
