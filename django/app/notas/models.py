from django.db import models


class Nota(models.Model):
    """Nota simple para el CRUD de la práctica."""

    titulo = models.CharField("Título", max_length=200)
    contenido = models.TextField("Contenido")
    creado = models.DateTimeField("Creado", auto_now_add=True)

    class Meta:
        ordering = ["-creado"]
        verbose_name = "Nota"
        verbose_name_plural = "Notas"

    def __str__(self):
        return self.titulo
