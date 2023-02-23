from django.db.models import Q
from rest_framework import viewsets, mixins

from .models import Computer
from .serializers import ComputerSerializer


class ComputersViewSet(mixins.ListModelMixin, viewsets.GenericViewSet):
    """Lists all current Computer records, supports `search` query param over Title.

    Notes:
    I'd normally just use a ModelViewset for this as only providing a list method
    isn't typically something I need, but the requirements emphasize using a _single_
    endpoint so that's what we'll do.

    The requirements also specify it should search over `description` and `vendor`.
    Description is not in the source data though, so I'll assume for now that `title`
    is equivalent.
    """

    serializer_class = ComputerSerializer

    def get_queryset(self):
        search_term = self.request.query_params.get('search')
        if search_term is None:
            return Computer.objects.all()

        return Computer.objects.filter(Q(title__icontains=search_term) | Q(vendor__icontains=search_term)).all()
