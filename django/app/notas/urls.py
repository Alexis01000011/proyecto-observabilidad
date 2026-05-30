from django.urls import path

from . import views

app_name = "notas"

urlpatterns = [
    path("", views.lista_notas, name="lista"),
    path("crear/", views.crear_nota, name="crear"),
]
