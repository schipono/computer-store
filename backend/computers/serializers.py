from rest_framework import serializers

from .models import Computer


class ComputerSerializer(serializers.ModelSerializer):
    class Meta:
        model = Computer
        fields = ('id', 'title', 'price', 'striked_price', 'image', 'vendor')
