from django.contrib import messages
from django.shortcuts import redirect, render

from .models import Nota


def lista_notas(request):
    """Muestra todas las notas, de la más reciente a la más antigua."""
    notas = Nota.objects.all()
    return render(request, "notas/lista.html", {"notas": notas})


def crear_nota(request):
    """Crea una nota a partir del formulario y vuelve a la lista."""
    if request.method == "POST":
        titulo = (request.POST.get("titulo") or "").strip()
        contenido = (request.POST.get("contenido") or "").strip()
        if titulo and contenido:
            Nota.objects.create(titulo=titulo, contenido=contenido)
            messages.success(request, "Nota creada correctamente.")
            return redirect("notas:lista")
        messages.error(request, "Título y contenido son obligatorios.")
    return render(request, "notas/crear.html")
