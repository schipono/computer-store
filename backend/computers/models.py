import uuid
from django.db import models


class Computer(models.Model):
    """Computers for sale.

    Notes:
        - No need to specify Textfield length with PG
        - DecimalField used since we appear to be using US currency and prices. Foreign currency or
          vastly inflated prices may conflict with current max digits.
    """

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    title = models.TextField()
    price = models.DecimalField(max_digits=8, decimal_places=2)
    striked_price = models.DecimalField(max_digits=8, decimal_places=2, null=True, blank=True)
    image = models.TextField(null=True, blank=True)
    vendor = models.TextField()
