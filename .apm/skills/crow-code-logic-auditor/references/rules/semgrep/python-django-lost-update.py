from django.db import transaction
from django.db.models import F


def redeem(user_id, amount):
    # ruleid: python-django-read-modify-write
    acct = Account.objects.get(user_id=user_id)
    if acct.balance < amount:
        raise ValueError
    acct.balance -= amount
    acct.save()


def redeem_atomic_only(user_id, amount):
    with transaction.atomic():
        # ruleid: python-django-read-modify-write
        acct = Account.objects.get(user_id=user_id)
        acct.account_balance = acct.account_balance - amount
        acct.save(update_fields=["account_balance"])


def redeem_locked(user_id, amount):
    with transaction.atomic():
        # ok: python-django-read-modify-write
        acct = Account.objects.select_for_update().get(user_id=user_id)
        acct.balance -= amount
        acct.save()


def redeem_conditional(user_id, amount):
    # ok: python-django-read-modify-write
    n = Account.objects.filter(user_id=user_id, balance__gte=amount).update(balance=F("balance") - amount)
    if n == 0:
        raise ValueError


def rename(pk, name):
    # ok: python-django-read-modify-write
    u = User.objects.get(pk=pk)
    u.name = name
    u.save()
