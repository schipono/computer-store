import requests
import pprint
from decimal import Decimal
from django.core.management.base import BaseCommand, CommandError

from computers.models import Computer

JSON_URL = 'https://spotter-interview-files.s3.amazonaws.com/take-home-data-facet.json'


def to_decimal_price(original_price):
    if original_price is None:
        return original_price

    stripped_price = original_price.lstrip('$').replace(',', '')
    return Decimal(stripped_price)


class Command(BaseCommand):
    help = "Bootstrap initial Computer records from a remote json document"

    def handle(self, *args, **kwargs):
        self.stdout.write('Retrieving json document')

        response = requests.get(JSON_URL)
        if not response.ok:
            raise CommandError('Error while retrieving json document, unable to load')

        json_data = response.json()
        self.stdout.write(f'Inserting {len(json_data)} records')

        instances = []
        for data in json_data:
            price = to_decimal_price(data['price'])
            if price is None:
                # If there's no price, we cannot sell it. (And requirements do not account for this)
                # Assume error while preparing the data, alert, and skip.
                self.stdout.write(f'Record missing data, will not insert, please review: \n{pprint.pformat(data)}')
                continue

            instances.append(Computer(
                title=data['title'],
                price=to_decimal_price(data['price']),
                striked_price=to_decimal_price(data['striked-price']),
                image=data['image'],
                vendor=data['vendor']
            ))

        Computer.objects.bulk_create(instances)
        self.stdout.write(f'Saved {len(instances)} Computer instances, out of initial {len(json_data)} JSON records')
