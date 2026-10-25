from django.db import models


class Invoice(models.Model):
    tenant_id = models.IntegerField()
    total = models.IntegerField()
