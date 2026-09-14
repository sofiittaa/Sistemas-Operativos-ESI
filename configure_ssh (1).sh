#!/usr/bin/env bash
# ==============================================================================
# configure_ssh.sh — Instala y configura el servicio SSH del servidor
# ------------------------------------------------------------------------------
# SSH (Secure Shell) es el servicio que permite conectarse a este servidor de
# forma remota, desde otra computadora, mediante una terminal. Es lo que se
# usa para administrar el servidor sin estar físicamente sentado frente a él.
#
# Qué hace este script, paso a paso:
#   1) Instala el servicio SSH: la parte "servidor" (recibe conexiones de
#      afuera) y la parte "cliente" (permite conectarse a otros servidores,
#      por ejemplo para el backup del punto anterior).
#   2) Guarda una copia del archivo de configuración original, por si hay
#      que volver atrás.
#   3) Configura el puerto por el que escucha (el estándar es el 22).
#   4) Evita que alguien entre directamente como root.
#   5) Reinicia el servicio para que los cambios se apliquen.
#
# Uso: sudo ./configure_ssh.sh
# ==============================================================================
set -e

if [[ "$(id -u)" -ne 0 ]]; then
  echo "Este script necesita permisos de administrador. Probá: sudo ./configure_ssh.sh"
  exit 1
fi

CONFIG="/etc/ssh/sshd_config"

echo "== Paso 1: instalar el servicio SSH (cliente y servidor) =="
# Si algún repositorio de software extra falla al actualizar la lista, no
# frenamos todo por eso: seguimos e intentamos instalar igual.
apt-get update -qq || echo "(aviso: algún repositorio no respondió, se continúa igual)"
apt-get install -y openssh-server openssh-client

echo "== Paso 2: guardar una copia del archivo de configuración original =="
# Por si algo sale mal, siempre queda una copia para volver atrás a mano
# (cp "${CONFIG}.original" "${CONFIG}").
if [[ ! -f "${CONFIG}.original" ]]; then
  cp "${CONFIG}" "${CONFIG}.original"
  echo "Copia guardada en ${CONFIG}.original"
else
  echo "Ya existía una copia previa; no se pisa."
fi

echo "== Paso 3: configurar el puerto de conexión =="
# El puerto es la "puerta" por la que entran las conexiones SSH. El puerto
# estándar de SSH es el 22. Lo dejamos escrito explícitamente en el archivo
# de configuración, en vez de depender del valor por defecto del programa.
if grep -qE "^#?Port " "${CONFIG}"; then
  sed -i "s/^#\?Port .*/Port 22/" "${CONFIG}"
else
  echo "Port 22" >> "${CONFIG}"
fi

echo "== Paso 4: no permitir el ingreso directo como root =="
# "root" es el usuario con más permisos de todo el sistema. Si alguien
# adivinara su contraseña, tendría control total del servidor. Por eso la
# práctica básica es no dejarlo entrar directo por SSH: cada persona entra
# con su propio usuario y, si necesita permisos de administrador, usa "sudo".
if grep -qE "^#?PermitRootLogin" "${CONFIG}"; then
  sed -i "s/^#\?PermitRootLogin.*/PermitRootLogin no/" "${CONFIG}"
else
  echo "PermitRootLogin no" >> "${CONFIG}"
fi

echo "== Paso 5: revisar que la configuración no tenga errores de sintaxis =="
sshd -t
echo "Configuración correcta."

echo "== Paso 6: reiniciar el servicio para aplicar los cambios =="
systemctl restart ssh 2>/dev/null || service ssh restart

echo "== Paso 7: dejar el servicio activado para que arranque junto con el servidor =="
systemctl enable ssh >/dev/null 2>&1 || true

echo
echo "Listo. El servicio SSH quedó instalado, configurado y corriendo."
echo "  Puerto:                    22"
echo "  Ingreso directo como root: deshabilitado"
echo
echo "Para conectarte usando una llave (más seguro que solo usar contraseña):"
echo "  1) En tu computadora:  ssh-keygen -t ed25519"
echo "  2) Copiar la llave:    ssh-copy-id tu_usuario@IP_DEL_SERVIDOR"
echo "  3) Conectarte:         ssh tu_usuario@IP_DEL_SERVIDOR"
